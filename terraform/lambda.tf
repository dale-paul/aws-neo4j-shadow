resource "aws_cloudwatch_event_rule" "event_rules" {
  for_each            = var.scheduled_events
  name                = lower("${var.project}-cluster-manager-${each.key}-trigger")
  description         = "${each.key} ${var.project} cluster"
  schedule_expression = each.value
}

data "archive_file" "init" {
  type        = "zip"
  source_file = "${path.module}/lambda/cost_saving.py"
  output_path = "${path.module}/lambda/cost_saving.zip"
}

resource "aws_iam_role" "lambda_iam_role" {
  name               = "${var.project}-cluster-manager-role"
  assume_role_policy = data.aws_iam_policy_document.cost_saving_lambda_iam_role.json
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project}-ECSCostSavingsLambdaPolicy"
  policy = data.aws_iam_policy_document.cost_saving_lambda_iam_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_policies" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "neo4j-cluster-manager" {
  function_name = "${var.project}-cluster-manager"
  filename      = "${path.module}/lambda/cost_saving.zip"
  handler       = "cost_saving.lambda_handler"
  role          = aws_iam_role.lambda_iam_role.arn
  runtime       = "python3.7"
  tags          = var.common_tags
  timeout       = 3
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  for_each      = var.scheduled_events
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.neo4j-cluster-manager.function_name
  principal     = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_target" "lambda" {
  for_each = var.scheduled_events
  rule     = aws_cloudwatch_event_rule.event_rules["${each.key}"].name
  arn      = aws_lambda_function.neo4j-cluster-manager.arn
}
