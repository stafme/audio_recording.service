#!/bin/bash

# Скрипт установки программы и настройки служб

# Убедимся, что запускаем от имени root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root. Используйте sudo." 
   exit 1
fi

echo "Начинаем установку..."

# Устанавливаем необходимые пакеты
echo "Устанавливаем зависимости..."
apt update && apt install -y sox ppp msmtp

# Создаем рабочие папки
echo "Создаем папки..."
mkdir -p /home/piadmin/wav

# Копируем основной скрипт
echo "Копируем основной скрипт..."
cat > /home/piadmin/run.sh << 'EOF'
#!/bin/bash

while true; do
    # Устанавливаем имя файла с временной меткой
    file_name="/home/piadmin/wav/recording_$(date +%Y%m%d%H%M%S).wav"

    # Записываем звук в файл в течение 1 минуты
    sox -d -r 8000 -c 1 $file_name trim 0 1:00

    # Проверяем, существует ли файл
    if [ -f "$file_name" ]; then
        # Отправляем файл на почту с правильным вложением в фоне
        (
            echo "Subject: Audio File $(date +'%Y-%m-%d %H:%M:%S')"
            echo "MIME-Version: 1.0"
            echo "Content-Type: multipart/mixed; boundary=\"boundary\""
            echo
            echo "--boundary"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo "Content-Transfer-Encoding: 7bit"
            echo
            echo "Please find the attached audio file."
            echo
            echo "--boundary"
            echo "Content-Type: audio/wav; name=\"$(basename $file_name)\""
            echo "Content-Transfer-Encoding: base64"
            echo "Content-Disposition: attachment; filename=\"$(basename $file_name)\""
            echo
            base64 $file_name
            echo "--boundary--"
        ) | msmtp -a default -t YouEmail@ukr.net &  # Запуск в фоне

        # Удаляем файл после отправки
        rm -f $file_name
    else
        echo "Error: Audio file was not recorded."
    fi
done
EOF

# Делаем скрипт исполняемым
chmod +x /home/piadmin/run.sh

# Создаем службу для записи аудио
echo "Создаем службу audio_recording.service..."
cat > /etc/systemd/system/audio_recording.service << EOF
[Unit]
Description=Audio Recording Service
After=multi-user.target

[Service]
ExecStart=/bin/bash /home/piadmin/run.sh
Restart=always
User=piadmin

[Install]
WantedBy=multi-user.target
EOF

# Создаем службу для автоматического подключения к интернету
echo "Создаем службу gprs.service..."
cat > /etc/systemd/system/gprs.service << EOF
[Unit]
Description=PPP GPRS Connection
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pon gprs
ExecStop=/usr/bin/poff gprs
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Перезагружаем systemd
echo "Перезагружаем systemd..."
systemctl daemon-reload

# Включаем службы
echo "Включаем службы..."
systemctl enable audio_recording.service
systemctl enable gprs.service

# Запускаем службы
echo "Запускаем службы..."
systemctl start gprs.service
systemctl start audio_recording.service

echo "Установка завершена!"
