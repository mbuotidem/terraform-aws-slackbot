from aws_lambda_powertools import Logger
from typing import List, Dict
from slack_bolt import Assistant, BoltContext, Say, SetSuggestedPrompts, SetStatus
from slack_bolt.context.get_thread_context import GetThreadContext
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

import os

from .llm_caller import call_bedrock_stream

logger = Logger(
    service=os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "terraform-aws-slackbot")
)
assistant = Assistant()


def process_message_lazily(
    payload: dict,
    logger: Logger,
    context: BoltContext,
    set_status: SetStatus,
    get_thread_context: GetThreadContext,
    client: WebClient,
    say: Say,
):
    """Process the message, call Bedrock, and send a reply."""

    user_message = payload["text"]
    user_id = payload.get("user")
    channel_id = context.channel_id
    thread_ts = context.thread_ts

    logger.info(
        "Processing message",
        extra={
            "user_id": user_id,
            "channel_id": channel_id,
            "thread_ts": thread_ts,
            "message_preview": user_message[:50] if user_message else "",
        },
    )

    if user_message == "Can you generate a brief summary of the referred channel?":
        # the logic here requires the additional bot scopes:
        # channels:join, channels:history, groups:history
        thread_context = get_thread_context()
        referred_channel_id = thread_context.get("channel_id")
        try:
            channel_history = client.conversations_history(
                channel=referred_channel_id, limit=50
            )
        except SlackApiError as e:
            if e.response["error"] == "not_in_channel":
                # If this app's bot user is not in the public channel,
                # we'll try joining the channel and then calling the same API again
                client.conversations_join(channel=referred_channel_id)
                channel_history = client.conversations_history(
                    channel=referred_channel_id, limit=50
                )
            else:
                raise e

        prompt = f"Can you generate a brief summary of these messages in a Slack channel <#{referred_channel_id}>?\n\n"
        for message in reversed(channel_history.get("messages")):
            if message.get("user") is not None:
                prompt += f"\n<@{message['user']}> says: {message['text']}\n"
        messages_in_thread = [{"role": "user", "content": prompt}]

        # Send initial "thinking..." message for channel summary
        set_status("is thinking...")

        # Call streaming version with live message updates using Slack's chat_stream API
        call_bedrock_stream(
            messages_in_thread,
            client=client,
            channel=channel_id,
            thread_ts=thread_ts,
            team_id=context.team_id,
            user_id=user_id,
        )
        return

    if not user_message:
        logger.info("No text in message, skipping Bedrock call.")
        return

    try:
        replies = client.conversations_replies(
            channel=context.channel_id,
            ts=context.thread_ts,
            oldest=context.thread_ts,
            limit=10,
        )
        messages_in_thread: List[Dict[str, str]] = []
        for message in replies["messages"]:
            role = "user" if message.get("bot_id") is None else "assistant"
            messages_in_thread.append({"role": role, "content": message["text"]})

        logger.debug(
            "Thread messages retrieved",
            extra={"message_count": len(messages_in_thread)},
        )
        # Send initial "thinking..." message

        set_status("is thinking...")

        # Use Slack's chat_stream API for streaming responses
        call_bedrock_stream(
            messages_in_thread,
            client=client,
            channel=channel_id,
            thread_ts=thread_ts,
            team_id=context.team_id,
            user_id=user_id,
        )
    except Exception as e:
        logger.error(f"Error processing event: {e}")
        say(
            "Sorry, there was an error communicating with AWS Bedrock. The good news is that your Slack App works! If you want to get Bedrock working, check that you've "
            "<https://docs.aws.amazon.com/bedrock/latest/userguide/model-access-modify.html|enabled model access> "
            "and are using the correct <https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html#cross-region-inference-use|inference profile>. "
            "If both of these are true, there is some other error. Check your lambda logs for more info."
        )


@assistant.thread_started()
def start_assistant_thread(
    say: Say,
    get_thread_context: GetThreadContext,
    set_suggested_prompts: SetSuggestedPrompts,
    context: BoltContext,
    logger=logger,
):
    try:
        say(":wave: Hi, how can I help you today?")

        prompts: List[Dict[str, str]] = []

        thread_context = get_thread_context()
        logger.debug(
            "Thread context retrieved",
            extra={
                "has_channel": (
                    thread_context.channel_id is not None if thread_context else False
                )
            },
        )
        if thread_context is not None and thread_context.channel_id is not None:
            summarize_channel = {
                "title": "Summarize the referred channel",
                "message": "Can you generate a brief summary of the referred channel?",
            }
            prompts.append(summarize_channel)

        set_suggested_prompts(prompts=prompts)
    except Exception as e:
        logger.exception(f"Failed to handle an assistant_thread_started event: {e}")
        say(f":warning: Something went wrong! ({e})")


# This listener is invoked when the user sends a reply in the assistant thread
@assistant.user_message(lazy=[process_message_lazily])
def respond_in_assistant_thread(
    payload: dict,
    context: BoltContext,
    set_status: SetStatus,
    get_thread_context: GetThreadContext,
    client: WebClient,
    say: Say,
    logger=logger,
):
    pass
