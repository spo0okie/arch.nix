#!/bin/sh
lib_arc_job_version="2.0.0"


#hist:
#	2018-07-28
#2.0.0 * Отделено от diff_arc


#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_con
lib_require lib_arc
lib_require lib_arc_sync
lib_require lib_arc_retention
lib_require lib_share



arc_job_INIT__()	#подготавливается к работе общая
{

	shareuse

	dircheck $arcstor
}

arc_job_INIT()	#подготавливается к работе
{
	# с каким префиксом делать архивы
	arc_var_ck
	arc_retention_var_ck

	logfile=/var/log/spookie.backup.$archprefx.log
	lmsg "Log file $logfile attached ------------------------------------------------"
	lmsg "Script started:	$archprefx differential backup //library version $libversion"

	if [ -f $arch ]; then
		lmsg_ok "Arch binary $arch"
	else 
		lmsg_err "Arch binary $arch" "not found!" && exit 10
	fi

	arc_job_INIT__
}

arc_job_BACKUP()
{
	findlastfull

	arc_setdiffmode $1

	arc_formname

	lmsg "Archiving..."
	cd /

	#в списке директорий для архивации меняем заяпятые на пробелы
	srcsrv=`echo $srcsrv|sed s/,/\ /g`
	srcarg=""
	#делаем пути относительными чтобы сохранить дерево папок в архиве
	for dir in $srcsrv; {
		abs=${dir:0:1}
		rel=${dir:1}
		if [ "$abs" == "/" ]; then	#make paths relative to store dir tree in .7z (abs paths not stored)
			dir=$rel
		fi
		srcarg="$srcarg $dir/*"
	}
	lmsg_norm "Archiving paths" "$srcarg"
	
	if [ "$diffmode" != "true" ]; then
		arc_Full "$srcarg"
	else
		arc_Diff "$srcarg"
	fi
}

arc_job_CLEAN() #чистка архивов
{
	for pol in $retention_policies; {
		case $pol in
			[Ss][Ii][Mm][Pp][Ll][Ee])
				buildSimpleRetentionList $retention_simple_age
			;;
		esac
	}

	if [ -n "$simpleRetentionList" ]; then
		cleanWithRetentionList "$simpleRetentionList" "$1"
	else
		lmsg "Retention list is empty. Skip cleaning."
	fi
}

arc_job_DONE()	#завершает работу
{
	arc_cleanafter
	
	sharerelease
}

