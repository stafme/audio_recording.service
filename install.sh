#!/bin/bash

# Переменные
SERVICE_NAME="audio_recording.service"
SCRIPT_PATH="/home/piadmin/run.sh"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
WAV_DIR="/home/piadmin/wav"

# Обновление системы и установка необходимых пакетов
echo "Обновление системы и установка необходимых пакетов..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y sox alsa-utils msmtp ppp

# Проверка наличия run.sh
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Ошибка: Скрипт $SCRIPT_PATH не найден."
    exit 1
fi

# Создание папки для сохранения записей
if [ ! -d "$WAV_DIR" ]; then
    echo "Создание директории для аудиофайлов: $WAV_DIR"
    mkdir -p "$WAV_DIR"
fi

# Настройка службы systemd
echo "Настройка службы systemd..."
cat <<EOL | sudo tee $SERVICE_PATH > /dev/null
[Unit]
Description=Audio Recording Service
After=network.target sound.target

[Service]
ExecStart=/bin/bash $SCRIPT_PATH
WorkingDirectory=/home/piadmin
StandardOutput=syslog
StandardError=syslog
Restart=always
User=piadmin

[Install]
WantedBy=multi-user.target
EOL

# Перезагрузка служб systemd
echo "Перезагрузка служб systemd..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# Настройка msmtp
echo "Настройка msmtp..."
MSMTP_CONFIG="/home/piadmin/.msmtprc"
cat <<EOL > "$MSMTP_CONFIG"
account default
host smtp.example.com
port 587
auth on
user your_email@example.com
password your_password
from your_email@example.com
tls on
tls_starttls on
logfile /home/piadmin/msmtp.log
EOL

# Задание правильных прав на файл msmtp
chmod 600 "$MSMTP_CONFIG"

# Настройка модема PPP (GPRS/LTE)
echo "Настройка PPP..."
PPP_CONFIG="/etc/ppp/peers/gprs"
sudo cat <<EOL | sudo tee $PPP_CONFIG > /dev/null
/dev/ttyUSB2 115200
connect "/usr/sbin/chat -v -f /etc/chatscripts/gprs"
noauth
defaultroute
usepeerdns
user "internet"
password "internet"
persist
nodetach
EOL

# Настройка chat-сценария для модема
sudo mkdir -p /etc/chatscripts
CHAT_CONFIG="/etc/chatscripts/gprs"
sudo cat <<EOL | sudo tee $CHAT_CONFIG > /dev/null
ABORT 'BUSY'
ABORT 'NO CARRIER'
ABORT 'ERROR'
'' AT
OK ATZ
OK AT+CGDCONT=1,"IP","internet"
OK ATD*99#
CONNECT ''
EOL

# Вывод информации и завершение
echo "Установка завершена!"
echo "Запустите службу командой: sudo systemctl start $SERVICE_NAME"
echo "Для установки интернет-соединения используйте: sudo pon gprs"
