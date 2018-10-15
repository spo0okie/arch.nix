#!/bin/bash
#
# Архивация одной папки
# - Проверка переменных
# - Подготовка папок
# - Архивация
# - Проверка списка архивов
# - Чистка папки с архивами

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=$PROGPATH/arch.priv.ini

if [ -z "$1" ]; then
	echo "usage: $0 <section from $INI>"
	exit 10
fi

#поделючаем библиотеки
. $PROGPATH/lib/lib_core.sh
lib_require lib_arc_ini
lib_require lib_arc_job

#проверяем наличие секции global в файле
ini_section_ck $INI global
ini_section_load $INI global

#проверяем наличие секции в файле
ini_section_ck $INI $1
ini_section_load $INI $1

if [ -n "$2" ]; then
	mode=$2
fi
logfile=/usr/local/etc/arch/log

arc_job_INIT			#подключаемся к хранилищу
arc_job_BACKUP $mode	#бэкапим
arc_job_CLEAN			#убираем старые архивы
arc_job_DONE			#прибираемся и отключаемся


