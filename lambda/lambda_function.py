import base64
import json
import logging
import os
import time
from urllib.parse import unquote

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

BUCKET = os.environ["BUCKET"]
PREFIX = os.environ["PREFIX"].strip("/") + "/"
s3 = boto3.client("s3")

CONTENT_TYPES = {
    "index.html": "text/html",
    "style.css": "text/css",
    "cv.pdf": "application/pdf",
}

def handler(event, context):
    started = time.perf_counter()
    # Corrected with [0] at the end
    path = unquote((event.get("rawPath") or event.get("path") or "/").split("?", 1)[0])
    
    if path in ("", "/"):
        key_name = "index.html"
    elif path in ("/index.html", "/style.css", "/cv.pdf"):
        key_name = path.lstrip("/")
    else:
        body = "<!doctype html><html><body><h1>404 Not Found</h1></body></html>"
        status = 404
        log_line = {"fn": context.function_name, "path": path, "status": status,
                    "ms": int((time.perf_counter() - started) * 1000)}
        logger.info(json.dumps(log_line))
        return {"statusCode": status, "headers": {"Content-Type": "text/html"},
                "body": body}

    try:
        obj = s3.get_object(Bucket=BUCKET, Key=PREFIX + key_name)
        content = obj["Body"].read()
        if key_name == "index.html":
            content = content.decode("utf-8").replace("{{HOSTED_ON}}",
                                                       "Lambda " + context.function_name).encode("utf-8")
            body = content.decode("utf-8")
            is_base64 = False
        elif key_name == "cv.pdf":
            body = base64.b64encode(content).decode("ascii")
            is_base64 = True
        else:
            body = content.decode("utf-8")
            is_base64 = False
            
        headers = {"Content-Type": CONTENT_TYPES[key_name]}
        if key_name == "index.html":
            headers["Cache-Control"] = "max-age=60"
        status = 200
        response = {"statusCode": status, "headers": headers, "body": body,
                    "isBase64Encoded": is_base64}
                    
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code in ('NoSuchKey', '404'):
            status = 404
            body = "<!doctype html><html><body><h1>404 Not Found</h1></body></html>"
        else:
            status = 500
            body = "<!doctype html><html><body><h1>Unable to load CV</h1></body></html>"
            
        response = {"statusCode": status, "headers": {"Content-Type": "text/html"},
                    "body": body}

    logger.info(json.dumps({"fn": context.function_name, "path": path, "status": status,
                            "ms": int((time.perf_counter() - started) * 1000)}))
    return response
