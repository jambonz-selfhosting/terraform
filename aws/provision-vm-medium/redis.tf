# ElastiCache Redis for jambonz medium deployment on AWS

# ------------------------------------------------------------------------------
# ELASTICACHE SUBNET GROUP
# ------------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "jambonz" {
  name       = "${var.name_prefix}-redis-subnet"
  subnet_ids = aws_subnet.private[*].id
}

# ------------------------------------------------------------------------------
# ELASTICACHE PARAMETER GROUP
# ------------------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "jambonz" {
  family = "redis7"
  name   = "${var.name_prefix}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

# ------------------------------------------------------------------------------
# ELASTICACHE REDIS REPLICATION GROUP
# ------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "jambonz" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "jambonz Redis cluster"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_clusters   = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.jambonz.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.jambonz.name

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = {
    Name = "${var.name_prefix}-redis"
  }
}
