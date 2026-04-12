import aws_cdk as core
import aws_cdk.assertions as assertions

from ai_dev_server.ai_dev_server_stack import AiDevServerStack

# example tests. To run these tests, uncomment this file along with the example
# resource in ai_dev_server/ai_dev_server_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = AiDevServerStack(app, "ai-dev-server")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
