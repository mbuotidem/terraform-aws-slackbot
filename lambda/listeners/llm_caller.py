import os
import re
from typing import List, Dict
import boto3
from aws_lambda_powertools import Logger

logger = Logger(service="llm_caller")
bedrock_runtime_client = boto3.client("bedrock-runtime")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_INFERENCE_PROFILE")

DEFAULT_SYSTEM_CONTENT = """
You're an assistant in a Slack workspace.
Users in the workspace will ask you to help them write something or to think deeply about a specific topic.
You'll respond to those questions in a professional way.
When you include markdown text, convert them to Slack compatible ones.
When a prompt has Slack's special syntax like <@USER_ID> or <#CHANNEL_ID>, you must keep them as-is in your response.
"""


def markdown_to_slack(content: str) -> str:
    # Split the input string into parts based on code blocks and inline code
    parts = re.split(r"(?s)(```.+?```|`[^`\n]+?`)", content)

    # Apply the bold, italic, and strikethrough formatting to text not within code
    result = ""
    for part in parts:
        if part.startswith("```") or part.startswith("`"):
            result += part
        else:
            for o, n in [
                (
                    r"\*\*\*(?!\s)([^\*\n]+?)(?<!\s)\*\*\*",
                    r"_*\1*_",
                ),  # ***bold italic*** to *_bold italic_*
                (
                    r"(?<![\*_])\*(?!\s)([^\*\n]+?)(?<!\s)\*(?![\*_])",
                    r"_\1_",
                ),  # *italic* to _italic_
                (r"\*\*(?!\s)([^\*\n]+?)(?<!\s)\*\*", r"*\1*"),  # **bold** to *bold*
                (r"__(?!\s)([^_\n]+?)(?<!\s)__", r"*\1*"),  # __bold__ to *bold*
                (r"~~(?!\s)([^~\n]+?)(?<!\s)~~", r"~\1~"),  # ~~strike~~ to ~strike~
            ]:
                part = re.sub(o, n, part)
            result += part
    return result


def call_bedrock_stream(
    messages_in_thread: List[Dict[str, str]],
    system_content: str = DEFAULT_SYSTEM_CONTENT,
    client=None,
    channel=None,
    thread_ts=None,
    team_id=None,
    user_id=None,
):
    """
    Streams messages to a Bedrock model with live Slack message updates using Slack's chat_stream API.

    Args:
        messages_in_thread: List of message dictionaries with 'role' and 'content' keys
        system_content: System prompt content
        client: Slack WebClient instance
        channel: Slack channel ID
        thread_ts: Thread timestamp for replies
        team_id: Team ID for the recipient
        user_id: User ID for the recipient

    Returns:
        str: Complete response content formatted for Slack
    """
    logger.debug("Messages being sent to Bedrock", extra={"messages": messages_in_thread})

    # Convert thread messages to Bedrock format
    messages = []
    for msg in messages_in_thread:
        formatted_msg = {"role": msg["role"], "content": [{"text": msg["content"]}]}
        messages.append(formatted_msg)

    # System prompts for streaming API
    system_prompts = [{"text": system_content}]

    model_id = BEDROCK_MODEL_ID

    # Basic inference configuration
    inference_config = {"temperature": 0.7, "maxTokens": 8192}

    try:
        # Start Bedrock streaming
        response = bedrock_runtime_client.converse_stream(
            modelId=model_id,
            messages=messages,
            system=system_prompts,
            inferenceConfig=inference_config,
        )

        # Initialize Slack streaming with chat_stream helper
        # This must be called BEFORE we start iterating through the Bedrock stream
        streamer = client.chat_stream(
            channel=channel,
            thread_ts=thread_ts,
            recipient_team_id=team_id,
            recipient_user_id=user_id,
        )

        # Stream the response directly to Slack
        stream = response.get("stream")

        if stream:
            for event in stream:
                if "contentBlockDelta" in event:
                    delta_text = event["contentBlockDelta"]["delta"]["text"]
                    # Stream to Slack using the new API
                    # Convert to Slack markdown and append to stream
                    streamer.append(markdown_text=markdown_to_slack(delta_text))

                if "messageStop" in event:
                    logger.info("Bedrock stream stopped", extra={"stop_reason": event['messageStop']['stopReason']})

                if "metadata" in event:
                    metadata = event["metadata"]
                    if "usage" in metadata:
                        logger.info(
                            "Bedrock token usage",
                            extra={
                                "input_tokens": metadata['usage']['inputTokens'],
                                "output_tokens": metadata['usage']['outputTokens'],
                                "total_tokens": metadata['usage']['totalTokens']
                            }
                        )

        # Stop the Slack stream
        streamer.stop()

        return ""

    except Exception:
        logger.exception("Error in streaming call")
        raise
