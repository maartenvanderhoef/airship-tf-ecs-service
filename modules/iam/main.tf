# We need the AWS Account ID for the SSM Permissions
data "aws_caller_identity" "current" {
  count = "${var.create ?  1 : 0 }"
}

# Asume Role Policy for the ECS Task
data "aws_iam_policy_document" "ecs_task_asume_role" {
  #count = "${var.create ? 1 : 0 }"
  count = "1"

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals = {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# The ECS TASK ROLE execution role needed for FARGATE & AWS LOGS
resource "aws_iam_role" "ecs_task_execution_role" {
  count              = "${(var.create && var.fargate_enabled ) ? 1 : 0 }"
  name               = "${var.name}-ecs-task-execution_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task_asume_role.json}"
}

# We need this for FARGATE
resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  count      = "${(var.create && var.fargate_enabled ) ? 1 : 0 }"
  role       = "${aws_iam_role.ecs_task_execution_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The actual ECS TASK ROLE
resource "aws_iam_role" "ecs_tasks_role" {
  count              = "${var.create}"
  name               = "${var.name}-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task_asume_role.json}"
}

# Policy Document to allow KMS Decryption with given KEYS
data "aws_iam_policy_document" "kms_permissions" {
  count = "${var.create ? 1 : 0 }"

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["${var.kms_keys}"]
  }
}

# Allow KMS-Decrypt permissions for the ECS Task Role
resource "aws_iam_role_policy" "kms_permissions" {
  count  = "${var.create ? 1 : 0 }"
  name   = "kms_permissions"
  role   = "${aws_iam_role.ecs_tasks_role.id}"
  policy = "${data.aws_iam_policy_document.kms_permissions.json}"
}

# Policy Document to allow KMS Decryption with given KEYS
data "aws_iam_policy_document" "ssm_permissions" {
  count = "${var.create ? 1 : 0 }"

  statement {
    effect    = "Allow"
    actions   = ["kms:GetParameter", "ssm:GetParametersByPath"]
    resources = ["${join("\", \"", formatlist("arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/application/%s/*",var.ssm_paths))}"]
  }
}

# Add the ssm policy to the task role
resource "aws_iam_role_policy" "ssm_permissions" {
  count  = "${var.create ? 1 : 0 }"
  name   = "ssm-policy"
  role   = "${aws_iam_role.ecs_tasks_role.id}"
  policy = "${data.aws_iam_policy_document.ssm_permissions.json}"
}

# Policy Document to allow S3 Read-Write Access to given paths
data "aws_iam_policy_document" "s3_rw_permissions" {
  count = "${var.create ? 1 : 0 }"

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${join("\", \"", formatlist("arn:aws:s3:::%s",var.s3_rw_paths))}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["${join("\", \"", formatlist("arn:aws:s3:::%s/*",var.s3_rw_paths))}"]
  }
}

# Policy Document to allow S3 Read-Only Access to given paths
data "aws_iam_policy_document" "s3_ro_permissions" {
  count = "${var.create ? 1 : 0 }"

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${join("\", \"", formatlist("arn:aws:s3:::%s",var.s3_ro_paths))}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${join("\", \"", formatlist("arn:aws:s3:::%s/*",var.s3_ro_paths))}"]
  }
}

# Add the ssm policy to the task role
resource "aws_iam_role_policy" "s3_rw_permissions" {
  name   = "s3-read-write-policy"
  count  = "${(var.create && length(var.s3_rw_paths) > 0 ) ? 1 : 0 }"
  role   = "${aws_iam_role.ecs_tasks_role.id}"
  policy = "${data.aws_iam_policy_document.s3_rw_permissions.json}"
}

# Add the ssm policy to the task role
resource "aws_iam_role_policy" "s3_ro_permissions" {
  count  = "${(var.create && length(var.s3_ro_paths) > 0 ) ? 1 : 0 }"
  name   = "s3-readonly-policy"
  role   = "${aws_iam_role.ecs_tasks_role.id}"
  policy = "${data.aws_iam_policy_document.s3_ro_permissions.json}"
}
