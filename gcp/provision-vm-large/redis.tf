# Memorystore Redis configuration for jambonz on GCP
# No AUTH, no TLS - simple configuration

# ------------------------------------------------------------------------------
# MEMORYSTORE REDIS INSTANCE
# ------------------------------------------------------------------------------

resource "google_redis_instance" "jambonz" {
  name           = "${var.name_prefix}-redis"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = var.region

  # Connect via private network
  authorized_network = google_compute_network.jambonz.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # No AUTH - disabled by default in Memorystore
  auth_enabled = false

  # No TLS
  transit_encryption_mode = "DISABLED"

  # Redis version
  redis_version = "REDIS_7_0"

  # Memory policy
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  labels = {
    environment = var.environment
    service     = "jambonz"
  }

  depends_on = [google_service_networking_connection.private_services]
}
