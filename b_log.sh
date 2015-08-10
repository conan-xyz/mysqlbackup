#!/bin/bash
[ -f /backup/bin_log_backup.log ] || touch /backup/bin_log_backup.log
nowtime=$(date +%Y-%m-%d-%T)
BIN_LOG="/backup/bin_log_backup.log"
echo "-------------$nowtime-----------------------------------"  >> $BIN_LOG
echo "-------------Starting backup bin_log--------------------"  >> $BIN_LOG
for name in `find /var/log/mysql/ -maxdepth 1 -mindepth 1 -mmin -120  -type f -iname mysql-bin* | sort -nr`;do
    scp -p -q $name zonzpoo@115.28.191.78:/data/mysql_backup_data/121.41.75.133/BIN_LOG/ && echo "Backup $name success............." >> $BIN_LOG
done

for expire_name in `find /var/log/mysql/ -maxdepth 1 -mindepth 1 -mtime +15  -type f -iname mysql-bin* | sort -nr`;do
    if [  ! -z $expire_name ];then
       rm -f $expire_name && echo "Delete MYSQL bin-log $expire_name two week ago sucess....................." >> $BIN_LOG
    fi
done    
