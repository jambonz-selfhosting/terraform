# ---- shared by every jambonz startup script (included via $${common}) ----
#
# Secrets come from Secret Manager, read with this VM's service account; none
# is passed in instance metadata. Scripts run without xtrace (-x), so no secret
# is echoed into the startup-script log or the serial console.
PROJECT_ID="${project_id}"
SECRET_PREFIX="${secret_prefix}"

gcp_secret() {
  local token value i
  for i in $(seq 1 30); do
    token=$(curl -sf -H "Metadata-Flavor: Google" \
      "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" \
      | python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])') &&
    value=$(curl -sf -H "Authorization: Bearer $token" \
      "https://secretmanager.googleapis.com/v1/projects/$PROJECT_ID/secrets/$SECRET_PREFIX-$1/versions/latest:access" \
      | python3 -c 'import sys, json, base64; print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode())') &&
    { printf '%s' "$value"; return 0; }
    sleep 10
  done
  echo "FATAL: could not read secret $SECRET_PREFIX-$1 from Secret Manager" >&2
  return 1
}

# Google's Ops Agent sends the systemd journal (including SSH logins) and the
# jambonz application logs to Cloud Logging, where logging.tf keeps them for
# log_retention_days. It installs in the background a minute after the apps
# start, so its apt work doesn't compete with their startup, and waits for the
# dpkg lock instead of failing (the image's apt-daily timers fire at first boot).
install_ops_agent() {
  (
    sleep 60
    echo 'DPkg::Lock::Timeout "600";' > /etc/apt/apt.conf.d/90jambonz-dpkg-lock-timeout
    if ! systemctl list-unit-files google-cloud-ops-agent.service >/dev/null 2>&1; then
      for i in $(seq 1 10); do
        curl -sSfo /tmp/add-google-cloud-ops-agent-repo.sh https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh &&
          bash /tmp/add-google-cloud-ops-agent-repo.sh --also-install && break
        sleep 30
      done
    fi
    mkdir -p /etc/google-cloud-ops-agent
    cat > /etc/google-cloud-ops-agent/config.yaml <<'OPSAGENT'
logging:
  receivers:
    jambonz_app:
      type: files
      include_paths:
        - /home/jambonz/.pm2/logs/*.log
        - /var/log/mediajam/*.log
    journald:
      type: systemd_journald
  service:
    pipelines:
      jambonz:
        receivers: [jambonz_app, journald]
OPSAGENT
    systemctl restart google-cloud-ops-agent || true
  ) > /var/log/jambonz-ops-agent.log 2>&1 &
}
# ---- end shared ----
