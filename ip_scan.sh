#!/bin/bash

#Проверка на root права
if [[ $EUID -ne 0 ]]; then
    echo "Скрипт должен быть запущен с правами root."
    exit 1
fi

trap 'echo "Ping exit (Ctrl-C)"; exit 1' 2

#Аргументы
PREFIX="$1"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"

#Регулярные выражения
RE_PREFIX='^([0-9]{1,3})\.([0-9]{1,3})$'
RE_OCTET='^([0-9]{1,3})$'

#Функция проверки октета
check_octet() {
    local value=$1
    local name=$2
    
    if [[ ! "$value" =~ $RE_OCTET || $value -lt 0 || $value -gt 255 ]]; then
        echo "$name должен быть от 0 до 255."
        exit 1
    fi
}

#Проверка на обязательные аргументы
if [[ -z "$PREFIX" || -z "$INTERFACE" ]]; then
    echo "Команда введена некорректно. Используйте: sudo $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
    echo "Пример: sudo $0 192.168 eth0 [10] [5]"
    exit 1
fi

#Проверка формата PREFIX
if [[ ! "$PREFIX" =~ $RE_PREFIX ]]; then
    echo "Некорректный префикс. Используйте формат ХХХ.ХХХ (например 192.168)"
    exit 1
fi

#Проверка диапазонов в PREFIX
for part in ${PREFIX//./ }; do
    check_octet "$part" "Каждый октет префикса"
done

#Проверка SUBNET
if [[ -n "$SUBNET" ]]; then
    check_octet "$SUBNET" "SUBNET"
fi

#Проверка HOST
if [[ -n "$HOST" ]]; then
    check_octet "$HOST" "HOST"
fi

#Функция для сканирования
scan_ip() {
    local ip=$1
    echo "Проверка IP: $ip"
    arping -c 3 -i "$INTERFACE" "$ip" 2>/dev/null
}

#Основная логика
if [[ -n "$HOST" && -n "$SUBNET" ]]; then
    #Сканирование одного адреса (заданы все 4 аргумента)    
    scan_ip "${PREFIX}.${SUBNET}.${HOST}"
elif [[ -n "$SUBNET" ]]; then
    #Сканируются хосты подсети (задан аргумент SUBNET)
    for h in {1..255}; do
        scan_ip "${PREFIX}.${SUBNET}.${h}"
    done
else
    #Сканируется вся подсеть (аргументы SUBNET и HOST не заданы)
    for s in {1..255}; do
        for h in {1..255}; do
            scan_ip "${PREFIX}.${s}.${h}"
        done
    done
fi
