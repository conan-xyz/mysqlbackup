#!/bin/bash
# ensure percona-xtrabackup is installed
# auther:Conan

MYSQL_CONF="/etc/mysql/my.cnf"
BACKUP_DIR="/backup"
INCRE_BACKUP_DIR="${BACKUP_DIR}/incre"
FULL_BACKUP_DIR="${BACKUP_DIR}/full"
logfiledate="${BACKUP_DIR}/mysql_full_backup.log"
NOW_TIME=$(date +%Y-%m-%d-%T)
NOW_SECOND=$(date +%s)
DATE=$(date +%Y-%m-%d)
HOSTNAME=$(uname -n)
BACK_DIR="$FULL_BACKUP_DIR/full_backup"
INCRE_DIR="$INCRE_BACKUP_DIR/$DATE.incre.backup"
BIN_LOG_DIR="/var/log/mysql"

ONLINE=$(ss -tunl | grep ":3306" &> /dev/null && echo "alive")
MYSQL_HOST="127.0.0.1"
MYSQL_USER="backuper"
MYSQL_PASSWD="backpasswd"
AVUSER=$(mysqladmin -u${MYSQL_USER} -p${MYSQL_PASSWD} -h${MYSQL_HOST} ping)

# change those three variables
USER='user'
BACK_ADDRESS='backup_ip_address'
STORE_ADDRESS='store_ip_assress'

# ensure dir is exist
[ -d $BACKUP_DIR ] || mkdir -pv $BACKUP_DIR
[ -d $FULL_BACKUP_DIR ] || mkdir -pv $FULL_BACKUP_DIR
[ -d $INCRE_BACKUP_DIR ] || mkdir -pv $INCRE_BACKUP_DIR
[ -f $logfiledate ] || touch $logfiledate

# exec script
echo "---${NOW_TIME}-----------------------------------------" >> ${logfiledate}
if [ ! -f $MYSQL_CONF ]; then
   echo "mysql configure file inexistence,exit!" >> ${logfiledate}
   exit 0
fi

if [ ! "$ONLINE" == "alive" ]; then
   echo "mysql server is down,exit!" >> ${logfiledate}
   exit 0
fi

if [ ! "$AVUSER" == "mysqld is alive" ]; then
   echo "Can not connect to mysql server with $MYSQL_USER" >> ${logfiledate}
   exit 0
fi

transfer ()
{
    scp -p -q -r $1 $USER@$STORE_ADDRESS:/data/mysql_backup_data/$BACK_ADDRESS/$2/
    if [ $? -eq 0 ];then
        echo "Tar file had transfered to $BACK_ADDRESS...."  >> $logfiledate
        rm -f $1 && echo "Delete $1 file success....." >> $logfiledate
    else
        echo "copy to $BACK_ADDRESS failure...."  >> $logfiledate
    fi
}

backup ()
{ 
   echo "--$NOW_TIME-Starting backup mysql-server------------" >> ${logfiledate}
   innobackupex --user=$MYSQL_USER --host=$MYSQL_HOST --password=$MYSQL_PASSWD --defaults-file=$MYSQL_CONF --no-timestamp $BACK_DIR &>> $logfiledate
   Var=`tail -5 $logfiledate | grep "completed OK" | awk '{print $(NF-1)}'`
   if [ "$Var" == "completed" ];then
      echo "Backup success." >> $logfiledate
   else
      echo "Backup failure." >> $logfiledate
      exit 0
   fi
   echo "Condense backups files." $logfiledate
   cp -a $MYSQL_CONF $FULL_BACKUP_DIR 
   find $BIN_LOG_DIR -maxdepth 1 -mindepth 1 -mtime -1 -iname mysql-bin* -exec cp -a {} $FULL_BACKUP_DIR \;
   chmod 444 $BACK_DIR/backup-my.cnf
   cd $FULL_BACKUP_DIR && tar -jcf $BACKUP_DIR/${DATE}.full_backup.tar full_backup && echo "Tar backup dir success...." >> ${logfiledate} 
}

incre_backup ()
{
   echo "--$NOW_TIME-Starting increments backup mysql-server------------" >> ${logfiledate}
   # $INCRE_DIR == $INCRE_BACKUP_DIR/$DATE.incre.backup
   if [ $exptime -gt 108000 ];then
      Dir=`find $INCRE_BACKUP_DIR -maxdepth 1 -mindepth 1 -mmin -1500 -type d -iname *.incre.backup | sort -nr | head -1`  
      innobackupex --user=$MYSQL_USER --host=$MYSQL_HOST --password=$MYSQL_PASSWD --defaults-file=$MYSQL_CONF --no-timestamp --incremental $INCRE_DIR --incremental-basedir=$Dir &>> $logfiledate
      Var=`tail -5 $logfiledate | grep "completed OK" | awk '{print $(NF-1)}'`
      if [ "$Var" == "completed" ];then
         echo "Backup success." >> $logfiledate
      else
         echo "Backup failure." >> $logfiledate
         exit 1
      fi
      cd $INCRE_BACKUP_DIR && tar -jcf $BACKUP_DIR/${DATE}.incre_backup.tar ${DATE}.incre.backup && echo "Tar backup dir success...." >> ${logfiledate}
    else
      innobackupex --user=$MYSQL_USER --host=$MYSQL_HOST --password=$MYSQL_PASSWD --defaults-file=$MYSQL_CONF --no-timestamp --incremental $INCRE_DIR --incremental-basedir=$BACK_DIR &>> $logfiledate
      Var=`tail -5 $logfiledate | grep "completed OK" | awk '{print $(NF-1)}'`
      if [ "$Var" == "completed" ];then
         echo "Backup success." >> $logfiledate
      else
         echo "Backup failure." >> $logfiledate
         exit 1
      fi
      cd $INCRE_BACKUP_DIR && tar -jcf $BACKUP_DIR/${DATE}.incre_backup.tar ${DATE}.incre.backup && echo "Tar backup dir success...." >> ${logfiledate}
   fi
}

# start backup
echo "check need full backup............................" >> ${logfiledate}
if [ ! -d $BACK_DIR ]; then 
   backup
   transfer $BACKUP_DIR/${DATE}.full_backup.tar FULL
   exit
else
   echo "Full backup is exist and check weather expire..."  >> $logfiledate
   setime=$[$NOW_SECOND+3600]
   file_time=$(stat --printf="%Y\n" $BACK_DIR/backup-my.cnf)
   exptime=`expr $setime - $file_time`
   if [ $exptime -gt 604800 ];then
      echo "Full backups is overdue." >> ${logfiledate}
      rm -rf $FULL_BACKUP_DIR/*
      backup
      transfer $BACKUP_DIR/${DATE}.full_backup.tar FULL
      exit 
   else
      echo "Full backups is not overdue." >> ${logfiledate}
      incre_backup
      transfer $BACKUP_DIR/${DATE}.incre_backup.tar INCRE
      expire_increDir=`find $INCRE_BACKUP_DIR -maxdepth 1 -mindepth 1 -mtime +14 -type d -iname *.incre.backup | sort -nr | head -1`
      if [ ! -z $expire_increDir ];then
          echo "Delete incre_backup_file two week ago..."  >> $logfiledate
          rm -rf $expire_increDir && echo "Delete success....."  >> $logfiledate
      fi
      exit
   fi
fi
