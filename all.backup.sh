#!/bin/bash
#
# Проверка всех архивных секций из ini файла

# v1.0 - initial

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=/usr/local/etc/arch/arch.priv.ini
all_logfile=/var/log/backups/all.backup.log
logfile=$all_logfile
#поделючаем библиотеки
#подключаем все, т.к. надо проверить в т.ч. что все они присутствуют

. $PROGPATH/lib/lib_core.sh
lib_require lib_arc
lib_require lib_arc_ini
lib_require lib_arc_job
lib_require lib_arc_retention

lmsg "ALL-Backup script run"

#проверяем наличие секции global в файле
ini_section_ck $INI global

sections=`arc_ini_section_list`
lmsg "Sections to proceed: $sections"

for section in $sections; do
	lmsg "Running $section."
	#FIXME: какойто баг с тем что не затирается значение от предыдущей секции при определении в новой
	srcxcl=""
	ini_section_load $INI global
	ini_section_load $INI $section
	if $( bool $do_arc ); then
		lmsg "Starting JOB (output will be redirected to section log file)"
		arc_job_INIT			#подключаемся к хранилищу
		arc_job_BACKUP $mode	#убираем старые архивы
		if $( bool $do_clean ); then
			arc_job_CLEAN clean		#убираем старые архивы
		fi
		arc_job_DONE			#прибираемся и отключаемся
		cd $PROGPATH			#возвращаемся в свою папку
		logfile=$all_logfile	#возвращаем вывод в наш лог
	else
		lmsg "Skipping JOB"
	fi
	lmsg "Complete ${section}."
done

lmsg "All done."
