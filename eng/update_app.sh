#!/bin/bash
# Script to automatically update a Docker Compose application
# File: update_app.sh

set -o errexit
set -o nounset
set -o pipefail

# === Configuration ===
APP_DIR="/opt/n8n-docker-caddy"     # Change to your app path
LOG_FILE="/var/log/docker_update.log"
THRESHOLD=85                        # % of disk usage to trigger auto-cleanup
MOUNTPOINT="/"                      # Disk to monitor

# === Logger ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# === Notifications (optional) ===
send_notification() {
  # expects TG_TOKEN and TG_CHAT_ID in env
  if [[ -n "${TG_TOKEN:-}" && -n "${TG_CHAT_ID:-}" ]]; then
    # логуватимемо відповідь від Telegram для дебага
    local msg="Docker update: $*"
    local resp http_code

    resp=$(curl -sS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d chat_id="${TG_CHAT_ID}" \
      --data-urlencode text="${msg}" \
      -w "\nHTTP_CODE:%{http_code}" ) || true

    http_code=$(echo "$resp" | sed -n 's/^HTTP_CODE:\([0-9]\+\)$/\1/p')
    log "Telegram response (HTTP ${http_code:-unknown}): $(echo "$resp" | sed '/^HTTP_CODE:/d')"
  else
    log "Notification skipped: TG_TOKEN or TG_CHAT_ID is not set"
  fi
}

# === Disk usage logging ===
get_disk_stats() {
  # Output: "<use_percent> <avail_human> <mountpoint>"
  usep=$(df -P "${MOUNTPOINT}" | awk 'NR==2{gsub("%","",$5); print $5}')
  line=$(df -h "${MOUNTPOINT}" | sed -n '2p')
  avail_h=$(echo "${line}" | awk '{print $4}')
  mp=$(echo "${line}" | awk '{print $6}')
  echo "${usep} ${avail_h} ${mp}"
}

log_disk_usage() {
  local usep avail_h mp
  read -r usep avail_h mp < <(get_disk_stats)
  log "Disk usage on ${mp}: ${usep}% used, ${avail_h} available (df -h)"
}

# === Automatic Docker cleanup when threshold exceeded ===
maybe_prune_docker() {
  local usep avail_h mp
  read -r usep avail_h mp < <(get_disk_stats)
  if (( usep >= THRESHOLD )); then
    log "Disk usage ${usep}% >= ${THRESHOLD}% → running Docker prune…"
    if docker builder prune -a -f; then
      log "Docker builder cache pruned"
    else
      log "WARNING: docker builder prune failed"
    fi
    if docker system prune -a --volumes -f; then
      log "Docker system prune completed"
    else
      log "WARNING: docker system prune failed"
    fi
    log_disk_usage
  else
    log "Disk usage ${usep}% < ${THRESHOLD}% → prune skipped"
  fi
}

# === START ===
log "=== Starting Docker Compose application update ==="
log_disk_usage
maybe_prune_docker

# Ensure app directory exists
if [ ! -d "$APP_DIR" ]; then
  log "ERROR: Directory $APP_DIR does not exist!"
  send_notification "ERROR: Directory not found"
  exit 1
fi

cd "$APP_DIR" || {
  log "ERROR: Cannot enter $APP_DIR"
  send_notification "ERROR: Cannot enter app directory"
  exit 1
}

log "Entered directory: $(pwd)"

# Backup docker-compose
log "Creating backup of current configuration..."
cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Pull new images
log "Pulling latest images..."
if docker compose pull; then
  log "Images pulled successfully"
else
  log "WARNING: Some images may not have been updated"
  send_notification "WARNING: Issues during image pull"
fi

# Stop containers
log "Stopping running containers..."
if docker compose down; then
  log "Containers stopped successfully"
else
  log "ERROR: Failed to stop containers"
  send_notification "ERROR: Failed to stop containers"
  exit 1
fi

log "Skipping automatic image cleanup for safety"

# Start updated containers
log "Starting updated containers..."
if docker compose up -d; then
  log "Containers started successfully"
  send_notification "✅ Docker application updated successfully"
else
  log "ERROR: Failed to start containers"
  send_notification "❌ ERROR: Failed to start containers"
  log "Attempting recovery from backup..."
  BACKUP_FILE=$(ls -1t docker-compose.yml.backup.* 2>/dev/null | head -1 || true)
  if [ -n "${BACKUP_FILE:-}" ]; then
    cp "$BACKUP_FILE" docker-compose.yml
    docker compose up -d || true
    log "Recovery from backup completed"
    send_notification "⚠️ Recovered from backup"
  fi
  exit 1
fi

# Verify container status
log "Checking container status..."
sleep 10
if docker compose ps | grep -q "Up"; then
  log "Containers are running normally"
  send_notification "✅ Update completed successfully"
else
  log "WARNING: Some containers may not be running"
  send_notification "⚠️ Possible container issues"
fi

# Log final disk usage and prune if needed
log_disk_usage
maybe_prune_docker

# Clean up old logs (keep last 30 days)
find /var/log -name "docker_update.log*" -mtime +30 -delete 2>/dev/null || true

log "=== Update process finished ==="
echo "Update completed. Check log: $LOG_FILE"
