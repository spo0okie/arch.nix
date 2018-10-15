#!/bin/sh
lib_arc_ini_version=0.1

#2018-07-28
#v0.1	initial

#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_ini_files

#загрузить секцию $1
arc_ini_load()
{
	do_arc=no
	do_clean=no
	do_sync=no

	#проверяем наличие секции global в файле
	ini_section_ck $PROGPATH/arch.priv.ini global
	#грузим общую
	ini_section_load $PROGPATH/arch.priv.ini global
	#проверяем наличие приватной секции в файле
	ini_section_ck $PROGPATH/arch.priv.ini $1
	#грузим приватную
	ini_section_load $PROGPATH/arch.priv.ini $1
}

#список всех приватных секций
arc_ini_section_list() {
	all_list=`ini_section_list $PROGPATH/arch.priv.ini`
	arr_sub "$all_list" global
}

#список секций для архивации
arc_ini_arc_list() {
	for section in `arc_ini_section_list`; do
		if $( bool $do_arc ); then
			echo $section
		fi
	done
}