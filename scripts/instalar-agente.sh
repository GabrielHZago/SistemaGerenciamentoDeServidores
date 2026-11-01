#!/bin/bash
# VMs srv-monitor-01/02/03 (.11/.12/.13): só o agente que envia hardware
# Uso: sudo bash instalar-agente.sh srv-monitor-01
set -e
NOME=${1:?Informe o nome: srv-monitor-01, 02 ou 03}
sudo hostnamectl set-hostname "$NOME"
sudo sed -i "/cdrom/d" /etc/apt/sources.list; sudo apt update && sudo apt install -y python3-psutil python3-requests curl
sudo mkdir -p /opt/agente
curl -fsSL https://raw.githubusercontent.com/EduardoCorrea01/monitoramento-data-center/main/agente/main.py | sudo tee /opt/agente/main.py >/dev/null
# Correção: a API exige os campos "servidor" e "disco", que o agente original não envia
sudo sed -i 's/"server_id": AGENTE_ID,/"server_id": AGENTE_ID,\n        "servidor": AGENTE_ID,\n        "disco": m["disco"]["uso_porcentagem"],/' /opt/agente/main.py
sudo tee /etc/systemd/system/monitor-agente.service >/dev/null <<E2
[Unit]
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/bin/python3 -u /opt/agente/main.py
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
E2
sudo systemctl daemon-reload && sudo systemctl enable --now monitor-agente
sleep 5; journalctl -u monitor-agente -n 15 --no-pager
