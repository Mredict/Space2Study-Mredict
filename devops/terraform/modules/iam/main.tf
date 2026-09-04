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
      }
    ]
  })
}

# 2. Trust Anchor (registers your Root CA with AWS)
resource "aws_rolesanywhere_trust_anchor" "jenkins" {
  name    = "${var.project_name}-jenkins-trust-anchor-${var.environment}"
  enabled = true

  source {
    source_data {
      x509_certificate_data = var.root_ca_certificate
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}

# 3. IAM Role Assumed by the Jenkins Agent
resource "aws_iam_role" "jenkins_roles_anywhere" {
  name = "${var.project_name}-jenkins-roles-anywhere-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rolesanywhere.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:SetSourceIdentity",
          "sts:TagSession"
        ]
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_rolesanywhere_trust_anchor.jenkins.arn
          }
        }
      }
    ]
  })
}

# 4. Attach Deployment Policy to the Roles Anywhere Role
resource "aws_iam_role_policy_attachment" "jenkins_deploy_attach" {
  role       = aws_iam_role.jenkins_roles_anywhere.name
  policy_arn = aws_iam_policy.jenkins_deployment_policy.arn
}

# 5. IAM Roles Anywhere Profile (links Trust Anchor and Role)
resource "aws_rolesanywhere_profile" "jenkins_profile" {
  name             = "${var.project_name}-jenkins-profile-${var.environment}"
  enabled          = true
  duration_seconds = 3600
  role_arns        = [aws_iam_role.jenkins_roles_anywhere.arn]
}