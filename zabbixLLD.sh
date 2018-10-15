#!/bin/bash
#
# Вывод списка 
#{"data":[{
#        "{#CHECKWORKS}":"/var/log/mail.azimut_recv.works",
#        "{#CHECKERR}":"/var/log/mail.azimut_recv.err",
#        "{#CHECKDESCR}":"получения вх. почты на @azimut.ru"
#},{
#        "{#CHECKWORKS}":"/var/log/mail.azimut_send.works",
#        "{#CHECKERR}":"/var/log/mail.azimut_send.err",
#        "{#CHECKDESCR}":"отправки исх. почты с @azimut.ru"
#}]}

# v1.0 - initial

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=/usr/local/etc/arch/arch.priv.ini

LOG_silent=1
if [ "$2" != "verbose" ]; then
	CON_silent=1
fi

#подrлючаем библиотеки
. $PROGPATH/lib/lib_core.sh
lib_require lib_arc
lib_require lib_arc_ini
lib_require lib_arc_job
lib_require lib_arc_retention

#проверяем наличие секции global в файле
ini_section_ck $INI global

sections=`arc_ini_section_list`

exsts=0
echo '{"data":['

for section in $sections; do
	ini_section_load $INI global
	ini_section_load $INI $section
	if $( bool $do_monitor ); then
		if [ "$exists" == "1" ]; then
			echo -n ","
		else
			echo -n "	"
		fi
		echo "{"
		echo "		\"{#SPOOARCINI}\":\"$section\","
		echo "		\"{#SPOOARCDESCR}\":\"$description\""
		echo -n "	}"
		exists=1
	fi
done
echo
echo "]}"

