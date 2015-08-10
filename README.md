# Deployment Guide:

*自动备份完全合增量脚本，自动备份二进制日志脚本*

*Prerequisite*:
* percona-xtrabackup
* Mysql

*Steps*:
1. 数据库创建最小权限用户用来备份
``` mysql
$ > CREATE USER 'backuper'@'localhost' IDENTIFIED BY 'backpasswd';
$ > REVOKE ALL PRIVILEGES ON *.* FROM backuper@localhost;
$ > REVOKE GRANT OPTION ON *.* FROM backuper@localhost;
$ > GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'backuper'@'localhost';
$ > FLUSH PRIVILEGES;
```

2. 安装percona-xtrabackup(ubuntu 14.04)
``` bash
$ sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
$ sudo add-apt-repository ppa:percona-daily/percona-xtrabackup
$ sudo apt-get update
$ sudo apt-get install percona-xtrabackup
```

3. 选择一个存储服务器并把脚本加入任务计划
```bash(example)
$ sudo vim /etc/crontab
$ 2 2 * * * root backup.sh 
```
