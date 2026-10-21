# Memorystore Redis configuration for jambonz on GCP
#
# STANDARD_HA keeps a replica in another zone with automatic failover. AUTH is
# on; the auth string is kept in Secret Manager and read by each VM at boot.
# Reached only over the private service connection.

# ------------------------------------------------------------------------------
# MEMORYSTORE REDIS INSTANCE
# ------------------------------------------------------------------------------

resource "google_redis_instance" "jambonz" {
  name           = "${var.name_prefix}-redis"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = var.region

  # Primary and replica in different zones (STANDARD_HA)
  location_id             = local.zones[0]
  alternative_location_id = var.redis_tier == "STANDARD_HA" ? local.zones[1 % length(local.zones)] : null

  # Connect via private network
  authorized_network = google_compute_network.jambonz.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  auth_enabled = true

  # TODO(soc2): SERVER_AUTHENTICATION (TLS) needs every jambonz component to
  # trust Memorystore's own CA certificate, which is not yet confirmed. Traffic
  # stays on the private service connection.
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
