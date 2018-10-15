#!/bin/bash
#
# Проверка всех архивных секций из ini файла

# v1.0 - initial

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=$PROGPATH/arch.priv.ini

#поделючаем библиотеки
#подключаем все, т.к. надо проверить в т.ч. что все они присутствуют

. $PROGPATH/lib/lib_core.sh
lib_require lib_arc
lib_require lib_arc_ini
lib_require lib_arc_job
lib_require lib_arc_retention

#проверяем наличие секции global в файле
ini_section_ck $INI global

sections=`arc_ini_section_list`

for section in $sections; do
	ini_section_load $INI global
	ini_section_load $INI $section

	if $( bool $do_clean ); then
		arc_retention_var_ck
		arc_job_INIT__			#подключаемся к хранилищу
		arc_job_CLEAN $1		#убираем старые архивы
		arc_job_DONE			#прибираемся и отключаемся
		cd $PROGPATH
	fi

done

lmsg "Clean done."
