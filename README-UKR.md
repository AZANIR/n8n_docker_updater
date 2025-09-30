# n8n Docker Updater

Автоматизований інструмент для оновлення n8n Docker Compose додатків на Linux серверах з підтримкою моніторингу диску, автоматичного очищення та сповіщень.

## 📋 Опис

Цей проект містить Bash-скрипти для автоматичного оновлення n8n (або будь-якого іншого Docker Compose додатку) з наступними можливостями:

- ✅ Безпечне оновлення Docker образів
- ✅ Автоматичне створення резервних копій конфігурації
- ✅ Моніторинг використання диску
- ✅ Автоматичне очищення Docker при досягненні порогу заповнення
- ✅ Відновлення з резервної копії при помилках
- ✅ Інтеграція з Telegram для сповіщень
- ✅ Детальне логування всіх операцій

## 📁 Структура проекту

```
n8n_docker_updater/
├── README.md
├── README-UKR.md        # Українська версія документації
├── README-ENG.md        # Англійська версія документації
├── eng/
│   └── update_app.sh    # Англійська версія скрипта
└── ukr/
    └── update_app.sh    # Українська версія скрипта
```

## 🚀 Швидкий старт

### 1. Завантаження скрипта

```bash
# Клонування репозиторію
git clone https://github.com/AZANIR/n8n_docker_updater.git
cd n8n_docker_updater

# Або завантаження конкретного скрипта
wget https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/eng/update_app.sh
# або
wget https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/ukr/update_app.sh
```

### 2. Налаштування скрипта

Відредагуйте основні параметри у скрипті:

```bash
# Відкрийте скрипт для редагування
nano update_app.sh
```

Змініть наступні змінні:

```bash
APP_DIR="/opt/n8n-docker-caddy"      # Шлях до вашого n8n Docker Compose
LOG_FILE="/var/log/docker_update.log" # Файл логів
THRESHOLD=85                         # Поріг використання диску (%)
MOUNTPOINT="/"                       # Розділ для моніторингу
```

### 3. Надання прав виконання

```bash
chmod +x update_app.sh
```

### 4. Тестовий запуск

```bash
sudo ./update_app.sh
```

## ⚙️ Детальне налаштування

### Конфігурація Telegram сповіщень (опційно)

Для отримання сповіщень в Telegram:

1. Створіть бота через [@BotFather](https://t.me/botfather)
2. Отримайте токен бота
3. Дізнайтеся свій chat_id (можна через [@userinfobot](https://t.me/userinfobot))

Встановіть змінні середовища:

sudo nano /root/.bashrc     # або /root/.profile

```bash
# Додайте в ~/.bashrc або /etc/environment
export TG_TOKEN="ваш_токен_бота"
export TG_CHAT_ID="ваш_chat_id"
```

оновіть зміни:

```bash
source /root/.bashrc
```

Перевірка

У shell, під яким працює скрипт:
```bash
echo $TG_TOKEN
echo $TG_CHAT_ID
```

Або створіть файл з налаштуваннями:

```bash
# Створіть файл /etc/default/docker-updater
echo 'TG_TOKEN="ваш_токен_бота"' | sudo tee /etc/default/docker-updater
echo 'TG_CHAT_ID="ваш_chat_id"' | sudo tee -a /etc/default/docker-updater
```

### Структура директорій n8n

Переконайтеся, що ваша структура n8n виглядає приблизно так:

```
/opt/n8n-docker-caddy/
├── docker-compose.yml
├── .env
├── data/
└── caddy_data/
```

## 📅 Налаштування автоматичних оновлень через Cron

### Варіант 1: Оновлення щонеділі о 3:00 ранку

```bash
# Відкрийте crontab
sudo crontab -e

# Додайте рядок (оновлення щонеділі о 3:00)
0 3 * * 0 /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1
```

### Варіант 2: Інші корисні розклади

```bash
# Щодня о 2:00 ранку
0 2 * * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Щосереди о 4:00 ранку
0 4 * * 3 /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Щомісяця 1 числа о 3:30
30 3 1 * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Кожні 12 годин
0 */12 * * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1
```

### Варіант 3: Розширена конфігурація з завантаженням змінних середовища

Створіть wrapper-скрипт `/usr/local/bin/n8n-updater.sh`:

```bash
#!/bin/bash
# Завантаження змінних середовища
if [ -f /etc/default/docker-updater ]; then
    source /etc/default/docker-updater
fi

# Запуск основного скрипта
/path/to/update_app.sh
```

Зробіть його виконуваним:

```bash
sudo chmod +x /usr/local/bin/n8n-updater.sh
```

Додайте до crontab:

```bash
# Щонеділі о 3:00 з завантаженням конфігурації
0 3 * * 0 /usr/local/bin/n8n-updater.sh >> /var/log/docker_update_cron.log 2>&1
```

## 🔧 Детальна конфігурація

### Основні параметри скрипта

| Параметр | Опис | Значення за замовчуванням |
|----------|------|---------------------------|
| `APP_DIR` | Шлях до директорії з docker-compose.yml | `/opt/n8n-docker-caddy` |
| `LOG_FILE` | Файл для логування | `/var/log/docker_update.log` |
| `THRESHOLD` | Поріг використання диску для автоочищення (%) | `85` |
| `MOUNTPOINT` | Розділ диску для моніторингу | `/` |

### Системні вимоги

- Linux сервер з Docker та Docker Compose
- Bash 4.0+
- Утиліти: `curl`, `df`, `awk`, `find`
- Права sudo для роботи з Docker

## 📊 Моніторинг та логування

### Переглядання логів

```bash
# Останні записи
tail -f /var/log/docker_update.log

# Останні 50 рядків
tail -n 50 /var/log/docker_update.log

# Логи за конкретну дату
grep "2024-12-30" /var/log/docker_update.log

# Логи помилок
grep "ERROR\|WARN" /var/log/docker_update.log
```

### Налаштування ротації логів

Створіть файл `/etc/logrotate.d/docker-update`:

```
/var/log/docker_update.log {
    weekly
    missingok
    rotate 8
    compress
    delaycompress
    notifempty
    postrotate
        /bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

### Перевірка стану контейнерів після оновлення

```bash
# Статус контейнерів
docker compose ps

# Логи контейнерів
docker compose logs -f

# Ресурси контейнерів
docker stats

# Використання диску Docker
docker system df
```

## 🛠️ Усунення несправностей

### Проблема: Скрипт не може зупинити контейнери

**Рішення:**
```bash
# Перевірте, чи працює Docker
sudo systemctl status docker

# Принудова зупинка контейнерів
cd /opt/n8n-docker-caddy
sudo docker compose down --timeout 30
```

### Проблема: Недостатньо місця на диску

**Рішення:**
```bash
# Ручне очищення Docker
sudo docker system prune -a --volumes -f
sudo docker builder prune -a -f

# Перевірка великих файлів
sudo du -sh /var/lib/docker/*
```

### Проблема: Telegram сповіщення не працюють

**Рішення:**
```bash
# Перевірка змінних середовища
echo $TG_TOKEN
echo $TG_CHAT_ID

# Тестове повідомлення
curl -X POST "https://api.telegram.org/$TG_TOKEN/sendMessage" \
     -d chat_id="$TG_CHAT_ID" \
     -d text="Тестове повідомлення"
```

## 🔒 Безпека

### Рекомендації з безпеки:

1. **Не зберігайте токени в скрипті напряму** - використовуйте змінні середовища
2. **Обмежте права доступу до скрипта:**
   ```bash
   sudo chown root:root update_app.sh
   sudo chmod 700 update_app.sh
   ```
3. **Регулярно перевіряйте логи** на предмет підозрілої активності
4. **Створюйте резервні копії** важливих даних перед оновленнями

## 🤝 Внесок у проект

Ласкаво просимо до участі в розвитку проекту:

1. Fork репозиторію
2. Створіть feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit ваші зміни (`git commit -m 'Add some AmazingFeature'`)
4. Push до branch (`git push origin feature/AmazingFeature`)
5. Відкрийте Pull Request

## 📄 Ліцензія

Цей проект розповсюджується під ліцензією MIT. Див. файл `LICENSE` для деталей.

## 📞 Підтримка

Якщо у вас виникли проблеми або питання:

1. Перевірте [Issues](https://github.com/AZANIR/n8n_docker_updater/issues)
2. Створіть новий Issue з детальним описом проблеми
3. Додайте логи та системну інформацію

## 🔄 Оновлення скрипта

Для оновлення скрипта до останньої версії:

```bash
cd /path/to/n8n_docker_updater
git pull origin master

# Або завантажте напряму
wget -O update_app.sh https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/eng/update_app.sh
```

---

**Автор:** AZANIR  
**Останнє оновлення:** Вересень 2025