#!/bin/bash
# VM monitor-central (192.168.56.20): API + worker + MySQL + Nginx + dashboard
set -e
REPO=https://github.com/EduardoCorrea01/monitoramento-data-center
DBPASS=${DBPASS:-Monitor@123}
sudo sed -i "/cdrom/d" /etc/apt/sources.list; sudo apt update
sudo apt install -y git python3-venv python3-pip mysql-server nginx
sudo git clone $REPO /opt/monitoramento || sudo git -C /opt/monitoramento pull
cd /opt/monitoramento/back-end
sudo python3 -m venv .venv
sudo .venv/bin/pip install -r requirements-server.txt
# Banco MySQL
sudo mysql -e "CREATE DATABASE IF NOT EXISTS monitoring; CREATE USER IF NOT EXISTS 'monitoring'@'localhost' IDENTIFIED BY '$DBPASS'; GRANT ALL ON monitoring.* TO 'monitoring'@'localhost'; FLUSH PRIVILEGES;"
sudo cp .env.example .env
sudo tee -a .env >/dev/null <<E2
DB_USER=monitoring
DB_PASSWORD=$DBPASS
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=monitoring
E2
# Serviços systemd (API em 127.0.0.1:5000 atrás do Nginx, e worker de OFFLINE)
sudo tee /etc/systemd/system/monitor-api.service >/dev/null <<E2
[Unit]
After=network.target mysql.service
[Service]
WorkingDirectory=/opt/monitoramento/back-end
ExecStart=/opt/monitoramento/back-end/.venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 "app:create_app()"
Restart=always
[Install]
WantedBy=multi-user.target
E2
sudo tee /etc/systemd/system/monitor-worker.service >/dev/null <<E2
[Unit]
After=monitor-api.service
[Service]
WorkingDirectory=/opt/monitoramento/back-end
ExecStart=/opt/monitoramento/back-end/.venv/bin/python availability_worker.py
Restart=always
[Install]
WantedBy=multi-user.target
E2
# Dashboard em http://192.168.56.20/dashboard/ apontando pra API da central
sudo sed -i "s#const API_BASE = .*#const API_BASE = 'http://192.168.56.20';#" /opt/monitoramento/dashboard/app.js
sudo tee /etc/nginx/sites-available/monitor >/dev/null <<'E2'
server {
    listen 80 default_server;
    location /dashboard/ { alias /opt/monitoramento/dashboard/; index index.html; }
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
E2
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor
sudo nginx -t && sudo systemctl restart nginx
sudo systemctl daemon-reload
sudo systemctl enable --now monitor-api monitor-worker
sleep 3; curl -s http://127.0.0.1/servidores && echo && echo "Central OK"
