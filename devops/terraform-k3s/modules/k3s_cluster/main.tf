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

# ----------------------------------------------------------------------------
# Control plane
# ----------------------------------------------------------------------------

resource "aws_eip" "control_plane" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-k3s-control-plane-eip-${var.environment}" }
}

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.control_plane_instance_type
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
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }

  user_data = templatefile("${path.module}/templates/control-plane-bootstrap.sh.tpl", {
    cluster_public_ip = aws_eip.control_plane.public_ip
    token_secret_arn  = var.k3s_token_secret_arn
    aws_region        = var.aws_region
    k3s_version       = var.k3s_version
  })

  tags = {
    Name = "${var.project_name}-k3s-control-plane-${var.environment}"
    Role = "control-plane"
  }
}

resource "aws_eip_association" "control_plane" {
  instance_id   = aws_instance.control_plane.id
  allocation_id = aws_eip.control_plane.id
}

# ----------------------------------------------------------------------------
# Workers
# ----------------------------------------------------------------------------

resource "aws_eip" "worker" {
  count  = var.worker_count
  domain = "vpc"
  tags   = { Name = "${var.project_name}-k3s-worker-${count.index}-eip-${var.environment}" }
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.worker_instance_type
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
  
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  user_data = templatefile("${path.module}/templates/worker-bootstrap.sh.tpl", {
    control_plane_private_ip = aws_instance.control_plane.private_ip
    token_secret_arn         = var.k3s_token_secret_arn
    aws_region               = var.aws_region
    mongo_device_name        = var.mongo_device_name
    k3s_version              = var.k3s_version
  })

  tags = {
    Name = "${var.project_name}-k3s-worker-${count.index}-${var.environment}"
    Role = "worker"
  }

  depends_on = [aws_instance.control_plane]
}

resource "aws_eip_association" "worker" {
  count         = var.worker_count
  instance_id   = aws_instance.worker[count.index].id
  allocation_id = aws_eip.worker[count.index].id
}

# ----------------------------------------------------------------------------
# Mongo data volume - workers only
# ----------------------------------------------------------------------------

resource "aws_ebs_volume" "mongo_data" {
  count             = var.worker_count
  availability_zone = aws_instance.worker[count.index].availability_zone
  size              = var.mongo_data_volume_gb
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "${var.project_name}-mongo-data-worker-${count.index}-${var.environment}" }
}

resource "aws_volume_attachment" "mongo_data" {
  count       = var.worker_count
  device_name = var.mongo_device_name
  volume_id   = aws_ebs_volume.mongo_data[count.index].id
  instance_id = aws_instance.worker[count.index].id
}
