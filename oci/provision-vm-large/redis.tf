# OCI Cache with Redis for jambonz medium cluster

resource "oci_redis_redis_cluster" "jambonz" {
  compartment_id     = var.compartment_id
  display_name       = "${var.name_prefix}-redis"
  node_count         = var.redis_node_count
  node_memory_in_gbs = var.redis_memory_in_gbs
  software_version   = "REDIS_7_0"
  subnet_id          = oci_core_subnet.private.id

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "cache"
  }
}
