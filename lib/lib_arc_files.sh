#!/bin/sh
lib_arc_files_version="2.1.0"

#hist:
#	2018-08-14
#2.1.0 + добавлены процедуры для работы с удаленными путями (в формате для rsync)

#	2018-08-13
#2.0.1 + findFirstArc()

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

keys_storage=$HOME/.ssh

#
remotePathCheck()
{
	echo $1 | grep -E '[0-9a-zA-Z]+\@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:' >/dev/null 2>&1
	return $?
}

#распарсивает имя удаленного файла и присваивает переменные удаленного сервера и удаленного пути
remotePathParse() 
{
	remotefname=$1
	remoteserver=${remotefname%:*}
	remotepath=${remotefname##*:}
}


getFileUnixTime() #returns file creation time in unixtimestamp; usage ftime=$(getFileFileUnixtime $1)
{
	#путь удаленный или локальный?
	if $( remotePathCheck $1); then
		#удаленный путь
		remotePathParse $1
		ssh -i $keys_storage/$remoteserver-key $remoteserver "stat -c %Y $remotepath 2>>/dev/null"
		#ssh -i $keys_storage/$remoteserver-key $remoteserver "stat -c %Y $remotepath 2>&1" 2>&1
	else
		stat -c %Y $1 2>>/dev/null	
	fi
}

getFileAge() #returns age in seconds of $1 file; usage hours=$(getFileHoursAge $1)
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
	#путь удаленный или локальный?
	if $( remotePathCheck $1); then
		#удаленный путь
		remotePathParse $1
		response=`ssh -i $keys_storage/$remoteserver-key $remoteserver "ls -1 -t $remotepath/*.{7z,zip} 2>/dev/null| head -n 1"`
		if [ -n "$response" ]; then
			echo "$remoteserver:$response"
		else
			echo ""
		fi
	else
		ls -1 -t $1/*.{7z,zip} 2>/dev/null| head -n 1
	fi
}

findFirstArc() #finds last archve file $1 - arcstor directory
{
	#путь удаленный или локальный?
	if $( remotePathCheck $1); then
		#удаленный путь
		remotePathParse $1
		response=`ssh -i $keys_storage/$remoteserver-key $remoteserver "ls -1 -t $remotepath/*.{7z,zip} 2>/dev/null| tail -n 1"`
		#ssh -i $keys_storage/$remoteserver-key $remoteserver "ls -1 -t $remotepath/*.{7z,zip}" 2>&1
		if [ -n "$response" ]; then
			echo "$remoteserver:$response"
		else
			echo ""
		fi
	else
		ls -1 -t $1/*.{7z,zip} 2>/dev/null| tail -n 1
	fi
}

findLastFullArc() #finds last archve file $1 - arcstor directory
{
	#путь удаленный или локальный?
	if $( remotePathCheck $1); then
		#удаленный путь
		remotePathParse $1
		response=`ssh -i $keys_storage/$remoteserver-key $remoteserver "ls -1 -t $remotepath/*.{7z,zip} 2>/dev/null | grep '\-full\.' | grep -v '\-diff\-' | head -n1"`
		if [ -n "$response" ]; then
			echo "$remoteserver:$response"
		else
			echo ""
		fi
	else
		ls -1 -t $1/*.{7z,zip} 2>/dev/null | grep '\-full\.' | grep -v '\-diff\-' | head -n1
	fi
	
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
