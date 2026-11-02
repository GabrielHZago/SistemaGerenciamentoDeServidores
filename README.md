# Monitoramento de Data Center: VMs prontas (.ova)

Projeto: https://github.com/EduardoCorrea01/monitoramento-data-center

Um único arquivo `monitoramento-datacenter.ova` contém as 4 VMs.

## Download
O `.ova` é grande demais para o repositório. Baixe em: (https://drive.google.com/drive/folders/1dmVx84U_-eYDFe0vSKO8UChmr3TseddC?usp=drive_link)

## Arquitetura
```text
srv-monitor-01 (.11) --\
srv-monitor-02 (.12) ---- POST http://192.168.56.20/monitoramento --> API -> MySQL -> Dashboard
srv-monitor-03 (.13) --/
```

## Conteúdo do .ova
| VM no VirtualBox | Hostname | IP fixo | Função |
|---|---|---|---|
| CENTRAL | monitor-central | 192.168.56.20 | API (Flask + Gunicorn), worker de OFFLINE, MySQL, Nginx e dashboard |
| Servidor-01 | srv-monitor-01 | 192.168.56.11 | Agente que envia CPU, RAM e disco a cada 30s |
| Servidor-02 | srv-monitor-02 | 192.168.56.12 | Agente |
| Servidor-03 | srv-monitor-03 | 192.168.56.13 | Agente (usado no teste de falha) |

Usuário das VMs: `vboxuser` (mesma senha definida na criação).
Banco: `monitoring`, usuário `monitoring`, senha `Monitor@123`.

## Pré-requisitos no computador
1. VirtualBox instalado.
2. Virtualização (SVM/AMD-V ou VT-x) ativada na BIOS e Hyper-V desligado no Windows.
3. Rede host-only `192.168.56.0/24` existindo no VirtualBox (Arquivo > Ferramentas > Gerenciador de Rede > Host-only, IP do host 192.168.56.1).

## Importação
1. Baixe `monitoramento-datacenter.ova` (link na seção Download).
2. VirtualBox > Arquivo > Importar Appliance > selecione o arquivo. As 4 VMs aparecem juntas.
3. Em "Política de endereço MAC", escolha **Incluir todos os endereços MAC**.
4. Confira a rede de cada VM: Adaptador 1 = Placa de rede exclusiva de hospedeiro (host-only), Adaptador 2 = NAT.

## Como o .ova foi gerado
Em cada VM: `sudo truncate -s0 /etc/machine-id && sudo poweroff`. Depois, no Windows:
```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" export CENTRAL Servidor-01 Servidor-02 Servidor-03 -o monitoramento-datacenter.ova --options manifest,macs
```

## Ordem de inicialização
1. Ligue a **CENTRAL** primeiro e espere o boot terminar.
2. Ligue os servidores 01, 02 e 03.
Tudo inicia sozinho (serviços systemd): `monitor-api`, `monitor-worker`, `nginx`, `mysql` na central e `monitor-agente` nos servidores.

## Testes
- Dashboard: abra http://192.168.56.20/dashboard/ no navegador do computador.
- API: `curl http://192.168.56.20/servidores` (também `/metricas`, `/alertas`, `/eventos`, `/resumo`).
- Banco (na central): `sudo mysql monitoring -e "SELECT * FROM servers;"`
- Log do agente (no servidor): `journalctl -u monitor-agente -f` (deve mostrar "Resposta do backend: 201").
- Status dos serviços (na central): `systemctl is-active nginx monitor-api monitor-worker`

### Teste de falha (OFFLINE)
1. Desligue o Servidor-03 (ou rode `sudo systemctl stop monitor-agente` nele).
2. Após cerca de 2 minutos sem dados, ele aparece como OFFLINE no dashboard, com alerta CRITICAL.
3. Ligue de novo: volta a ONLINE e o alerta é resolvido automaticamente.

### Teste de alerta de consumo
No servidor, gere carga de CPU: `yes > /dev/null &` (pare com `killall yes`). Acima de 85% aparece um alerta.

## Problemas comuns
| Sintoma | Solução |
|---|---|
| VM não liga: VERR_SVM_DISABLED / VERR_NEM_NOT_AVAILABLE | Ativar SVM na BIOS; `bcdedit /set hypervisorlaunchtype off` e desligar Integridade de memória; reiniciar o PC |
| Agente: "Connection refused" | Central desligada ou serviços parados; na central `sudo systemctl restart nginx monitor-api monitor-worker` |
| Agente: timeout | Rede host-only errada; confira `ip a` (deve ter o IP fixo na enp0s3) |
| Dashboard com erro de API | Ctrl+F5; confira `curl http://192.168.56.20/servidores` |
| `apt update` com erro de cdrom | `sudo sed -i '/cdrom/d' /etc/apt/sources.list` |

## Observação
A correção aplicada no agente (`/opt/agente/main.py`) adiciona os campos `servidor` e `disco` exigidos pela API, que o agente original do repositório não enviava.

## Estrutura do repositório
```text
.
├── README.md
├── .gitignore              # impede subir .ova/.vdi por engano
└── scripts/
    ├── instalar-central.sh # na VM central: sudo bash instalar-central.sh
    └── instalar-agente.sh  # em cada servidor: sudo bash instalar-agente.sh srv-monitor-01
```

## Como reinstalar do zero (sem o .ova)
1. Crie 4 VMs Ubuntu 22.04 com os IPs fixos da tabela (netplan) e os adaptadores host-only + NAT.
2. Na central: `sudo bash scripts/instalar-central.sh`
3. Em cada servidor: `sudo bash scripts/instalar-agente.sh srv-monitor-0N`
