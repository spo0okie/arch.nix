#!/bin/bash
#
# мониторинг одной папки
# config - Проверка конфигурации
# arclibsize	- объем всей библиотеки архивов
# arcfullsize	- объем последнего фулл
# arcdiffsize	- объем последнего дифф
# syncfirstage	- возраст первого файла в реплике архивов
# synclastage	- возраст последнего файла в реплике архивов
# synclibsize	- объем всей реплики архивов

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=$PROGPATH/arch.priv.ini

if [ -z "$1" ]; then
	echo "usage: $0 <parameter> <section from $INI>"
	echo "<parameter>:"
	echo "	config - Проверка конфигурации"
	echo "	arcfirstage	- возраст первого файла архивов"
	echo "	arclastage	- возраст последнего файла архивов"
	echo "	arcfullage	- возраст последнего ФУЛЛ архива"
	echo "	arclibsize	- объем всей библиотеки архивов"
	echo "	arcfullsize	- объем последнего фулл"
	echo "	arcdiffsize	- объем последнего дифф"
	echo "	syncfirstage- возраст первого файла в реплике архивов"
	echo "	synclastage	- возраст последнего файла в реплике архивов"
	echo "	synclibsize	- объем всей реплики архивов"
	exit 10
fi

#глушим лог
LOG_silent=1

#глушим вывод в консоль (если только для отладки не указано обратное)
if [ "$3" != "verbose" ]; then
	CON_silent=1
fi

#подключаем библиотеки
. $PROGPATH/lib/lib_core.sh
lib_require lib_arc_ini
lib_require lib_arc_files
lib_require lib_arc_job

#грузим общие настройки
ini_section_load $INI global
#грузим нашу секцию
ini_section_load $INI $2

arc_job_INIT	#подключаемся к хранилищу

#запрашиваем наш параметр

case $1 in
	arcfirstage)
		#ищем первый архив
		firstarc=`findFirstArc $arcstor`
		#возвращаем возраст в часах
		if [ -n "$firstarc" ]; then
			getFileHoursAge $firstarc
		else
			echo 65535
		fi
	;;
	arclastage)
		lastarc=`findLastArc $arcstor`
		if [ -n "$lastarc" ]; then
			getFileHoursAge $lastarc
		else
			echo 65536
		fi
	;;
	arcfullage)
		lastarc=`findLastFullArc $arcstor`
		if [ -n "$lastarc" ]; then
			getFileHoursAge $lastarc
		else
			echo 65536
		fi
	;;
	synclastage)
		lastsync=`findLastArc $remotesync/$archprefx`
		if [ -n "$lastsync" ]; then
			getFileHoursAge $lastsync
		else
			echo 65536
		fi
	;;
	syncfirstage)
		lastsync=`findFirstArc $remotesync/$archprefx`
		if [ -n "$lastsync" ]; then
			getFileHoursAge $lastsync
		else
			echo 65536
		fi
	;;

esac

arc_job_DONE	#отключаемся от хранилища
