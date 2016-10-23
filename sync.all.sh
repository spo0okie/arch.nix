#!/bin/sh
# версия 1.1.0
# не используем единый lock файл, вместо него отдельный lock на каждый поток
# синхронизации, что позволяет запускать новые потоки, если продолжается какойто
# поток из предыдущего запуска
# версия 1.0.10
# теперь все потоки синхронизации запускаются параллельно, 
# потом запускается цикл ожидания завершения процессов 
# и по завершению каждого процесса он чистит за ним временную папку
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/spookie.diff.arc.lib.sh
. $PROGPATH/spookie.diff.arc.settings.sh
log_tpl=/var/log/spookie.sync

if [ -z "$syncdirs" ]; then
	lmsg "Nothing to sync"
	exit 1
fi

lmsg "Sync list: [$syncdirs]"
proclist=""
for archprefx in $syncdirs; do
	echo "-------------------"
	lmsg "Trying to sync $archprefx ..."
	archsufx=`echo "$archprefx"|tr '\/' '_'`
	varname="sync_age_$archsufx"
	if [ -n "${!varname}" ]; then
		lmsg "Synchronizing $archprefx ..."
		sync_age=${!varname}
		lmsg_ok "Sync age" $retention_simple_age
		tmppid=$pidfile.$archsufx.pid
		if checkPIDFile $tmppid; then
			syncDirPeriod_async $archprefx $arcdir $sync_age $remotesync/$archprefx $tmppid $log_tpl.$archsufx.log
			lmsg "Got new process pid: $lastpid ($syncdir)"
			proclist="$proclist $lastpid"
			eval sync_dir_$lastpid="$syncdir"
			eval pidfile_$lastpid="$tmppid"
		else
			lmsg "Skip $archprefx: already syncing in other process."
		fi
	else
		lmsg_err "$archprefx sync age" "UNSET"
	fi
done

while [ -n "$proclist" ]; do
	waitManyPids "$proclist"
	proclist=$pids_remain
	for pid in $pids_destroyed; do
		lmsg "PID # $pid completed."
		tmpDirVar="sync_dir_$pid"
		tmpPidVar="pidfile_$pid"
		#lmsg "$tmpDirVar=${!tmpDirVar}"
		deleteTempDir ${!tmpDirVar}
		unlockPIDFile ${!tmpPidVar}
	done
done

