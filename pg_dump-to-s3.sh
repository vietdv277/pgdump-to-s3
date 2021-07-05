#!/bin/bash -x

#                     _                             _                  _____ 
#  _ __   __ _     __| |_   _ _ __ ___  _ __       | |_ ___        ___|___ / 
# | '_ \ / _` |   / _` | | | | '_ ` _ \| '_ \ _____| __/ _ \ _____/ __| |_ \ 
# | |_) | (_| |  | (_| | |_| | | | | | | |_) |_____| || (_) |_____\__ \___) |
# | .__/ \__, |___\__,_|\__,_|_| |_| |_| .__/       \__\___/      |___/____/ 
# |_|    |___/_____|                   |_|                                   
#
# Project at https://github.com/gabfl/pg_dump-to-s3
#

set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import config file
source $DIR/pg_dump-to-s3.conf

# Vars
NOW=$(date +"%Y-%m-%d-at-%H-%M-%S")
DELETETION_TIMESTAMP=`[ "$(uname)" = Linux ] && date +%s --date="-$S3_DELETE_AFTER"` # Maximum date (will delete all files older than this date)
BACKUPDIR=/var/backups/postgresql
STARTBKTIME=$(date +'%a %b %d %Y %H:%M:%S %z')
# Split databases
IFS=',' read -ra DBS <<< "$PG_DATABASES"


# Delere old files
echo "Backup of Database Server: $(hostname)"
echo ""
echo "======================================================================"
echo "Backup Start Time: $STARTBKTIME"
echo "======================================================================"
echo ""
echo "======================================================================"
echo "Backup in progress...";
echo "======================================================================"

# Loop thru databases
for db in "${DBS[@]}"; do
    FILENAME="$NOW"_"$db"

    echo "----------------------------------------------------------------------"
    echo "Backing up database: $db..."
    

    # Dump database
    pg_dump -Fc -h $PG_HOST -U $PG_USER -p $PG_PORT $db > $BACKUPDIR/"$FILENAME".dump

    # Copy to local storage
    #cp /$BACKUPDIR/"$FILENAME".dump $BACKUPDIR

    # Copy to S3
    aws s3 cp $BACKUPDIR/"$FILENAME".dump s3://$S3_PATH/"$FILENAME".dump --storage-class STANDARD_IA

    # Delete local file
    #rm /tmp/"$FILENAME".dump

    # Log
    echo ""
    echo "Database $db has been backed up with information:"
    echo ""
    echo "Size         Location"
    echo "$(du -sh $BACKUPDIR/"$FILENAME".dump)"
    echo "----------------------------------------------------------------------"
 
done

# Delere old files
echo ""
echo "======================================================================"
echo "Deleting old backups...";
echo "======================================================================"
echo ""
echo "Deleting old backups from S3.."

# Delete old backups from S3
aws s3 ls s3://$S3_PATH/ | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $DELETETION_TIMESTAMP ]]
    then
        # Get file name
        FILENAME=`echo $line|awk {'print $4'}`
        if [[ $FILENAME != "" ]]
          then
            echo "Deleting $FILENAME"
            aws s3 rm s3://$S3_PATH/$FILENAME
        fi
    fi
done;
echo "----------------------------------------------------------------------"
echo ""
# Delete old backups from local storage
echo "Deleting old backups from local storage..."
find $BACKUPDIR -mtime "+$LOCAL_DELETE_AFTER" -exec rm -rf {} \;
echo "----------------------------------------------------------------------"

echo ""
echo "======================================================================"
echo ""
echo "Total disk space used for backup storage:"
echo ""
echo "Size         Location"
echo "$(du -sh $BACKUPDIR)"
echo ""
echo "...Done!";

