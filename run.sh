#!/bin/bash

while true; do
    # Устанавливаем имя файла с временной меткой
    file_name="/home/piadmin/wav/recording_$(date +%Y%m%d%H%M%S).wav"

    # Записываем звук в файл в течение 1 минуты
    #sox -d -r 8000 -c 1 $file_name trim 0 1:00
    #sox -t alsa hw:3,0 -r 8000 -c 1 /home/piadmin/wav/recording_$(date +%Y%m%d%H%M%S).wav trim 0 1:00
    sox -t alsa hw:3,0 -r 8000 -c 1 $file_name trim 0 1:00

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
        ) | msmtp -a default -t stafme@ukr.net &  # Запуск в фоне
        
        # Ждем завершения фона (отправки письма)
        wait $!

        # Удаляем файл после отправки
        rm -f $file_name
    else
        echo "Error: Audio file was not recorded."
    fi
done

