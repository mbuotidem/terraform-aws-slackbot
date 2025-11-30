from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.utilities.batch import (
    BatchProcessor,
    EventType,
    process_partial_response,
)
from aws_lambda_powertools.utilities.data_classes import (
    LambdaFunctionUrlEvent,
    APIGatewayProxyEvent,
)
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSRecord
from aws_lambda_powertools.utilities.parameters import get_secret
from listeners import register_listeners
from slack_bolt import App
from slack_bolt.adapter.aws_lambda import SlackRequestHandler
from slack_sdk import WebClient
import json
import boto3
import os

logger = Logger()
tracer = Tracer()
processor = BatchProcessor(event_type=EventType.SQS)
sqs = boto3.client("sqs")

# Slack app setup
slack_token = get_secret(os.environ.get("token"), transform="json")["token"]
slack_signing_secret = get_secret(os.environ.get("secret"), transform="json")["secret"]

app = App(
    signing_secret=slack_signing_secret,
    client=WebClient(token=slack_token),
    process_before_response=True,
)


def record_handler(record: SQSRecord, context):
    """Process individual SQS records containing original Lambda events"""
    # The SQS message body contains the ORIGINAL Lambda event
    # that SlackRequestHandler expects
    original_event = json.loads(record.body)

    logger.info(
        "Processing Slack event from SQS",
        extra={
            "event_type": original_event.get("requestContext", {})
            .get("http", {})
            .get("method")
            or original_event.get("requestContext", {}).get("httpMethod")
        },
    )

    # Pass the original event directly to SlackRequestHandler
    register_listeners(app)
    slack_handler = SlackRequestHandler(app=app)

    response = slack_handler.handle(original_event, context)
    logger.info(
        "Processed Slack event", extra={"status_code": response.get("statusCode")}
    )


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    """
    Universal handler supporting:
    - Lambda Function URL (direct from Slack)
    - API Gateway v1/v2 (direct from Slack)
    - SQS Event Source Mapping (async processing)
    """

    # Path 1: SQS Batch Processing
    if (
        "Records" in event
        and event.get("Records", [{}])[0].get("eventSource") == "aws:sqs"
    ):
        logger.info(f"Processing {len(event.get('Records', []))} SQS records")

        # Batch process with partial failure handling
        return process_partial_response(
            event=event,
            record_handler=lambda record: record_handler(record, context),
            processor=processor,
            context=context,
        )

    # Path 2: Direct invocation from Slack (Function URL or API Gateway)
    else:
        # Detect event type using Powertools data classes
        event_type = detect_event_type(event)
        logger.append_keys(event_type=event_type)

        # Parse with appropriate data class
        if event_type == "function_url":
            typed_event = LambdaFunctionUrlEvent(event)
            body = typed_event.body
        elif event_type in ["api_gateway_v1", "api_gateway_v2"]:
            typed_event = APIGatewayProxyEvent(event)
            body = typed_event.body
        else:
            logger.error("Unknown event type", extra={"event": event})
            return {"statusCode": 400, "body": "Unknown event type"}

        # Handle Slack URL verification challenge (synchronous response required)
        if body:
            try:
                body_json = json.loads(body)
                if body_json.get("type") == "url_verification":
                    challenge = body_json.get("challenge")
                    logger.info("Responding to Slack URL verification challenge")
                    return {
                        "statusCode": 200,
                        "headers": {"x-slack-no-retry": "1"},
                        "body": challenge,
                    }
            except json.JSONDecodeError:
                pass

        # Send ENTIRE original event to SQS for async processing
        # This preserves the exact format SlackRequestHandler expects
        queue_url = os.environ.get("SQS_QUEUE_URL")
        if queue_url:
            sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(event),  # Send the whole event!
                MessageGroupId=(
                    context.aws_request_id if queue_url.endswith(".fifo") else None
                ),
            )
            logger.info("Sent event to SQS for async processing")
        else:
            # Fallback: process synchronously (for testing or if SQS disabled)
            logger.warning("No SQS queue configured, processing synchronously")
            register_listeners(app)
            slack_handler = SlackRequestHandler(app=app)
            return slack_handler.handle(event, context)

        # Respond immediately to Slack (meets 3-second requirement)
        return {"statusCode": 200, "body": ""}


def detect_event_type(event: dict) -> str:
    """Detect whether event is from Function URL, API Gateway v1, or v2"""
    if "requestContext" in event:
        request_context = event["requestContext"]

        # Function URL has requestContext.http.method and requestContext.domainName
        if "http" in request_context and request_context.get("domainName"):
            return "function_url"

        # API Gateway v2 has requestContext.http
        elif "http" in request_context:
            return "api_gateway_v2"

        # API Gateway v1 has requestContext.httpMethod
        elif "httpMethod" in request_context or "httpMethod" in event:
            return "api_gateway_v1"

    return "unknown"
