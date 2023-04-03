module "athena-connector" {
  source = "./modules/athena-connector"

  primary_aws_region   = data.aws_region.current.name
  resource_name_prefix = local.resource_name_prefix
}

module "slack_notifier" {
  count  = var.slack_settings == null ? 0 : 1
  source = "./modules/slack-notification"

  image_uri = var.slack_settings.image_uri

  lambda_env_variables = {
    SLACK_WEBHOOK_URL = var.slack_settings.webhook_url
    SLACK_CHANNEL     = var.slack_settings.channel
    SLACK_USERNAME    = var.slack_settings.username
  }

  primary_aws_region = data.aws_region.current.name
  sns_topic_arn      = local.sns_topic_notifications_arn
  subnet_ids         = var.vpc_subnet_ids

  vpc_id = var.slack_settings.vpc_id
}