#!/usr/bin/env python3.11
# AI-ML on AWS -- Smoke Test: Claude on Amazon Bedrock via IAM Role
# Run this after SSHing into the AI Dev Server.
# No API key needed -- auth via the IAM role attached to the instance.

import boto3
import json

client = boto3.client('bedrock-runtime', region_name='us-east-1')

response = client.invoke_model(
    modelId='us.anthropic.claude-haiku-4-5-20251001-v1:0',
    body=json.dumps({
        'anthropic_version': 'bedrock-2023-05-31',
        'max_tokens': 50,
        'messages': [{'role': 'user', 'content': 'Say: Claude on Bedrock is live on AWS.'}]
    })
)

print(json.loads(response['body'].read())['content'][0]['text'])
