#!/bin/sh

#$1 Общая папка где лежат архивы
#$2 Конкретная подпапка с архивами
#$3 Критическое значение параметра актуальности (в часах)
#$4 Warning значение

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="0.1.0"
. /usr/local/etc/arch/spookie.diff.arc.lib.sh
. $PROGPATH/utils.sh

if [ -z "$1" ]; then
	echo "No archive dir passed"
	exit $STATE_UNKNOWN
fi

if [ -z "$2" ]; then
	echo "No archive subdir passed"
	exit $STATE_UNKNOWN
fi

if [ -z "$3" ]; then
	crit=50;
else
	crit=$3
fi

if [ -z "$4" ]; then
	warn=25;
else
	warn=$4
fi

case `date +%u` in
	"7" )
		warn=$(( $warn + 24 ))
		crit=$(( $crit + 24 ))
	;;
	"1" )
		warn=$(( $warn + 48 ))
		crit=$(( $crit + 48 ))
	;;
esac

lastfile=$(findLastArc $1/$2)

if [ -z "$lastfile" ]; then
	echo "$msg CRIT: No archives found"
	exit $STATE_CRITICAL
fi

hours=$(getFileHoursAge $lastfile)
msg="${hours}h old"


if [ $(fileIsDiff $lastfile) = "diff" ]; then
	master=$1/$2/$(fullFromDiff $lastfile)
	if [ ! -f "$master" ]; then
		echo "No full archive $master for diff $lastfile"
		exit $STATE_CRITICAL
	fi
	mdays=$(getFileDaysAge $master)
	msg="$msg (full ${mdays}days old)"
fi

#additional stats
arcsize=`du -sh $1/$2|cut -f1`
arccount=`ls -1 $1/$2/*.{7z,zip} 2>/dev/null|wc -l`
arcfirst=`ls -1 -r -t $1/$2/*.{7z,zip} 2>/dev/null|head -n1`
arcfirstdate=$(getFileUnixTime $arcfirst)
arcfirstdatereadable=`date -d@$(getFileUnixTime $arcfirst) +%Y-%m-%d`
arcfirstagedays=$(getFileDaysAge $arcfirst)
msg="$msg	/Total: $arcsize	/Count: $arccount	/First: $arcfirstdatereadable ($arcfirstagedays days old)"

if [ $hours -lt $warn ] ; then
        echo "$prfx OK: $msg"
        exit $STATE_OK
else
        if [ $hours -lt $crit ] ; then
	        echo "$prfx WARN: $msg"
                exit $STATE_WARNING
        else
	        echo "$prfx CRIT: $msg"
                exit $STATE_CRITICAL
        fi
fi



