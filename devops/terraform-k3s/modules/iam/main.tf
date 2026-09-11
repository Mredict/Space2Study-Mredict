# ----------------------------------------------------------------------------
# k3s NODE ROLE
# ----------------------------------------------------------------------------

resource "aws_iam_role" "k3s_node" {
  name = "${var.project_name}-k3s-node-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "ecr_pull" {
  name = "${var.project_name}-ecr-pull-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ECRAuth", Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_attach" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

resource "aws_iam_policy" "node_secrets_read" {
  name = "${var.project_name}-node-secrets-read-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadClusterToken"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.k3s_token_secret_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_secrets_read_attach" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.node_secrets_read.arn
}

resource "aws_iam_instance_profile" "k3s_node" {
  name = "${var.project_name}-k3s-node-profile-${var.environment}"
  role = aws_iam_role.k3s_node.name
}

# ----------------------------------------------------------------------------
# EXTERNAL SECRETS OPERATOR - deliberately NOT via the node's instance profile
# ----------------------------------------------------------------------------

resource "aws_iam_user" "eso_secrets_reader" {
  name = "${var.project_name}-eso-secrets-reader-${var.environment}"
}

resource "aws_iam_access_key" "eso_secrets_reader" {
  user = aws_iam_user.eso_secrets_reader.name
}

resource "aws_iam_policy" "eso_secrets_read" {
  name = "${var.project_name}-eso-secrets-read-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAppSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.app_secrets_arn]
    }]
  })
}

resource "aws_iam_user_policy_attachment" "eso_secrets_reader_attach" {
  user       = aws_iam_user.eso_secrets_reader.name
  policy_arn = aws_iam_policy.eso_secrets_read.arn
}

# ----------------------------------------------------------------------------
# JENKINS - STATIC IAM USER
# ----------------------------------------------------------------------------

resource "aws_iam_user" "jenkins_static" {
  name = "${var.project_name}-jenkins-deployer-${var.environment}"
}

resource "aws_iam_access_key" "jenkins_static" {
  user = aws_iam_user.jenkins_static.name
}

resource "aws_iam_policy" "jenkins_deploy" {
  name        = "${var.project_name}-jenkins-deploy-${var.environment}"
  description = "Push to ECR from the local Jenkins agent"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ECRAuth", Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
        ]
        Resource = var.ecr_repository_arns
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_static.name
  policy_arn = aws_iam_policy.jenkins_deploy.arn
}

resource "aws_iam_user_policy_attachment" "jenkins_ssm" {
  user       = aws_iam_user.jenkins_static.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# ----------------------------------------------------------------------------
# COSIGN IMAGE SIGNING - KMS-backed key
# ----------------------------------------------------------------------------

resource "aws_kms_key" "cosign_signing" {
  description              = "Asymmetric signing key for cosign image signing (Jenkins)"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 30
}

resource "aws_kms_alias" "cosign_signing" {
  name          = "alias/${var.project_name}-cosign-signing-${var.environment}"
  target_key_id = aws_kms_key.cosign_signing.key_id
}

resource "aws_iam_policy" "cosign_sign" {
  name        = "${var.project_name}-cosign-sign-${var.environment}"
  description = "Lets Jenkins sign images with the cosign KMS key - nothing else"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "CosignSign"
      Effect   = "Allow"
      Action   = ["kms:Sign", "kms:GetPublicKey", "kms:DescribeKey"]
      Resource = aws_kms_key.cosign_signing.arn
    }]
  })
}

resource "aws_iam_user_policy_attachment" "cosign_sign_attach" {
  user       = aws_iam_user.jenkins_static.name
  policy_arn = aws_iam_policy.cosign_sign.arn
}
