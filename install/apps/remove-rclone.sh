#!/bin/bash

source ${CONFIGS}/Docker/.env
which rclone > ${CONFIGVARS}/checkapp
clear

if [ ! -s ${CONFIGVARS}/checkapp ]; then

	NOTINSTALLED

else

	EXPLAINTASK

	CONFIRMATION

	if [[ ${REPLY} =~ ^[Yy]$ ]]; then

		GOAHEAD

		# Main script

		/bin/fusermount -uz ${RCLONEMOUNT}
		/bin/fusermount -uz ${RCLONEMOUNT2}
		sudo rm /usr/bin/rclone
		sudo rm /usr/local/share/man/man1/rclone.1

		# Removing Services

		if [ -f /etc/systemd/system/rclone.service ]; then
			sudo systemctl stop rclone
			sudo systemctl disable rclone.service
			sudo rm /etc/systemd/system/rclone.service
		fi

		if [ -f /etc/systemd/system/gooby.service ]; then
			sudo systemctl stop gooby
			sudo systemctl disable gooby.service gooby-rclone.service gooby-find.service mnt-google.mount
			sudo rm /etc/systemd/system/gooby* /etc/systemd/system/mnt-*
		fi

		if [ -f /etc/systemd/system/rclonefs.service ]; then
			sudo systemctl stop mergerfs rclonefs
			sudo systemctl disable mergerfs.service rclonefs.service
			sudo rm /etc/systemd/system/mergerfs* /etc/systemd/system/rclonefs*
		fi
			
		if [ -f /etc/systemd/system/rclonefm.service ]; then
			sudo systemctl stop mergerfm rclonefm
			sudo systemctl disable mergerfm.service rclonefm.service
			sudo rm /etc/systemd/system/mergerfm* /etc/systemd/system/rclonefm*
		fi

		sudo rmdir ${RCLONEMOUNT} > /dev/null 2>&1
		sudo rmdir ${MOUNTTO} > /dev/null 2>&1
		sudo rmdir ${RCLONEMOUNT2} > /dev/null 2>&1
		sudo rmdir ${MOUNTTO2} > /dev/null 2>&1

		sudo systemctl daemon-reload

		TASKCOMPLETE

	else

		CANCELTHIS

	fi

fi

rm ${CONFIGVARS}/checkapp
PAUSE
