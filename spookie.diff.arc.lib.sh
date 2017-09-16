#!/bin/sh
libversion="1.1.2 rc"

tmp=/tmp/spoo.arc.multipart.tmp

#hist:
#	2017-09-17
#1.2.0 * список для чистки теперь составляется с учетом минимального количества файлов
#	2016-10-23
#1.1.2 + добавлен параметр retstopon_global - минимальное количество архивов которое нужно оставить при чистке старых архивов
#	т.е. если при построении списка архивов для чистки, оказывается что остается меньше чем разрешено, то чистка отменяется
#      + добалены параметры retstopon__<archive> то же что и глобальный, но устанавливается персонально для каждого (иначе действует глобал)
#	2016-10-13
#1.1.1 + добавлен параметр fulllifetime - максимальный возраст жизни полного архива в днях, после которого создастся новый (45 по умолч)
#	2016-08-25
#	* Причесан вывод в консоль, устранены небольшие косяки.
#	2016-08-23
#1.1.0 + добавлены функции для проверки pid файлов. процесс синхронизации всех каталогов более не использует единый pid файл
#	все потоки синхронизации имеют свой pid файл и проверка ведется именно по нему
#
#	2016-08-22
#1.0.10+ асинхронный режим синхронизации каталогов для параллельной синхронизации всех каталогов 
#	(на случай затыка всей синхронизации если в одном из каталогов появился большой файл, чтобы синхронизировались те, где такого файла нет)
#	2016-06-05
#1.0.9 + импортированы из внешних скриптов функции для вывода статистики в нагиос
#	   + добавлена переменная $CON_silent, блокирующая весь вывод в консоль, если установлена в true
#	2016-05-31
#1.0.8 + импортированы из внешних скриптов функции для синхронизации не всей подпапки а архивов за последние N дней
#	теперь на разных концах дврусторонней синхронизации может храниться разный период архивации
#	2016-05-21
#1.0.7 + Добавлены процедуры для синхронизации через rsync
#      * Скорректированы функции работы с консолью, добавлены функции раздельного вывода строки и дописи статуса
#      ! Некоторые багфиксы
#1.0.6 ! В процедуру монтирования шары добавлено бесконечное ожидание успешного монтирования
#	 с паузами 30 мин между попытками

#TODO:
#	при чистке если остается точек меньше чем retstopon, то нужно не отменять чистку вообще, а корректировать список
#cleanafter()
#buildSimpleRetentionList() - удалять инконсистентные файлы (дифф без фула)
#передавать день для полных копий, чтобы распределить равномерно нагрузку по дням а не в один день все


if [ -z "$fulllifetime" ]; then
	fulllifetime=45
fi

if [ -z "$retstopon_global" ]; then
	retstopon_global=10
fi

########################################################################
###   F U N C S  #######################################################
########################################################################


### CONSOLE STUFF ######################################################
crlf='
'
CON_RED=$(tput setaf 1)
CON_GREEN=$(tput setaf 2)
CON_NORMAL=$(tput sgr0)
CON_WIDTH=$(tput cols)
CON_RMARGIN=2
CON_TTY=`tty`
if [ "${CON_TTY:0:4}" = "/dev" ]; then
	CON_TTY="tty"
else
	CON_TTY="no"
fi

con_stat()	#report ok ($msg $status $colorcode
{
	if [ "$CON_silent" = "1" ]; then 
		 return 0 
	fi
	if [ "$CON_TTY" = "no" ]; then 
		con_msg "$1 - $2" && return 0 
	fi

	if [ "$(( $CON_WIDTH - ${#2} - 2 - $CON_RMARGIN ))" -lt "${#1}" ]; then
		msg="${1:0:$(( $CON_WIDTH - ${#2} - $CON_RMARGIN - 5 ))}..."	#trunkate long messages
	else
		msg=$1
	fi

	printf "%s%*s%s\n" "$msg" $(( $CON_WIDTH - ${#msg} - ${#2} - 2 - $CON_RMARGIN )) " " "[$3$2$CON_NORMAL]"

}

con_stat_stat()	#report ok ($msg $status $colorcode
{
	if [ "$CON_silent" = "1" ]; then 
		 return 0 
	fi

	if [ "$CON_TTY" = "no" ]; then 
		con_msg " - $2" && return 0 
	fi

	if [ "$(( $CON_WIDTH - ${#2} - 2 - $CON_RMARGIN ))" -lt "${#1}" ]; then
		msg="${1:0:$(( $CON_WIDTH - ${#2} - $CON_RMARGIN - 5 ))}..."	#trunkate long messages
	else
		msg=$1
	fi

	printf "%*s%s\n" $(( $CON_WIDTH - ${#msg} - ${#2} - 2 - $CON_RMARGIN )) " " "[$3$2$CON_NORMAL]"

}

con_stat_msg()	#report ok ($msg $status $colorcode
{
	#выведет сообщение и подготовит к выводу статуса. 
	#уже в этой функции надо передать самый длинный возможный статус для обрезки сообщения
	if [ "$CON_silent" = "1" ]; then 
		 return 0 
	fi

	if [ "$CON_TTY" = "no" ]; then 
		printf "%s" "$1" && return 0 
	fi

	if [ "$(( $CON_WIDTH - ${#2} - 2 - $CON_RMARGIN ))" -lt "${#1}" ]; then
		msg="${1:0:$(( $CON_WIDTH - ${#2} - $CON_RMARGIN - 5 ))}..."	#trunkate long messages
	else
		msg=$1
	fi
	printf "%s" "$msg"
}

con_msg()	#msg to console
{
	if [ "$CON_silent" = "1" ]; then 
		 return 0 
	fi
	echo "$1"
}
	
log_msg()	#msg to log
{
	if [ -z "$logfile" ]; then
		logfile=/dev/null
	fi
	echo "$1" >>$logfile
}
	
lmsg() 	#log command
{	
	date=`date +"%F %T"`
	con_msg "$date $1" && log_msg "$date $1"
}


lmsg_ok() 	#log command
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='OK'
	else
		status="$2"
	fi
	con_stat "$date $1" "$status" $CON_GREEN && log_msg "$date $1 - $status"
}

lmsg_norm() 	#log command
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='NORM'
	else
		status="$2"
	fi
	con_stat "$date $1" "$status" $CON_NORMAL && log_msg "$date $1 - $status "
}

lmsg_err() 	#log command
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='ERR'
	else
		status="$2"
	fi
	con_stat "$date $1" "$status"  $CON_RED && log_msg "$date $1 - $status "
}


lmsg__() 	#log command and leave space for status $2
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='NORM'
	else
		status="$2"
	fi
	con_stat_msg "$date $1" "$status"  && log_msg "$date $1 ... "
}


lmsg__ok() 	#log command status after lmsg__
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='OK'
	else
		status="$2"
	fi
	con_stat_stat "$date $1" "$status" $CON_GREEN && log_msg "$date $1 - $status"
}

lmsg__err() 	#log command
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='ERR'
	else
		status="$2"
	fi
	con_stat_stat "$date $1" "$status"  $CON_RED && log_msg "$date $1 - $status "
}

lmsg__norm() 	#log command
{	
	date=`date +"%F %T"`
	if [ -z "$2" ]; then
		status='NORM'
	else
		status="$2"
	fi
	con_stat_stat "$date $1" "$status" $CON_NORMAL && log_msg "$date $1 - $status "
}


### VAR STUFF ##########################################################

checkvar_ret()	#check if var is set(return code)
{	
	if [ -z "$1" ]; then
		lmsg_err "$2" "UNSET" && return 1
	else 
		lmsg_ok "$2" "SET" && return 0
	fi
}

checkvar()	#check if var is set
{	
	if [ -z "$1" ]; then
		lmsg_err "$2" "UNSET" && exit 10
	else 
		lmsg_ok "$2" "SET"
	fi
}

shareuse() #mount share
{
	if [ -z "$arcshare" ]; then
		lmsg_norm "shareuse(): no share to mount" "skip"
		return 0
	fi
	mountpoint=$mountroot/$archprefx
	dircheck $mountpoint
	p="shareuse(): mounting $arcshare to $mountpoint"
	while true ; do
		if $( mount -t cifs -o username=$arcuser,password=$arcsecret $arcshare $mountpoint ); then
			lmsg_ok "$p"
			arcstor=$mountpoint/$arcstor
			return 0
		else
			lmsg_err "$p"
			lmsg "retry in 30 mins (waiting) ... "
			sleep 30
		fi
	done
}

sharerelease() #unmount share
{
	if [ -z "$arcshare" ]; then
		lmsg_norm "sharerelease(): no share to unmount" "skip"
		return 0
	fi
	p="sharerelease(): unmounting $arcshare from $mountpoint"
	if $( umount $mountpoint ); then
		lmsg_ok "$p"
	else
		lmsg_err "$p"
	fi
	
}


getFileUnixTime() #returns age in hours of $1; usage hours=$(getFileHoursAge $1)
{
	stat -c %Y $1 2>>/dev/null
}

getFileAge() #returns age in hours of $1; usage hours=$(getFileHoursAge $1)
{
	echo $(( `date +%s` - $(getFileUnixTime $1) ))
}

getFileHoursAge() #returns age in hours of $1; usage hours=$(getFileHoursAge $1)
{
	echo $(( $(getFileAge $1) / 3600 ))
}

getFileDaysAge() #returns age in hours of $1; usage hours=$(getFileHoursAge $1)
{
	echo $(( $(getFileAge $1) / 86400 ))
}

findLastArc() #finds last archve file $1 - arcstor directory
{
	ls -1 -t $1/*.{7z,zip} 2>/dev/null| head -n 1
}

findLastFullArc() #finds last archve file $1 - arcstor directory
{
	ls -1 $1/*.{7z,zip} 2>/dev/null | grep "\\-full\\." | grep -v "\\-diff\\-" | tail -n1
}

findlastfull() #find last full arc file in dir
{	
	lastfull=$(findLastFullArc $arcstor)
	if [ -n "$lastfull" ]; then
		lastfull_base=`basename $lastfull`
		lmsg_norm "findlastfull(): Last full archive is" "$lastfull_base /$lastfull_age_days days old"
		lastfull_age_days=$(getFileDaysAge $lastfull)
		lmsg_norm "findlastfull(): Full age" $lastfull_age_days
	else 
		lastfull_age_days=0
		lmsg "findlastfull(): No full archives found in $arcstor $lastfull (diff mode unavailable)"
	fi
}

setdiffmode()	#set diff or full mode for current job
{	
	p="setdiffmode($1):"
	if [ -n "$lastfull" ]; then
		#make diff if today is not fifth day of month and Full not older than 31 day
		case "$1" in
			[Mm][Oo][Nn][Tt][Hh][Ll][Yy])
				day=`date +%m`
				if [ "$day" != "05" ]; then
					#31day: 31*24*60*60=2678400
					if [ "$lastfull_age_days" -lt "$fulllifetime" ]; then
						diffmode=true
						lmsg_norm "$p Monthly shedule" "Diff mode"
					else
						lmsg_err "$p Monthly shedule (full is older than 31day!)" "Full mode"
					fi
				else
					lmsg_norm "$p Monthly shedule" "Full mode"
				fi
			;;
			[Dd][Ii][Ff][Ff])
				diffmode=true
				lmsg_ok "$p Diff mode forced" "Diff mode"
			;;
			*)
				lmsg_ok "$p Full mode forced" "Full mode"
			;;
		esac
	else
		diffmode=false
		lmsg_norm "$p No full archive exist to make diff" "Full mode"
	fi
}

formname()	#form name for current job file
{	
	#lmsg "Forming archive date prefix"
	dateprefx=`date +%Y%m%d-%H%M%S`
	lmsg_norm "formname(): Prefix set" "$archprefx-$dateprefx"
}

dircheck()	#creates dir (and cleans it if $2==clean)
{	
	if ! [ -d "$1" ]; then
		lmsg_err "dircheck(): Checking folder $1..." "MISS"
		mkdir -p $1
		if ! [ -d "$1" ]; then
			lmsg_err "dircheck(): Creating $1 ..."
			exit 1
		else
			lmsg_ok "dircheck(): Creating $1 ..."
		fi
	else
		lmsg_ok "dircheck(): Checking folder $1..."
	fi
	if [ "$2" == "clean" ]; then
		if [ -n "$1" ]; then	#do not delete in /*
			rm -f $1/* >>$logfile
		fi
		lmsg_ok "dircheck(): Cleaning folder $1 ..." "DONE"
	fi
}

fileIsDiff() #says diff if file is diff from other
{
	if [ -n "$1" ]; then
		testdiff=`echo $1|grep diff`
		if [ "$testdiff" = "$1" ]; then
			echo "diff"
		else
			echo  "nodiff"
		fi
	else
		echo  "error: no name given"
	fi
}

fullFromDiff() #says diff's full arc filename
{
	echo $1|sed -r 's/.*-diff-//'
}

cleanafter()
{
	if [ "$cleandirsafter" == "" ]; then
		lmsg "cleanafter(): Dirs list for cleaning is empty. Nothing to clean after archiving..."
	else
		echo "cleanafter(): FOR %%i IN (%cleandirsafter%) DO (CALL :dircheck %%i clean)"
	fi
}


arcDiff()	#arc in diff mode
{
	
	p="arcDiff($1): $arch u $lastfull$arcopts -u- -up3q3r2x2y2z0w2\\!$arcstor/$archprefx-$dateprefx-diff-$lastfull_base $1"
	if $( $arch u $lastfull$arcopts -u- -up3q3r2x2y2z0w2\!$arcstor/$archprefx-$dateprefx-diff-$lastfull_base $1 >>$logfile ); then
		lmsg_ok "$p"
	else
		lmsg_err "$p"
	fi
}

arcFull()	#arc in full mode
{
	p="arcFull($1): $arch a $arcstor/$archprefx-$dateprefx-full.7z $arcopts $1 ..."
	if $( $arch a $arcstor/$archprefx-$dateprefx-full.7z $arcopts $1 >>$logfile ); then
		lmsg_ok "$p"
	else
		lmsg_err "$p"
	fi
}

inlist() #проверяет что $1 есть в списке $2
{
	if [ -z "$1" ]; then
		echo "false"
	elif [ -z "$2" ]; then
		echo "false"
	else
		testlist=`echo "$2"|grep $1`
		if [ -z "$testlist" ]; then 
			echo "false"
		elif [ "$testlist" == "$1" ]; then
			echo "true"
		else
			echo "false"
		fi
	fi
}

buildSimpleRetentionList()	#делаем список файлов для сохранения по правилу "все не старше чем... $1"
{
	p="buildSimpleRetentionList($1): "
	if [ -z "$1" ]; then
		lmsg "HALT: $p no retention age given!"
		return 13
	fi
	currenttime=`date +%s`
	retentionage=$(( $1 * 86400 ))
	retentiondate=$(( $currenttime - $retentionage ))
	retentiondatereadable=`date -d@$retentiondate +%Y-%m-%d`
	#сторим список файлов к проверке
	testlist=`ls -1 -t -r $arcstor/*.{7z,zip} 2>/dev/null`
	testlist_cnt=`echo "$testlist" |wc -l`
	testlist_orig=$testlist_cnt
	outlist=""
	if [ -z "$retstopon" ]; then
		retstopon=$retstopon_global
	fi
	lmsg "$p filtering out files older than $retentiondatereadable ($retstopon limit)... "
	for testf in $testlist; {
		#пропускаем файлы если длинна списка укоротилась до предельной
		if [ "$testlist_cnt" -le "$retstopon" ]; then
			outlist=$( printf "$outlist\n$testf" )
			#он дельта или полный?
			if [ $( fileIsDiff $testf ) == "diff" ]; then
				#дельта - ищем фулл
				testff=$( fullFromDiff $testf )
				outlist=$( printf "$outlist\n$arcstor/$testff" )
			fi
			continue
		fi
		#время модификации
		testftimestamp=`stat -c %Y $testf`
		if ! [ "$testftimestamp" -lt "$retentiondate" ]; then
			#не старый
			outlist=$( printf "$outlist\n$testf" )
			#он дельта или полный?
			if [ $( fileIsDiff $testf ) == "diff" ]; then
				#дельта - ищем фулл
				testff=$( fullFromDiff $testf )
				outlist=$( printf "$outlist\n$arcstor/$testff" )
			fi
		else
			#уменьшаем размр списка на 1
			testlist_cnt=$(( $testlist_cnt - 1 ))
			lmsg "$p original filelist consist of $testlist_orig files filtered to ($testlist_cnt)"
		fi
	}
	simpleRetentionList=`echo "$outlist"|sort -u`
	simpleRetentionList_cnt=`echo "$simpleRetentionList"|wc -l`
	lmsg "$p original filelist consist of $testlist_orig files filtered to $simpleRetentionList_cnt($testlist_cnt)"
}

cleanWithRetentionList()	#чистит папку оставляя файлы из списка
{
	p="cleanWithRetentionList(): "
	if [ -z "$1" ]; then
		lmsg "SKIP: $p no retention list given!"
		return 13
	fi
	retentioncount=`echo "$1"|wc -l`
	if [ -z "$retstopon" ]; then
		retstopon=$retstopon_global
	fi

	if [ "$retentioncount" -lt "$retstopon" ]; then
		lmsg "SKIP: $p retention list saves only $retentioncount restore points!!!"
		echo "$1"
		return 14
	fi
	testlist=`ls $arcstor/*.{7z,zip} 2>/dev/null`
	anyold="false"
	for testf in $testlist; {
		testbname=`basename $testf`
		if [ $( inlist "$testf" "$1" ) == "true" ]; then
			lmsg_norm "$p $testbname" "actual"
		else
			if [ "$2" = "clean" ]; then
				rm -f $testf
				lmsg_err "$p $testbname" "removed"
			else
				lmsg_err "$p $testbname" "old"
				anyold="true"
			fi
		fi
	}
	if [ "$anyold" = "true" ]; then
		lmsg "HINT: use \"clean\" commandline argument to clean old archives"
	fi
}


jobINIT__()	#подготавливается к работе общая
{

	shareuse

	dircheck $arcstor
}

jobINIT()	#подготавливается к работе
{
	# с каким префиксом делать архивы
	checkvar $archprefx "Arch prefix"

	logfile=/var/log/spookie.backup.$archprefx.log
	lmsg "Log file $logfile attached ----------------------------------------------------------------------------------------------"
	lmsg "Script started:	$archprefx differential backup //library version $libversion"

	# откуда бэкапим
	checkvar "$srcsrv"		"Source path"
	# где хранить архивы
	#checkvar "$arcshare"	"Store share"
	checkvar "$arcstor"		"Store path"

	if [ -f $arch ]; then
		lmsg_ok "Arch binary $arch"
	else 
		lmsg_err "Arch binary $arch" "not found!" && exit 10
	fi

	jobINIT__
}

jobBACKUP()
{
	findlastfull

	setdiffmode $1

	formname

	lmsg "Archiving..."
	cd /
	srcsrv=`echo $srcsrv|sed s/,/\ /g`
	srcarg=""
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
		arcFull "$srcarg"
	else
		arcDiff "$srcarg"
	fi
}

jobCLEAN() #чистка архивов
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

jobDONE()	#завершает работу
{
	cleanafter
	
	sharerelease
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

prepSyncFile()		#$1 - file $2 - temp dir
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

prepSyncFilesList()	#$1 - where to place links $2 - filelist
{
	if [ -z "$2" ]; then
		lmsg "Sync list empty. Nothing to do"
		return 10
	fi
	for ff in $2; do
		prepSyncFile $ff $1
	done
}

syncDirPeriod_async()
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
	prepSyncFilesList $syncdir "$simpleRetentionList"
	
	
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

deleteTempDir()
{
	p="cleanTempDir():"
	lmsg__ "$p cleaning temp dir $1 ... " "err"
	if $( rm -rf $1 ); then
		lmsg__ok "$p cleaning temp dir $1 ... "
	else
		lmsg__err "$p cleaning temp dir $1 ... "
	fi

}

syncDirPeriod()
{
	p="syncDirPeriod():"
	lmsg "$p Syncing [$1] dir"
	checkvar_ret "$1" "$p Archive subdir" && \
	checkvar_ret "$2" "$p Archives dir" && \
	checkvar_ret "$3" "$p Sync age" && \
	checkvar_ret "$4" "$p Remote command" && \
	checkvar_ret "$5" "$p PID file" \
	|| return 10

	syncDirPeriod_async $*
	waitPid $lastpid 
	deleteTempDir $syncdir

	lmsg "$p Syncing [$1] done."

}


checkPIDFile()
{
	lmsg__ "Checking PID file $1 ... "
	if [ -f "$1" ]; then
		lmsg__norm "Checking PID file $1 ... " "busy"
		lmsg "Checking PIDs ..."
		for pid in `cat $1`; do
			lmsg__ "Checking for PID $pid ..." "alive"
			if ps -p $pid > /dev/null; then
				lmsg__err "Checking for pid $pid ..." "alive"
				return 1
			else
				lmsg__err "Checking for pid $pid ..." "miss"
			fi
		done
	else
		lmsg__ok "Checking PID file $1 ... " "free"
	fi
	return 0
}

lockPIDFile()
{
	if checkPIDFile $1; then
		echo $$ > $1
		lmsg_ok "Lock $1"
	else
		lmsg "HALT: Other copy already running."
		exit 10
	fi
}

unlockPIDFile()
{
	lmsg__ "Unlock PID file $1"
	if $( rm -f $1 ); then
		lmsg__ok "Unlock PID file $1"
	else
		lmsg__ "Unlock PID file $1"
	fi
}

waitPid()
{
	lmsg__ "waitPid($1) waiting process#$1 to complete ...."
	while ps -p $lastpid > /dev/null; do
		echo -n "."
		sleep 2
	done
	echo " done"
}

waitManyPids()
{
#ждет завершения одного из процессов из переданного списка
#возвращает списки $pids_destroyed $pids_remain
	lmsg__ "waitManyPids(): waiting for $1 to complete"
	pids_destroyed=""
	while [ -z "$pids_destroyed" ]; do
		pids_remain=""
		for pid in $1;do
			if ps -p $pid > /dev/null; then
				pids_remain="$pids_remain $pid"
			else
				pids_destroyed="$pids_destroyed $pid"
			fi
			
		done
		sleep 2
		echo -n "."
	done
	echo "."
	lmsg "waitManyPids(): $pids_destroyed done"
}
