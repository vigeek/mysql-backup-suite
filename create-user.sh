#!/bin/bash
# Simply creates a mysql backup user with limited permissions.
# Russ@vigeek.net

echo -n "Enter the backup user's name (e.g:  backup-user):"
	read B_USER

echo -n "Enter the backup users password:"
	read B_PASS

echo -e "Select user connectivity permissions -"
echo -e "1 - localhost only (if backups being performed locally)"
echo -e "2 - allow all hosts % (security risk)"
echo -e "3 - single remote host (you will be prompted for IP)"
echo -n "Selected option:"
	read B_PERM

if [ "$B_PERM" == "1" ] ; then
	B_PERM="127.0.0.1"
elif [ "$B_PERM" == "2" ] ; then
	B_PERM="%"
elif [ "$B_PERM" == "3" ] ; then
	echo -n "Enter the IP/hostname address of the remote host: "
		read B_PERM
			if [ -z "$B_PERM" ] ; then
				echo -e "Error:  invalid entry"
				exit 1
			fi
else
	echo -e "Error:  invalid selection"
	exit 1
fi

echo -e ""
echo -e "Preparing to create account"
echo -e ""
	echo -n "Enter your root/admin mysql username: "
		read B_USER
echo -e "mySQL prompting for root/admin user pass (hit enter if blank)..."
		
MYSQL_STATEMENT="GRANT SHOW DATABASES, SELECT, RELOAD, LOCK TABLES ON *.* TO '$B_USER'@'$B_PERM' IDENTIFIED BY '$B_PASS';"
	echo -e "$MYSQL_STATEMENT" | mysql -u"$B_USER" -p 1> /dev/null
	
	
