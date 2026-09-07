# 1. Fetch latest fck-nat x86_64 AMI (for t3.micro Free Tier compatibility)
data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"] # Official fck-nat AWS account

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*-x86_64-ebs"]
  }
}

# 2. Security Group for the NAT instance
resource "aws_security_group" "fck_nat" {
  name        = "${var.project_name}-fck-nat-sg-${var.environment}"
  description = "Security group for fck-nat instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow inbound traffic from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.private_subnets
  }

  egress {
    description = "Allow all outbound internet traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-fck-nat-sg-${var.environment}"
  }
}

# 3. Elastic IP for the NAT instance
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-fck-nat-eip-${var.environment}"
  }
}

# 4. Network Interface with Source/Dest Check Disabled
resource "aws_network_interface" "nat_eni" {
  subnet_id         = module.vpc.public_subnets[0]
  security_groups   = [aws_security_group.fck_nat.id]
  source_dest_check = false # Required for NAT routing

  tags = {
    Name = "${var.project_name}-fck-nat-eni-${var.environment}"
  }
}

resource "aws_eip_association" "nat_eip_assoc" {
  network_interface_id = aws_network_interface.nat_eni.id
  allocation_id        = aws_eip.nat.id
}

# 5. Free-Tier eligible EC2 instance (t3.micro, x86_64) using primary_network_interface
resource "aws_instance" "fck_nat" {
  ami           = data.aws_ami.fck_nat.id
  instance_type = "t3.micro"

  primary_network_interface {
    network_interface_id = aws_network_interface.nat_eni.id
  }

  tags = {
    Name = "${var.project_name}-fck-nat-${var.environment}"
  }
}

# 6. Route private subnet traffic through the fck-nat ENI
resource "aws_route" "private_nat_gateway" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.nat_eni.id
}