#!/bin/sh
## MySQL Backup Package v1.0
## Authored By Russ Thompson 2008 @ viGeek.net
## Updated: 2011 - Russ@vigeek.net

PASSED_FILE="$1"


# FTP Export Function

func_ftp () {


ftp -n $FTP_HOST << EOF
quote USER "$FTP_USER"
quote PASS "$FTP_PASS"
cd $FTP_PATH
put $PASSED_FILE
quit
EOF
  if [ $? -eq "1" ] ; then
	# Add failure handling
	exit 1
  fi

}

# SSH/SCP Export Function

func_ssh () {

}

# rSync Export Function

func_rsync () {

}
