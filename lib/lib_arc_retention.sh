#!/bin/sh
lib_arc_retention_version="2.0.0 rc"

#hist:
#	2018-07-28
#2.0.0 * Библиотека разделена на меньшие для простоты управления

#TODO:
#	при чистке если остается точек меньше чем retention_stop_on, то нужно не отменять чистку вообще, а корректировать список
#cleanafter()
#buildSimpleRetentionList() - удалять инконсистентные файлы (дифф без фула)
#передавать день для полных копий, чтобы распределить равномерно нагрузку по дням а не в один день все


#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_con
lib_require lib_arc_files


arc_retention_var_ck()
{
	lmsg "Checking archives retention vars set ..."
	var_ck arcstor
	var_ck retention_stop_on
	var_ck retention_policies
	for pol in $retention_policies; {
		case $pol in
			[Ss][Ii][Mm][Pp][Ll][Ee])
				var_ck retention_simple_age
			;;
		esac
	}
}

#делаем список файлов для сохранения по правилу "все не старше чем... $1"
#использует glob переменную retention_stop_on - минимальное количество файлов которое нужно оставлять
#результатом является глобальная переменная simpleRetentionList
buildSimpleRetentionList()	
{
	p="buildSimpleRetentionList($1): "
	if [ -z "$1" ]; then
		halt "$p no retention age given!" 13
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
	var_ck retention_stop_on
	lmsg "$p filtering out files older than $retentiondatereadable ($retention_stop_on limit)... "
	for testf in $testlist; {
		#пропускаем файлы если длинна списка укоротилась до предельной
		if [ "$testlist_cnt" -le "$retention_stop_on" ]; then
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
	var_ck retention_stop_on

	if [ "$retentioncount" -lt "$retention_stop_on" ]; then
		lmsg "SKIP: $p retention list saves only $retentioncount restore points!!!"
		echo "$1"
		return 14
	fi
	testlist=`ls $arcstor/*.{7z,zip} 2>/dev/null`
	anyold="false"
	for testf in $testlist; {
		testbname=`basename $testf`
		if $( arr_inlist "$testf" "$1" ); then
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

