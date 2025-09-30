# n8n Docker Updater

Automated tool for updating n8n Docker Compose applications on Linux servers with disk monitoring support, automatic cleanup, and notifications.

## 📋 Description

This project contains Bash scripts for automatically updating n8n (or any other Docker Compose application) with the following capabilities:

- ✅ Safe Docker image updates
- ✅ Automatic configuration backup creation
- ✅ Disk usage monitoring
- ✅ Automatic Docker cleanup when reaching usage threshold
- ✅ Recovery from backup on errors
- ✅ Telegram integration for notifications
- ✅ Detailed logging of all operations

## 📁 Project Structure

```
n8n_docker_updater/
├── README.md
├── README-UKR.md        # Ukrainian version of documentation
├── README-ENG.md        # English version of documentation
├── eng/
│   └── update_app.sh    # English version of script
└── ukr/
    └── update_app.sh    # Ukrainian version of script
```

## 🚀 Quick Start

### 1. Download Script

```bash
# Clone repository
git clone https://github.com/AZANIR/n8n_docker_updater.git
cd n8n_docker_updater

# Or download specific script
wget https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/eng/update_app.sh
# or
wget https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/ukr/update_app.sh
```

### 2. Configure Script

Edit the main parameters in the script:

```bash
# Open script for editing
nano update_app.sh
```

Change the following variables:

```bash
APP_DIR="/opt/n8n-docker-caddy"      # Path to your n8n Docker Compose
LOG_FILE="/var/log/docker_update.log" # Log file
THRESHOLD=85                         # Disk usage threshold (%)
MOUNTPOINT="/"                       # Partition to monitor
```

### 3. Set Execute Permissions

```bash
chmod +x update_app.sh
```

### 4. Test Run

```bash
sudo ./update_app.sh
```

## ⚙️ Detailed Configuration

### Telegram Notifications Configuration (optional)

To receive Telegram notifications:

1. Create a bot via [@BotFather](https://t.me/botfather)
2. Get the bot token
3. Find your chat_id (you can use [@userinfobot](https://t.me/userinfobot))

Set environment variables:

sudo nano /root/.bashrc     # or /root/.profile


```bash
# Add to ~/.bashrc or /etc/environment
export TG_TOKEN="your_bot_token"
export TG_CHAT_ID="your_chat_id"
```

Update changes:

```bash
source /root/.bashrc
```
Verification

In the shell under which the script runs:

```bash
echo $TG_TOKEN
echo $TG_CHAT_ID
```

Or create a configuration file:

```bash
# Create file /etc/default/docker-updater
echo 'TG_TOKEN="your_bot_token"' | sudo tee /etc/default/docker-updater
echo 'TG_CHAT_ID="your_chat_id"' | sudo tee -a /etc/default/docker-updater
```

### n8n Directory Structure

Make sure your n8n structure looks approximately like this:

```
/opt/n8n-docker-caddy/
├── docker-compose.yml
├── .env
├── data/
└── caddy_data/
```

## 📅 Setting Up Automatic Updates via Cron

### Option 1: Weekly Updates at 3:00 AM Sunday

```bash
# Open crontab
sudo crontab -e

# Add line (weekly update at 3:00 AM Sunday)
0 3 * * 0 /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1
```

### Option 2: Other Useful Schedules

```bash
# Daily at 2:00 AM
0 2 * * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Wednesday at 4:00 AM
0 4 * * 3 /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Monthly on the 1st at 3:30 AM
30 3 1 * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1

# Every 12 hours
0 */12 * * * /bin/bash /path/to/update_app.sh >> /var/log/docker_update_cron.log 2>&1
```

### Option 3: Extended Configuration with Environment Variable Loading

Create wrapper script `/usr/local/bin/n8n-updater.sh`:

```bash
#!/bin/bash
# Load environment variables
if [ -f /etc/default/docker-updater ]; then
    source /etc/default/docker-updater
fi

# Run main script
/path/to/update_app.sh
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/n8n-updater.sh
```

Add to crontab:

```bash
# Sunday at 3:00 AM with configuration loading
0 3 * * 0 /usr/local/bin/n8n-updater.sh >> /var/log/docker_update_cron.log 2>&1
```

## 🔧 Detailed Configuration

### Main Script Parameters

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `APP_DIR` | Path to directory with docker-compose.yml | `/opt/n8n-docker-caddy` |
| `LOG_FILE` | File for logging | `/var/log/docker_update.log` |
| `THRESHOLD` | Disk usage threshold for auto-cleanup (%) | `85` |
| `MOUNTPOINT` | Disk partition to monitor | `/` |

### System Requirements

- Linux server with Docker and Docker Compose
- Bash 4.0+
- Utilities: `curl`, `df`, `awk`, `find`
- Sudo rights for Docker operations

## 📊 Monitoring and Logging

### Viewing Logs

```bash
# Latest entries
tail -f /var/log/docker_update.log

# Last 50 lines
tail -n 50 /var/log/docker_update.log

# Logs for specific date
grep "2024-12-30" /var/log/docker_update.log

# Error logs
grep "ERROR\|WARN" /var/log/docker_update.log
```

### Log Rotation Setup

Create file `/etc/logrotate.d/docker-update`:

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

### Check Container Status After Update

```bash
# Container status
docker compose ps

# Container logs
docker compose logs -f

# Container resources
docker stats

# Docker disk usage
docker system df
```

## 🛠️ Troubleshooting

### Problem: Script cannot stop containers

**Solution:**
```bash
# Check if Docker is running
sudo systemctl status docker

# Force stop containers
cd /opt/n8n-docker-caddy
sudo docker compose down --timeout 30
```

### Problem: Not enough disk space

**Solution:**
```bash
# Manual Docker cleanup
sudo docker system prune -a --volumes -f
sudo docker builder prune -a -f

# Check large files
sudo du -sh /var/lib/docker/*
```

### Problem: Telegram notifications not working

**Solution:**
```bash
# Check environment variables
echo $TG_TOKEN
echo $TG_CHAT_ID

# Test message
curl -X POST "https://api.telegram.org/$TG_TOKEN/sendMessage" \
     -d chat_id="$TG_CHAT_ID" \
     -d text="Test message"
```

## 🔒 Security

### Security Recommendations:

1. **Don't store tokens directly in script** - use environment variables
2. **Limit script access permissions:**
   ```bash
   sudo chown root:root update_app.sh
   sudo chmod 700 update_app.sh
   ```
3. **Regularly check logs** for suspicious activity
4. **Create backups** of important data before updates

## 🤝 Contributing

Welcome to contribute to the project:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📄 License

This project is distributed under the MIT License. See `LICENSE` file for details.

## 📞 Support

If you have problems or questions:

1. Check [Issues](https://github.com/AZANIR/n8n_docker_updater/issues)
2. Create new Issue with detailed problem description
3. Add logs and system information

## 🔄 Script Updates

To update script to the latest version:

```bash
cd /path/to/n8n_docker_updater
git pull origin master

# Or download directly
wget -O update_app.sh https://raw.githubusercontent.com/AZANIR/n8n_docker_updater/master/eng/update_app.sh
```

---

**Author:** AZANIR  
**Last Updated:** September 2025