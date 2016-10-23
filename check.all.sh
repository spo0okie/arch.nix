#!/bin/sh

filelist="spookie.diff.arc.lib.sh sync.all.sh clean.all.sh check.all.sh spookie.diff.arc.settings.sh mon.nagios.sh"
updlist="spookie.diff.arc.lib.sh sync.all.sh clean.all.sh check.all.sh mon.nagios.sh"
execlist="sync.all.sh clean.all.sh check.all.sh mon.nagios.sh"
arcvars="arcdir arch arcopts"
syncvars="syncdirs remotesync"
cleanvars="cleandirs"
nagiospluglist="/usr/lib/nagios/plugins /usr/lib64/nagios/plugins"


if [ "$1" = "upd" ]; then
	repo=http://nppx.ru
	for ff in $updlist; do
		wget $repo/$ff -O ./$ff
	done
fi

for ff in $execlist; do
	chmod 775 ./$ff
done

echo "Archiving scheme checking..."
echo "FILES CHECK"

if  ! [ -f "./spookie.diff.arc.lib.sh" ]; then
	echo "Arc library not found!"
	exit 10
fi

. ./spookie.diff.arc.lib.sh

lmsg_ok "Main library loading"
lmsg "Checking core files"

for ff in $filelist; do
	if [ -f $ff ]; then
		lmsg_ok $ff
	else
		lmsg_err $ff "missing"
	fi
done

echo "SETTINGS CHECK"
. ./spookie.diff.arc.settings.sh

lmsg_ok "Main settings file loading"

echo "Archiving mode:"
for vv in $arcvars; do
	checkvar_ret "${!vv}" "$vv (${!vv})"
done

echo "Sync mode:"
for vv in $syncvars; do
	checkvar_ret "${!vv}" "$vv (${!vv})"
done

for archprefx in $syncdirs; do
	vv=`echo "sync_age_$archprefx"|tr '\/' '_'`
	checkvar_ret "${!vv}" "$vv (${!vv}) "
done

echo "Var adding help:"
for archprefx in $syncdirs; do
	vv=`echo "sync_age_$archprefx"|tr '\/' '_'`
	if [ -z "${!vv}" ]; then
		echo "$vv="
	fi
done

echo "Clean mode:"
for vv in $cleanvars; do
	checkvar_ret "${!vv}" "$vv (${!vv})"
done

for archprefx in $cleandirs; do
	vv=`echo "retention__$archprefx"|tr '\/' '_'`
	checkvar_ret "${!vv}" "$vv (${!vv}) "
done

echo "Var adding help:"
for archprefx in $cleandirs; do
	vv=`echo "retention__$archprefx"|tr '\/' '_'`
	if [ -z "${!vv}" ]; then
		echo "$vv="
	fi
done

echo "Monitoring:"
for ff in $nagiospluglist; do
	if [ -d "$ff" ]; then
		lmsg_norm "Nagios plugins dir" $ff
		nagioslib=$ff
	fi
done

if [ -n "$nagioslib" ]; then
		rm -f $nagioslib/check_diff_arch.sh 2>>/dev/null
		ln ./mon.nagios.sh $nagioslib/check_diff_arch.sh
fi
