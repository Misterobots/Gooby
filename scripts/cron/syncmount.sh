#!/bin/bash
if pidof -o %PPID -x "$(basename $0)"; then
	echo Already running!
	exit 1
fi

source /opt/Gooby/menus/variables.sh
source ${CONFIGS}/Docker/.env

# Check to see if anything needs to be cached locally.  Doing this before the sync allows new files to be copied locally first.

[ -f ${HOME}/bin/localcache ] && ${HOME}/bin/localcache

# Load existing variables and use them as defaults, if available

AGE=2	# How many minutes old a file must be before copying/deleting
LOG=${LOGS}/mounter-sync.log
TEMPFILE="/tmp/filesmissing"
TEMPFILE2="/tmp/filesmissing2"

echo Starting sync at $(date) | tee -a ${LOG}

# Fix dates in the future

find ${UPLOADS}/ ! -path "*Downloads*" ! -iname "*.partial~" -type f -mmin -0 -exec touch "{}" -d "$(date -d "-5 minutes")" \;

# Identify files needing to be copied

find ${UPLOADS}/ ! -path "*Downloads*" ! -iname "*.partial~" -type f -mmin +${AGE} | sed 's|'${UPLOADS}'||' | sort > ${TEMPFILE}

# Fix dates in the future

find ${UPLOADS2}/ ! -path "*Downloads2*" ! -iname "*.partial~" -type f -mmin -0 -exec touch "{}" -d "$(date -d "-5 minutes")" \;

# Identify files needing to be copied

find ${UPLOADS2}/ ! -path "*Downloads2*" ! -iname "*.partial~" -type f -mmin +${AGE} | sed 's|'${UPLOADS2}'||' | sort > ${TEMPFILE2}

# Copy files

if [[ -s ${TEMPFILE} ]]
then
	while IFS= read -r FILE
	do
		rclone rc core/stats --user ${RCLONEUSERNAME} --pass ${RCLONEPASSWORD} | jq '.transferring' | grep "${UPLOADS}${FILE}" > /dev/null
		RUNCHECK=${?}
		if [[ ${RUNCHECK} -gt 0 ]]; then
			BYTES=$(du "${UPLOADS}${FILE}" | cut -f1)
			BYTESH=$(du -h "${UPLOADS}${FILE}" | cut -f1)
			echo $(date '+%F %H:%M:%S'),START,1,${BYTES} "# ${FILE}" >> ${APILOG}
			echo Queuing ${FILE} of size ${BYTESH}
	                ## Fix for Rclone RC creating multiple directories
			TESTDIR="${RCLONEMOUNT}$(dirname "${FILE}")"
			if [[ ! -d "${TESTDIR}" ]]; then
				mkdir -p "${TESTDIR}"
			fi
			rclone rc operations/movefile _async=true srcFs=Local: srcRemote="${UPLOADS}${FILE}" dstFs=${RCLONESERVICE}:${RCLONEFOLDER} dstRemote="${FILE}" --user ${RCLONEUSERNAME} --pass ${RCLONEPASSWORD} > /dev/null
			# echo "Sleeping 1 second - temp fix for duplicate folders" ; sleep 1
		else
			echo Skipping ${FILE}:  Already in queue
		fi
	done < ${TEMPFILE}
else
	echo Nothing to copy | tee -a ${LOG}
fi

if [[ -s ${TEMPFILE2} ]]
then
	while IFS= read -r FILE2
	do
		rclone rc core/stats --user ${RCLONEUSERNAME} --pass ${RCLONEPASSWORD} | jq '.transferring' | grep "${UPLOADS2}${FILE2}" > /dev/null
		RUNCHECK=${?}
		if [[ ${RUNCHECK} -gt 0 ]]; then
			BYTES=$(du "${UPLOADS2}${FILE2}" | cut -f1)
			BYTESH=$(du -h "${UPLOADS2}${FILE2}" | cut -f1)
			echo $(date '+%F %H:%M:%S'),START,1,${BYTES} "# ${FILE2}" >> ${APILOG}
			echo Queuing ${FILE2} of size ${BYTESH}
	                ## Fix for Rclone RC creating multiple directories
			TESTDIR="${RCLONEMOUNT2}$(dirname "${FILE2}")"
			if [[ ! -d "${TESTDIR}" ]]; then
				mkdir -p "${TESTDIR}"
			fi
			# echo "Sleeping 1 second - temp fix for duplicate folders" ; sleep 1
			rclone rc operations/movefile _async=true srcFs=Local: srcRemote="${UPLOADS2}${FILE2}" dstFs=${RCLONESERVICE2}:${RCLONEFOLDER2} dstRemote="${FILE2}" --user ${RCLONEUSERNAME} --pass ${RCLONEPASSWORD} > /dev/null
		else
			echo Skipping ${FILE2}:  Already in queue
		fi
	done < ${TEMPFILE2}
else
	echo Nothing to copy | tee -a ${LOG}
fi

# Cleanup letovers

rm ${TEMPFILE}
cd ${UPLOADS}
find . ! -path "*Downloads*" -type d -empty -delete
cd ${UPLOADS2}
find . ! -path "*Downloads2*" -type d -empty -delete
echo Finished at $(date) | tee -a ${LOG}
echo --------------------------------------------------- | tee -a ${LOG}
