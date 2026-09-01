# 1. IAM User for Local Jenkins Agent
resource "aws_iam_user" "jenkins_deployer" {
  name = "${var.project_name}-jenkins-deployer-${var.environment}"
  path = "/system/"
}

# 2. Generate Access Keys (To be securely stored in local Jenkins Credentials)
resource "aws_iam_access_key" "jenkins_keys" {
  user = aws_iam_user.jenkins_deployer.name
}

# 3. Least-Privilege Policy for ECR and ECS
resource "aws_iam_user_policy" "jenkins_deployment_policy" {
  name = "${var.project_name}-deployment-policy-${var.environment}"
  user = aws_iam_user.jenkins_deployer.name

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
          "ecs:DescribeServices"
        ]
        Resource = [
          var.frontend_ecs_service_id,
          var.backend_ecs_service_id
        ]
      }
    ]
  })
}