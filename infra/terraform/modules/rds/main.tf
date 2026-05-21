# IV-02, IV-10 remediated — private subnets, encryption, backups, deletion protection

variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_password" { type = string }

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-db-subnet"
  subnet_ids  = var.private_subnet_ids
  description = "Private subnet group for RDS instances"
}

resource "aws_security_group" "db" {
  name        = "${var.project}-${var.environment}-db-sg"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL instances"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/8"]
    description     = "Allow PostgreSQL from private network only"
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Allow PostgreSQL outbound to private network only"
  }
}

resource "aws_db_instance" "auth" {
  identifier              = "${var.project}-${var.environment}-authdb"
  engine                  = "postgres"
  engine_version          = "14"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "authdb"
  username                = "authuser"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = false
  deletion_protection     = true
  backup_retention_period = 7

  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  iam_database_authentication_enabled   = true

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  monitoring_interval                   = 60
  auto_minor_version_upgrade            = true
  multi_az                              = true
}

resource "aws_db_instance" "transactions" {
  identifier              = "${var.project}-${var.environment}-txdb"
  engine                  = "postgres"
  engine_version          = "14"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "transactiondb"
  username                = "txuser"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = false
  deletion_protection     = true
  backup_retention_period = 7

  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  iam_database_authentication_enabled   = true

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  monitoring_interval                   = 60
  auto_minor_version_upgrade            = true
  multi_az                              = true
}

output "auth_db_endpoint" {
  value = aws_db_instance.auth.endpoint
}

output "tx_db_endpoint" {
  value = aws_db_instance.transactions.endpoint
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS Performance Insights encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
