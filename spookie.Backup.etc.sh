#!/bin/sh
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

if [ -z "$1" ]; then
	mode="monthly"
else
	mode=$1
fi

# Префикс архивов
archprefx=fserver_etc
#archprefx=Test
# где хранить архивы
arcstor=/store/protected/Archives/$archprefx

# откуда бэкапим
srcsrv=/var/log,/etc,/usr/local/etc,/usr/lib64/nagios/plugins,/var/lib/asterisk/sounds,/root

# исключить
srcxcl="-x!*.gz"

#политика хранения архивов - простая (храним все, что не старше чем ...)
retention_policies="simple"
#сколько дней хранить по простому алгоритму
retention_simple_age=90

. $PROGPATH/spookie.diff.arc.settings.sh


#cleandirsafter=$srcsrv\Test

. $PROGPATH/spookie.diff.arc.lib.sh


jobINIT			#подключаемся к хранилищу
jobBACKUP "$mode"	#бэкапим
jobCLEAN		#убираем старые архивы
jobDONE			#прибираемся и отключаемся


