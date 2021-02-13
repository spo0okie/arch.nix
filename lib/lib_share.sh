#!/bin/sh
lib_share_version="2.0.1 rc2"

#hist:
#	2018-07-28
#2.0.0 * Библиотека разделена на меньшие для простоты управления

#core check
if [ -z "lib_core_version" ]; then
        echo "HALT: Error loading $0 - load core first!"
        exit 99
fi

lib_require lib_con

arc_share_var_ck()
{
	if ! [ -z "$arcshare" ]; then
		lmsg "Checking remote share vars set ..."
		#шара куда архивировать
		var_ck arcshare
		#учетные данные самбы/cifs для этой шары
		var_ck arcuser
		var_ck arcsecret
		#какую папку использовать как точку монтирования
		var_ck mountroot
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
		if $( mount -t cifs -o username="$arcuser",password="$arcsecret" $arcshare $mountpoint ); then
			lmsg_ok "$p"
			return 0
		else
			lmsg_err "$p"
			lmsg "retry in 30 secs (waiting) ... "
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
	while true ; do
		if $( umount $mountpoint ); then
			lmsg_ok "$p"
			return 0
		else
			lmsg_err "$p"
			lmsg "retry in 7 sec (waiting) ... "
			sleep 7
		fi
	done
}


