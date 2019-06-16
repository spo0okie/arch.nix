#!/bin/bash
#
# Проверка всех архивных секций из ini файла

# v1.0 - initial

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=$PROGPATH/arch.priv.ini
logfile=/dev/null

#поделючаем библиотеки
#подключаем все, т.к. надо проверить в т.ч. что все они присутствуют

. $PROGPATH/lib/lib_core.sh
lib_require lib_arc
lib_require lib_arc_files
lib_require lib_arc_ini
lib_require lib_arc_job
lib_require lib_arc_retention
lib_require lib_arc_sync
lib_require lib_ini_files
lib_require lib_process
lib_require lib_share

#проверяем наличие секции global в файле
ini_section_ck $INI global

sections=`arc_ini_section_list`

for section in $sections; do
	lmsg "CHECKING $section"
	ini_section_load $INI global
	ini_section_load $INI $section

	var_ck do_monitor
	var_ck description
	if $( bool $do_arc ); then
		lmsg_ok " - ARC" "enabled"
		arc_var_ck
	else
		lmsg_norm " - ARC" "disabled"
	fi

	if $( bool $do_clean ); then
		lmsg_ok " - CLEAN" "enabled"
		arc_retention_var_ck
	else
		lmsg_norm " - CLEAN" "disabled"
	fi

	if $( bool $do_sync ); then
		lmsg_ok " - SYNC" "enabled"
		arc_sync_var_ck
	else
		lmsg_norm " - SYNC" "disabled"
	fi
done

lmsg "Check done. All green"

