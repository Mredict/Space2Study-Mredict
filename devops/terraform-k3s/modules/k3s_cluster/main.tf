data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  join_count = var.node_count - 1
}

# ----------------------------------------------------------------------------
# Node 0: bootstraps the cluster with `k3s server --cluster-init`
# ----------------------------------------------------------------------------

resource "aws_eip" "init" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-k3s-node-0-eip-${var.environment}" }
}

resource "aws_instance" "init" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.node_instance_type
  subnet_id              = var.public_subnets[0]
  vpc_security_group_ids = [var.node_sg_id]
  iam_instance_profile   = var.node_instance_profile_name

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  user_data = templatefile("${path.module}/templates/bootstrap.sh.tpl", {
    is_init           = true
    server_private_ip = ""
    cluster_public_ip = aws_eip.init.public_ip
    token_secret_arn  = var.k3s_token_secret_arn
    aws_region        = var.aws_region
    k3s_version       = var.k3s_version
    mongo_device_name = var.mongo_device_name
  })

  tags = {
    Name = "${var.project_name}-k3s-node-0-${var.environment}"
    Role = "init"
  }
}

resource "aws_eip_association" "init" {
  instance_id   = aws_instance.init.id
  allocation_id = aws_eip.init.id
}

# ----------------------------------------------------------------------------
# Remaining nodes: join the cluster via node 0's PRIVATE ip (stays in-VPC)
# ----------------------------------------------------------------------------

resource "aws_eip" "join" {
  count  = local.join_count
  domain = "vpc"
  tags   = { Name = "${var.project_name}-k3s-node-${count.index + 1}-eip-${var.environment}" }
}

resource "aws_instance" "join" {
  count = local.join_count

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.node_instance_type
  subnet_id              = var.public_subnets[(count.index + 1) % length(var.public_subnets)]
  vpc_security_group_ids = [var.node_sg_id]
  iam_instance_profile   = var.node_instance_profile_name

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = templatefile("${path.module}/templates/bootstrap.sh.tpl", {
    is_init           = false
    server_private_ip = aws_instance.init.private_ip
    cluster_public_ip = aws_eip.init.public_ip
    token_secret_arn  = var.k3s_token_secret_arn
    aws_region        = var.aws_region
    k3s_version       = var.k3s_version
    mongo_device_name = var.mongo_device_name
  })

  tags = {
    Name = "${var.project_name}-k3s-node-${count.index + 1}-${var.environment}"
    Role = "join"
  }

  # Make sure the init node is fully up before joiners try to reach it.
  depends_on = [aws_instance.init]
}

resource "aws_eip_association" "join" {
  count         = local.join_count
  instance_id   = aws_instance.join[count.index].id
  allocation_id = aws_eip.join[count.index].id
}

# ----------------------------------------------------------------------------
# Per-node EBS volume for MongoDB's data directory (local-path storage)
# ----------------------------------------------------------------------------

resource "aws_ebs_volume" "mongo_data" {
  count             = var.node_count
  availability_zone = count.index == 0 ? aws_instance.init.availability_zone : aws_instance.join[count.index - 1].availability_zone
  size              = var.mongo_data_volume_gb
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "${var.project_name}-mongo-data-${count.index}-${var.environment}" }
}

resource "aws_volume_attachment" "mongo_data" {
  count       = var.node_count
  device_name = var.mongo_device_name
  volume_id   = aws_ebs_volume.mongo_data[count.index].id
  instance_id = count.index == 0 ? aws_instance.init.id : aws_instance.join[count.index - 1].id
}
