#!/bin/sh
lib_arc_version="2.0.0 rc"

#hist:
#	2018-07-28
#2.0.0 * Библиотека разделена на меньшие для простоты управления
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


#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_con
lib_require lib_process
lib_require lib_ini_files



########################################################################
###   F U N C S  #######################################################
########################################################################

#проверяет что установлены все переменные для архивации папки
arc_var_ck()
{
	lmsg "Checking archivation vars set ..."
	#бинарник архиватора
	var_ck arch
	# Режим архивации
	var_ck mode
	# Префикс архивов
	var_ck archprefx
	# откуда бэкапим
	var_ck srcsrv
	# где хранить архивы
	var_ck arcstor
	#периодичность полных архивов
	var_ck fulllifetime
}

#Выбирает какой режим архивации будет использоваться в зависимости от желаемого и условий
arc_setdiffmode()	#set diff or full mode for current job
{
	p="arc_setdiffmode($1):"
	if [ -n "$lastfull" ]; then
		case "$1" in
			[Mm][Oo][Nn][Tt][Hh][Ll][Yy])
				day=`date +%m`
				if [ "$lastfull_age_days" -lt "$fulllifetime" ]; then
					diffmode=true
					lmsg_norm "$p Monthly shedule" "Diff mode"
				else
					lmsg_err "$p Monthly shedule (full is older than $fulllifetime day!)" "Full mode"
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

arc_formname()	#form name for current job file
{	
	#lmsg "Forming archive date prefix"
	dateprefx=`date +%Y%m%d-%H%M%S`
	lmsg_norm "arc_formname(): Prefix set" "$archprefx-$dateprefx"
}

arc_cleanafter()
{
	if [ "$cleandirsafter" == "" ]; then
		lmsg "arc_cleanafter(): Dirs list for cleaning is empty. Nothing to clean after archiving..."
	else
		echo "arc_cleanafter(): FOR %%i IN (%cleandirsafter%) DO (CALL :dircheck %%i clean)"
	fi
}


arc_Diff()	#arc in diff mode
{
	
	p="arcDiff($1): $arch u $lastfull $arcopts $srcxcl -u- -up3q3r2x2y2z0w2\\!$arcstor/$archprefx-$dateprefx-diff-$lastfull_base $1"
	lmsg "$p"

	if [ "$CON_TTY" == "tty" ]; then
		#teeing output if someone watching
		$arch u $lastfull $arcopts $srcxcl -u- -up3q3r2x2y2z0w2\!$arcstor/$archprefx-$dateprefx-diff-$lastfull_base $1 | tee -a $logfile
	else
		#logging if nobody watching
		$arch u $lastfull $arcopts $srcxcl -u- -up3q3r2x2y2z0w2\!$arcstor/$archprefx-$dateprefx-diff-$lastfull_base $1 >> $logfile
	fi

	if [ "$?" -eq "0" ]; then
		lmsg_ok "$p"
	else
		lmsg_err "$p"
	fi
}

arc_Full()	#arc in full mode
{
	p="arcFull($1): $arch a $arcstor/$archprefx-$dateprefx-full.7z $arcopts $srcxcl $1"
	lmsg "$p"

	if [ "$CON_TTY" == "tty" ]; then
		#teeing output if someone watching
		$arch a $arcstor/$archprefx-$dateprefx-full.7z $arcopts $srcxcl -bb3 $1 | tee -a $logfile
	else
		#logging if nobody watching
		$arch a $arcstor/$archprefx-$dateprefx-full.7z $arcopts $srcxcl -bb3 $1 >> $logfile
	fi

	if [ "$?" -eq "0" ]; then
		lmsg_ok "$p"
	else
		lmsg_err "$p"
	fi
}
