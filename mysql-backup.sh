#!/bin/sh
## MySQL Backup Package v1.0
## Authored By Russ Thompson 2008 @ viGeek.net
## Updated: 2011 - Russ@vigeek.net

# NO NEED to edit anything in this file.

if [ -f "mysql-backup.conf" ] ; then
	. ./mysql-backup.conf
else
	echo -e "Unable to read the configuration file"
	exit 1
fi

# Define our email subject (default is failure)
EMAIL_SUB="mySQL Backup Error on $(hostname)"
EMAIL_TEMP_FILE="/tmp/mysqlbackup.txt"
# Define our output file name  (changing this will cause issues)
FILE_OUT="db_$(hostname)_$(date +%m-%d-%Y)"
# We use this to track the amount of time
TIME_HOLD="/tmp/timehold.txt"
# Reporting hold
REPORT_HOLD="/tmp/rephold.txt"

log () {
  if [ -z "$1" ]; then
    echo -e "Unable to log data, data missing.  $(basename 0)"
    send_mail
    exit 1
  fi
  
  echo -e "[`date +"%D-%H:%M:%S"`] $1" >> $LOG_FILE

}

report() {
	echo -e "$1" >> $REPORT_HOLD
}

send_mail () {
	/bin/mail -s "$EMAIL_SUB" "$EMAIL_ADDRESS" < $EMAIL_TEMP_FILE
	rm -f $EMAIL_TEMP_FILE
}


# Seperation
log "------------------------------------------------------------------"

# Kickoff
log "$(basename $0) has started at: $(date +%l:%M%p)"

# This is our cleanup function, if anything unusual happens.
# We send an e-mail and cleanup.
clean_up () {
        # Performance success cleanup
          if [ -z "$1" ]; then
              #Perform actions on errors.  Need to fix lineno
					echo -e "$(hostname) caught error on line $LINENO at \
					$(date +%l:%M%p) via script $(basename $0)" >> $EMAIL_TEMP_FILE
					log "Caught error on $LINENO at $(date +%l:%M%p)"
					send_mail
					exit 1
          fi
				log "$(basename $0) backup successfully completed"
				rm -f $EMAIL_TEMP_HOLD $REPORT_HOLD $TIME_HOLD
            exit 0    
}
# Define our trap conditions
trap clean_up ERR SIGHUP SIGINT SIGTERM

singles_backup () {
  for i in $DB_BACKUP ; do
    nice -n $PRIORITY mysqldump --user $DB_USER --password=$DB_PASS $i > $i.sql | \
        tar -rpf $FILE_OUT.tar $i.sql && rm -f $i.sql
    log "Created mySQL dump for database $i"
  done
  
  if [ $COMPRESS -eq "1" ] ; then
    nice -n $PRIORITY gzip $FILE_OUT.tar
  fi
  
}

all_backup () {
	if [ $SEPARATE_FILES -eq "1" ] ; then
		for dbs in `echo "show databases;" | mysql --user=$DB_USER --password=$DB_PASS` ; do
			if [ $COMPRESS -eq "1" ] ; then
				nice -n $PRIORITY mysqldump --user=$DB_USER --password=$DB_PASS $dbs | \
					gzip > $dbs.sql.gz
			else
				nice -n $PRIORITY mysqldump --user=$DB_USER --password=$DB_PASS $dbs > $dbs.sql
			fi
		done
			if [ $COMPRESS -eq "1" ] ; then
				tar -czvf $FILE_OUT.tar.gz *.gz
				rm -f $(ls *.gz | grep -v "$FILE_OUT")
			fi
	else
		#FILE_OUT="$(echo $FILE_OUT | sed "s/.tar//g")"
		if [ $COMPRESS -eq "1" ] ; then
			nice -n $PRIORITY mysqldump --user=$DB_USER --password=$DB_PASS --all-databases | \
			gzip > $FILE_OUT.gz
		else
			nice -n $PRIORITY mysqldump --user=$DB_USER --password=$DB_PASS --all-databases > $FILE_OUT.sql
		fi
	fi

 
}

archive_policy () {
  if [ $ARCHIVE -eq "1" ] ; then
    # File exists?
    if [ -f db_* ] ; then
      # Move last backup to archive.
      mv db_* $ARCHIVE_PATH
      # Remove outdated backups
      find $ARCHIVE_PATH -type f -mtime +$ARCHIVE_DAYS -exec rm {} \;
      # Generate report
      report "Older backups on hand:"
      report "$(ls -l $ARCHIVE_PATH/db_* | awk '{print $9}')"
    else
      log "No backup to archive, continuing"
    fi
   
  else
   # Remove last backup.
    rm -f $FILE_OUT.* 
  fi
}

func_ftp () {

	if [ $REMOTE_ARCHIVE -eq "1" ] ; then
		ftp -n $FTP_HOST << EOF
		quote USER "$FTP_USER"
		quote PASS "$FTP_PASS"
		prompt
		cd $FTP_PATH
		put $PASSED_FILE
		mdel $ARCHIVE_FILE*
		quit
EOF
		if [ $? -eq "1" ] ; then
			# Add failure handling
			log "Error during FTP upload"
			exit 1
		fi

	else
		ftp -n $FTP_HOST << EOF
		quote USER "$FTP_USER"
		quote PASS "$FTP_PASS"
		cd $FTP_PATH
		put $PASSED_FILE
		quit
EOF
		if [ $? -eq "1" ] ; then
			log "Error during FTP upload"
			exit 1
		fi
	fi

}

# SSH/SCP Export Function

func_ssh () {
  echo ssh
}

# rSync Export Function

func_rsync () {
	echo rsync
}


# Begin calculation of backup time.
TIME_NOW="$(date +%s)"

# Configure our priority (nice)
PRIORITY=$(echo $PRIORITY | awk '{print tolower($0)}')
  if [ $PRIORITY == "high" ] ; then
    PRIORITY="-10"
  elif [ $PRIORITY == "low" ] ; then
    PRIORITY="10"
  else
    PRIORITY="0"
  fi
  
# Change into working directory
cd $DEST_DIR

log "Changed into directory $(pwd)" 

# Before we continue ensure we're in the right place

if echo $(pwd)| grep $DEST_DIR >> /dev/null
        then
        echo -e "Good" >> /dev/null
else
        log "ERROR: expecting directory $DEST_DIR however in $(pwd)" 
        clean_up
fi

if [ $ARCHIVE -eq "1" ] ; then
	archive_policy
fi

if [ $DB_ALL_BACKUP -eq "1" ] ; then
	all_backup
else
	singles_backup
fi


# Calculate how long it took
# Time after
TIME_AFTER="$(date +%s)"
# Compute time
TIME_DIFF="$(expr $TIME_AFTER - $TIME_NOW)"
echo |awk '{print strftime('$TIME_DIFF',1)}' > $TIME_HOLD

if [ $REMOTE_ARCHIVE -eq "1" ] ; then
	ARCHIVE_FILE="db_$(hostname)_$(date +%m-%d-%Y --date "$transform -$ARCHIVE_DAYS day")"
fi

if [ $FTP_EXPORT -eq "1" ] ; then
	PASSED_FILE="$(ls | grep $FILE_OUT)"
	func_ftp
fi

clean_up "0"

