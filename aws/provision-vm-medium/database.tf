# Aurora Serverless v2 MySQL for jambonz medium deployment on AWS

# ------------------------------------------------------------------------------
# DB SUBNET GROUP
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "jambonz" {
  name       = "${var.name_prefix}-db-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.name_prefix}-db-subnet"
  }
}

# ------------------------------------------------------------------------------
# CLUSTER PARAMETER GROUP
# ------------------------------------------------------------------------------

resource "aws_rds_cluster_parameter_group" "jambonz" {
  family = "aurora-mysql8.0"
  name   = "${var.name_prefix}-cluster-params"

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_events"
    value = "CONNECT,QUERY,TABLE"
  }

  parameter {
    name         = "binlog_format"
    value        = "MIXED"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "binlog_checksum"
    value        = "CRC32"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "binlog_row_image"
    value        = "FULL"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.name_prefix}-cluster-params"
  }
}

# ------------------------------------------------------------------------------
# DB PARAMETER GROUP
# ------------------------------------------------------------------------------

resource "aws_db_parameter_group" "jambonz" {
  family = "aurora-mysql8.0"
  name   = "${var.name_prefix}-instance-params"

  parameter {
    name  = "max_connections"
    value = "300"
  }

  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = {
    Name = "${var.name_prefix}-instance-params"
  }
}

# ------------------------------------------------------------------------------
# AURORA SERVERLESS v2 CLUSTER
# ------------------------------------------------------------------------------

resource "aws_rds_cluster" "jambonz" {
  cluster_identifier              = "${var.name_prefix}-aurora"
  engine                          = "aurora-mysql"
  engine_mode                     = "provisioned"
  engine_version                  = "8.0.mysql_aurora.3.08.1"
  database_name                   = "jambones"
  master_username                 = var.mysql_username
  master_password                 = local.db_password
  db_subnet_group_name            = aws_db_subnet_group.jambonz.name
  vpc_security_group_ids          = [aws_security_group.mysql.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.jambonz.name
  skip_final_snapshot             = true
  deletion_protection             = false
  storage_encrypted               = true
  backup_retention_period         = 30
  preferred_backup_window         = "07:00-09:00"
  preferred_maintenance_window    = "sun:05:00-sun:06:00"

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = {
    Name = "${var.name_prefix}-aurora"
  }
}

# ------------------------------------------------------------------------------
# AURORA SERVERLESS v2 INSTANCE
# ------------------------------------------------------------------------------

resource "aws_rds_cluster_instance" "jambonz" {
  cluster_identifier   = aws_rds_cluster.jambonz.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.jambonz.engine
  engine_version       = aws_rds_cluster.jambonz.engine_version
  db_parameter_group_name = aws_db_parameter_group.jambonz.name
  publicly_accessible  = false

  tags = {
    Name = "${var.name_prefix}-aurora-instance"
  }
}
