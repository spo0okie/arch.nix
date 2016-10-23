#!/bin/sh
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

# откуда бэкапим

. $PROGPATH/spookie.diff.arc.settings.sh
. $PROGPATH/spookie.diff.arc.lib.sh

#политика хранения архивов - простая (храним все, что не старше чем ...)
retention_policies="simple"

if [ -z "$cleandirs" ]; then
	lmsg "Nothing to clean"
	exit 1
fi

lmsg "Clean list: [$cleandirs]"

for archprefx in $cleandirs; do
	lmsg "Trying to clean $archprefx ..."
	varname=`echo "retention__$archprefx"|tr '\/' '_'`
	varname2=`echo "retstopon__$archprefx"|tr '\/' '_'`
	lmsg_norm "Variable for retention age: " $varname
	if [ -n "${!varname}" ]; then
		lmsg "Cleaning $archprefx ..."
		arcstor=$arcdir$archprefx
		retention_simple_age=${!varname}
		if [ -n "${!varname2}" ]; then
			#если предопределена персональная переменная для этого архива, то используем ее
			retstopon=${!varname2}
		else
			#иначе обнуляем переменную, и подставится глобальное значение
			retstopon=""
		fi
		lmsg_ok "Reteniton age" $retention_simple_age
		lmsg_norm "Archive storage" $arcstor
		jobINIT__			#подключаемся к хранилищу
		jobCLEAN $1			#убираем старые архивы
		jobDONE				#прибираемся и отключаемся
	else
		lmsg_err "Reteniton age" "not set"
	fi
done


