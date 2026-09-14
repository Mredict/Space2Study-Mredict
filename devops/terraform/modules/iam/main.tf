# 1. Managed Deployment Policy
resource "aws_iam_policy" "jenkins_deployment_policy" {
  name        = "${var.project_name}-deployment-policy-${var.environment}"
  description = "Allows Jenkins to push ECR images, locate K3s instances, and read runtime secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
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
          "ecr:DescribeImages"
        ]
        Resource = [
          var.frontend_ecr_arn,
          var.backend_ecr_arn
        ]
      },
      {
        Sid    = "EC2Discovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.secret_arn
        ]
      }
    ]
  })
}

# 2. Dedicated IAM User for Jenkins CI/CD
resource "aws_iam_user" "jenkins" {
  name = "${var.project_name}-jenkins-agent-${var.environment}"

  tags = {
    Name = "${var.project_name}-jenkins-agent-${var.environment}"
  }
}

# 3. IAM Access Key Pair
resource "aws_iam_access_key" "jenkins" {
  user = aws_iam_user.jenkins.name
}

# 4. Attach Deployment Policy to Jenkins IAM User
resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins.name
  policy_arn = aws_iam_policy.jenkins_deployment_policy.arn
}