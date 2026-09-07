# 1. Managed Deployment Policy (ECR + ECS permissions)
resource "aws_iam_policy" "jenkins_deployment_policy" {
  name        = "${var.project_name}-deployment-policy-${var.environment}"
  description = "Allows Jenkins to push ECR images and trigger ECS deployments"

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
        Sid    = "ECSTriggerDeploy"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRolesToECS"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.project_name}-ecs-*-${var.environment}"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
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