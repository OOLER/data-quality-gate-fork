resource "random_uuid" "fast_data" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/data_test/", "*.py"),
      fileset("${path.module}/functions/data_test/", "requirements.txt"),
      fileset("${path.module}/functions/data_test/", "Dockerfile")
    ) :
    filename => filemd5("${path.module}/functions/data_test/${filename}")
  }
}

module "docker_image_fast_data" {
  source          = "terraform-aws-modules/lambda/aws//modules/docker-build"
  version         = "3.3.1"
  create_ecr_repo = true
  ecr_repo        = "${local.resource_name_prefix}-fast-data"
  image_tag       = random_uuid.fast_data.result
  source_path     = "${path.module}/functions/data_test"
}

module "lambda_function_fast_data" {
  source         = "terraform-aws-modules/lambda/aws"
  version        = "3.3.1"
  function_name  = "${local.resource_name_prefix}-fast-data"
  description    = "Fast data QA"
  create_package = false
  environment_variables = {
    QA_BUCKET         = aws_s3_bucket.fast_data_qa.bucket
    QA_CLOUDFRONT     = local.aws_cloudfront_distribution
    QA_DYNAMODB_TABLE = aws_dynamodb_table.data_qa_report.name
    REDSHIFT_DB       = var.redshift_db_name
    REDSHIFT_SECRET   = var.redshift_secret
    ENVIRONMENT       = var.environment
  }
  image_uri                      = module.docker_image_fast_data.image_uri
  package_type                   = "Image"
  reserved_concurrent_executions = -1
  timeout                        = 900
  memory_size                    = var.lambda_fast_data_qa_memory
  tracing_mode                   = "PassThrough"
  ephemeral_storage_size         = var.lambda_fast_data_qa_ephemeral_storage_size
}

resource "aws_iam_policy" "fast_data_qa_basic_lambda_policy" {
  name = "${local.resource_name_prefix}-fast-data-qa-basic"
  path = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "ssm:GetParameters",
            "ssm:GetParameter"
          ],
          "Resource" : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${local.resource_name_prefix}/data-qa/*}"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "fast_data_qa_basic_lambda_policy" {
  role       = module.lambda_function_fast_data.lambda_role_name
  policy_arn = aws_iam_policy.fast_data_qa_basic_lambda_policy.arn
}

resource "aws_iam_policy" "fast_data_qa_athena" {
  name = "${local.resource_name_prefix}-fast-data-qa-athena"
  path = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "athena:GetWorkGroup",
            "athena:StartQueryExecution",
            "athena:StopQueryExecution",
            "athena:GetQueryExecution",
            "athena:GetQueryResults"
          ],
          "Resource" : "arn:aws:athena:*:${data.aws_caller_identity.current.account_id}:workgroup/primary"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:PutObject",
            "s3:GetObject",
            "s3:AbortMultipartUpload",
            "s3:ListMultipartUploadParts"
          ],
          "Resource" : "arn:aws:s3:::aws-athena-query-results-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}/*"
        },
        {
          "Effect" : "Allow",
          "Action" : "athena:ListWorkGroups",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ],
          "Resource" : "arn:aws:s3:::aws-athena-query-results-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "fast_data_qa_athena" {
  role       = module.lambda_function_fast_data.lambda_role_name
  policy_arn = aws_iam_policy.fast_data_qa_athena.arn
}
