# 1. Subnet Group for DocumentDB
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group-${var.environment}"
  subnet_ids = var.private_subnets

  tags = {
    Name = "${var.project_name}-docdb-subnet-group"
  }
}

# 2. DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb-${var.environment}"
  engine                  = "docdb"
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [var.db_sg_id]
  storage_encrypted       = true # DevSecOps: Enforce encryption at rest
  skip_final_snapshot     = true # Set to false in real production

  tags = {
    Name = "${var.project_name}-docdb-cluster"
  }
}

# 3. DocumentDB Cluster Instance
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 1 # Adjust instance count as needed
  identifier         = "${var.project_name}-docdb-instance-${count.index}-${var.environment}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"
}