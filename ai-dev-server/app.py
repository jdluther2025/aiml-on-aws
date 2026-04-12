#!/usr/bin/env python3
import os
import aws_cdk as cdk
from ai_dev_server.ai_dev_server_stack import AiDevServerStack

app = cdk.App()

AiDevServerStack(app, "AiDevServerStack",
    # Environment is required for VPC lookup (default VPC detection)
    env=cdk.Environment(
        account=os.getenv("CDK_DEFAULT_ACCOUNT"),
        region=os.getenv("CDK_DEFAULT_REGION"),
    ),
)

app.synth()
