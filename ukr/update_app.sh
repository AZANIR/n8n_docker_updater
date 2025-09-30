#!/bin/bash
# Скрипт автоматичного оновлення Docker Compose додатку
# Файл: update_app.sh

set -o errexit
set -o nounset
set -o pipefail

# === Конфіг ===
APP_DIR="/opt/n8n-docker-caddy"      # Змініть на ваш шлях
LOG_FILE="/var/log/docker_update.log"
THRESHOLD=85                         # NEW: поріг % використання диска для автоприбирання
MOUNTPOINT="/"                       # NEW: який розділ моніторити; зазвичай "/"

# === Логер ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# === Нотифікації (опційно) ===
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

# === Диск: зняття показників і логування (NEW) ===
get_disk_stats() {
  # Повертає: "<use_percent> <avail_human> <mountpoint>"
  # Використовуємо POSIX-вивід df -P, а для людиночитного також df -h
  local line usep mp avail_h
  # % використання (без знака %)
  usep=$(df -P "${MOUNTPOINT}" | awk 'NR==2{gsub("%","",$5); print $5}')
  # Людиночитний рядок для логу
  line=$(df -h "${MOUNTPOINT}" | sed -n '2p')
  # Витягаємо Avail (4-та колонка у df -h)
  avail_h=$(echo "${line}" | awk '{print $4}')
  mp=$(echo "${line}" | awk '{print $6}')
  echo "${usep} ${avail_h} ${mp}"
}

log_disk_usage() {
  local usep avail_h mp
  read -r usep avail_h mp < <(get_disk_stats)
  log "Disk usage on ${mp}: ${usep}% used, ${avail_h} available (df -h)"
}

# === Автоочистка Docker при високому заповненні диска (NEW) ===
maybe_prune_docker() {
  local usep avail_h mp
  read -r usep avail_h mp < <(get_disk_stats)
  if (( usep >= THRESHOLD )); then
    log "Usage ${usep}% >= ${THRESHOLD}% → running Docker prune…"
    # Спочатку builder cache
    if docker builder prune -a -f; then
      log "Docker builder cache pruned"
    else
      log "WARN: docker builder prune failed"
    fi
    # Потім загальна чистка
    if docker system prune -a --volumes -f; then
      log "Docker system prune done"
    else
      log "WARN: docker system prune failed"
    fi
    log_disk_usage
  else
    log "Usage ${usep}% < ${THRESHOLD}% → prune skipped"
  fi
}

# === Старт ===
log "=== Початок оновлення Docker Compose додатку ==="
log_disk_usage          # NEW: лог до оновлення
maybe_prune_docker      # NEW: спроба прибирання перед оновленням

# Перевірка директорії
if [ ! -d "$APP_DIR" ]; then
  log "ПОМИЛКА: Директорія $APP_DIR не існує!"
  send_notification "ПОМИЛКА: Директорія не знайдена"
  exit 1
fi

cd "$APP_DIR" || {
  log "ПОМИЛКА: Не вдалося перейти до директорії $APP_DIR"
  send_notification "ПОМИЛКА: Не вдалося перейти до директорії"
  exit 1
}

log "Перейшли до директорії: $(pwd)"

# Бекап compose
log "Створення резервної копії поточної конфігурації..."
cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Оновлення образів
log "Завантаження найновіших образів..."
if docker compose pull; then
  log "Образи успішно оновлені"
else
  log "ПОПЕРЕДЖЕННЯ: Деякі образи можливо не оновилися"
  send_notification "ПОПЕРЕДЖЕННЯ: Проблеми з оновленням образів"
fi

# Зупинка контейнерів
log "Зупинка поточних контейнерів..."
if docker compose down; then
  log "Контейнери успішно зупинені"
else
  log "ПОМИЛКА: Не вдалося зупинити контейнери"
  send_notification "ПОМИЛКА: Не вдалося зупинити контейнери"
  exit 1
fi

log "Пропускаємо автоматичне очищення образів для безпеки"

# Запуск контейнерів
log "Запуск оновлених контейнерів..."
if docker compose up -d; then
  log "Контейнери успішно запущені"
  send_notification "✅ Docker додаток успішно оновлено"
else
  log "ПОМИЛКА: Не вдалося запустити контейнери"
  send_notification "❌ ПОМИЛКА: Не вдалося запустити контейнери"
  log "Спроба відновлення з резервної копії..."
  BACKUP_FILE=$(ls -1t docker-compose.yml.backup.* 2>/dev/null | head -1 || true)
  if [ -n "${BACKUP_FILE:-}" ]; then
    cp "$BACKUP_FILE" docker-compose.yml
    docker compose up -d || true
    log "Відновлення з резервної копії завершено"
    send_notification "⚠️ Відновлено з резервної копії"
  fi
  exit 1
fi

# Перевірка стану
log "Перевірка стану контейнерів..."
sleep 10
if docker compose ps | grep -q "Up"; then
  log "Контейнери працюють нормально"
  send_notification "✅ Оновлення завершено успішно"
else
  log "ПОПЕРЕДЖЕННЯ: Деякі контейнери можуть не працювати"
  send_notification "⚠️ Можливі проблеми з контейнерами"
fi

# Фінальний стан диска + можливе прибирання (NEW)
log_disk_usage
maybe_prune_docker

# Прибирання старих логів (залишити останні 30 днів)
find /var/log -name "docker_update.log*" -mtime +30 -delete 2>/dev/null || true

log "=== Оновлення завершено ==="
echo "Оновлення завершено. Перевірте лог: $LOG_FILE"
