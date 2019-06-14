#!/bin/bash
#
# Проверка всех архивных секций из ini файла

# v1.0 - initial

log_tpl=/var/log/backups/sync

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
INI=$PROGPATH/arch.priv.ini
logfile=/var/log/backups/all.sync.log

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
		arc_sync_var_ck

		#в суффиксе подменяем слэши
		archsufx=`echo "$archprefx"|tr '\/' '_'`

		#назначаем файл с PID процесса синхронзации
		tmppid=$pid_dir/spoo_sync.$archsufx.pid

		#если файл свободен
		if checkPIDFile $tmppid; then
			#запускаем синхронизацию со всеми параметрами
			arc_sync_DirPeriod_async $archprefx $arcdir $sync_age $remotesync/$archprefx $tmppid $log_tpl.$archsufx.log
			lmsg "Got new process pid: $lastpid ($syncdir)"

			#запоминаем PID этой синхронизации
			proclist="$proclist $lastpid"

			#запоминаем файл и папку синхронизации этого процесса
			eval sync_dir_$lastpid="$syncdir"
			eval pidfile_$lastpid="$tmppid"
		else
			lmsg "Skip $archprefx: already syncing in other process."
		fi
	fi
done

#тут мы запустили все процессы синхронизации, какие хотели и они висят в фоне.
#нам нужно отлавливать завершившиеся пиды и прибираться за ними

#пока есть еще фоновые процессы
while [ -n "$proclist" ]; do

	#ждем пока ктонибудь завершится
	waitManyPids "$proclist"

	#корректируем список фоновых процессов
	proclist=$pids_remain

	#обрабатываем завершившиеся процессы
	for pid in $pids_destroyed; do
		lmsg "PID # $pid completed."
		tmpDirVar="sync_dir_$pid"
		tmpPidVar="pidfile_$pid"
		#lmsg "$tmpDirVar=${!tmpDirVar}"
		deleteTempDir ${!tmpDirVar}
		unlockPIDFile ${!tmpPidVar}
	done
done




lmsg "Sync done."

