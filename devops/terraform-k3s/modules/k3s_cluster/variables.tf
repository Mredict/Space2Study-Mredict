variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }

variable "control_plane_instance_type" {
  description = "No longer runs workload pods (tainted NoSchedule) - t3.small kept for now for stability rather than gambling on t3.micro after everything else this project has been through"
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  type    = string
  default = "t3.small"
}

variable "worker_count" {
  description = "MongoDB's replica count in the Helm chart must not exceed this - see values-dev.yaml"
  type        = number
  default     = 2
}

variable "root_volume_gb" { type = number }
variable "mongo_data_volume_gb" { type = number }
variable "mongo_device_name" {
  type    = string
  default = "/dev/xvdf"
}
variable "public_subnets" { type = list(string) }
variable "node_sg_id" { type = string }
variable "node_instance_profile_name" { type = string }
variable "k3s_token_secret_arn" { type = string }

variable "k3s_version" {
  description = "Pinned k3s release - never track 'latest' for a cluster you'll rebuild more than once"
  type        = string
  default     = "v1.31.4+k3s1"
}
