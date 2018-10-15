#!/bin/sh
lib_arc_sync_version="2.0.0 rc"

#hist:
#	2018-07-28
#2.0.0 * Библиотека разделена на меньшие для простоты управления

#TODO:
#	при чистке если остается точек меньше чем retstopon, то нужно не отменять чистку вообще, а корректировать список
#cleanafter()
#buildSimpleRetentionList() - удалять инконсистентные файлы (дифф без фула)
#передавать день для полных копий, чтобы распределить равномерно нагрузку по дням а не в один день все


#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_con
lib_require lib_arc_retention

arc_sync_var_ck()
{
	lmsg "Checking archives synchronization vars set ..."
	var_ck arcdir
	var_ck arcstor
	var_ck archprefx
	var_ck sync_age
	var_ck remotesync
}

syncDir()
{
	p="syncDir():"
	lmsg "$p Syncing [$1] dir"
	checkvar_ret "$1" "$p Archive subdir" && \
	checkvar_ret "$2" "$p Archives dir" && \
	checkvar_ret "$3" "$p Remote command" && \
	checkvar_ret "$4" "$p PID file" \
	|| return 10

        lmsg__ "$p forking rsync ... " "99999"
        rsync -a -P -e "ssh -i /root/.ssh/ssh-key" $2/$1 $3 & lastpid=$! >> $4
        echo $lastpid >> $4
        lmsg__ok "$p forking rsync ... " $lastpid
        lmsg "$p waiting rsync to complete ... "
        while ps -p $lastpid > /dev/null; do
		sleep 2
	done
	lmsg "$p Syncing [$1] done."

}

arc_sync_prepFile()		#$1 - file $2 - temp dir
{
	msg11="prepSyncFile() Queueing sync of $1 ..."
	lmsg__ "$msg11" "No temp dir passed"
	if [ -z "$2" ]; then
		lmsg__err "$msg11" "No temp dir passed"
		return 10
	fi
	if $( cp -l $1 $2 ); then
		lmsg__ok "$msg11"
	else
		lmsg__err "$msg11"
	fi
}

arc_sync_prepFilesList()	#$1 - where to place links $2 - filelist
{
	if [ -z "$2" ]; then
		lmsg "Sync list empty. Nothing to do"
		return 10
	fi
	for ff in $2; do
		arc_sync_prepFile $ff $1
	done
}

arc_sync_DirPeriod_async()
{
	p="syncDirPeriod_async():"
	lmsg "$p Syncing [$1] dir"
	checkvar_ret "$1" "$p Archive subdir" && \
	checkvar_ret "$2" "$p Archives dir" && \
	checkvar_ret "$3" "$p Sync age" && \
	checkvar_ret "$4" "$p Remote command" && \
	checkvar_ret "$5" "$p PID file" \
	|| return 10

	lmsg "$p Preparing temp dir ... "
	arcstor=$2$1
	syncdir="$arcstor/.sync"
	dircheck $syncdir "clean"
	buildSimpleRetentionList $3
	arc_sync_prepFilesList $syncdir "$simpleRetentionList"

	if [ -n "$6" ]; then
		#добавляем редирект вывода в отдельный лог
		#--partial позволяет докачку
		lmsg__ "$p forking rsync (logging into $6) ... " "99999"
		date >> $6
		rsync -a -v --partial -e "ssh -i /root/.ssh/ssh-key" $syncdir/ $4 >> $6 & lastpid=$! >> $5
		lmsg__ok "$p forking rsync (logging into $6) ... " $lastpid
	else
		#вывод в консоль -Р означает докачку+вывод прогресса в консоль
		lmsg__ "$p forking rsync ... " "99999"
		rsync -a -P -e "ssh -i /root/.ssh/ssh-key" $syncdir/ $4 & lastpid=$! >> $5
		lmsg__ok "$p forking rsync ... " $lastpid
	fi
	echo $lastpid >> $5
	return $lastpid

}

arc_sync_DirPeriod()
{
	p="syncDirPeriod():"
	lmsg "$p Syncing [$1] dir"
	checkvar_ret "$1" "$p Archive subdir" && \
	checkvar_ret "$2" "$p Archives dir" && \
	checkvar_ret "$3" "$p Sync age" && \
	checkvar_ret "$4" "$p Remote command" && \
	checkvar_ret "$5" "$p PID file" \
	|| return 10

	arc_sync_DirPeriod_async $*

	waitPid $lastpid 
	dir_clean $syncdir

	lmsg "$p Syncing [$1] done."

}


