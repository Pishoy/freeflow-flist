#!/usr/bin/env bash
set -ex

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
export HOME=/root
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'remove a record was added by zos that make our server slow, below is resolv.conf file contents'
cat /etc/resolv.conf

#sed -i '/^nameserver 10./d' /etc/resolv.conf
# start startup script and start it
bash /.setup_ffp_script.sh
chown -R www-data. /var/www/html/humhub

# prepare ssh

chmod 400 -R /etc/ssh/
mkdir -p /run/sshd
[[ -d /root/.ssh/ ]] || mkdir /root/.ssh

# prepare MySQL
mkdir /var/run/mysqld
chown -R mysql /var/lib/mysql
chown -R mysql /var/log/mysql
chown -R mysql /var/run/mysqld
chown -R mysql /var/mysql/binlog
chown -R mysql /var/run/mysqld
find /var/lib/mysql/ -maxdepth 0 -empty -exec  \
    /usr/sbin/mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql/ \;

# prepare redis server

sed -i 's/^pidfile.*$//g' /etc/redis/redis.conf
install -d -m 0755 -o redis -g redis /shared/redis_data
sed -i 's/^bind .*$//g' /etc/redis/redis.conf
sed -i 's|^dir .*$|dir /shared/redis_data|g' /etc/redis/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/g' /etc/redis/redis.conf

mkdir -p /var/log/{mysql,redis,apache2,php,cron}


# start all services
supervisord -c /etc/supervisor/supervisord.conf

user=$DB_USER
pass=$DB_PASS
if [[ ! -d /var/lib/mysql/humhub/ ]] ; then
mysql -e 'CREATE DATABASE IF NOT EXISTS humhub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -e "GRANT ALL ON humhub.* TO '$user'@'localhost' IDENTIFIED BY '$pass'"
mysql -e 'FLUSH PRIVILEGES'
fi
mysqladmin --user=root --password=  password "$ROOT_DB_PASS" &&  password reset successfully || echo ignore error


# crontab
# prepare backup cron
sed -i "s/pROOT_DB_PASS/p${ROOT_DB_PASS}/g" /.backup
export AWS_ACCESS_KEY_ID=our_aws_access_key
export AWS_SECRET_ACCESS_KEY=our_aws_secret_key
export RESTIC_REPOSITORY=our_restic_repository
export RESTIC_PASSWORD=our_restic_password

sed -i "s/our_aws_access_key/${AWS_ACCESS_KEY_ID}/g" /.backup
sed -i "s/our_aws_secret_key/${AWS_SECRET_ACCESS_KEY}/g" /.backup
sed -i "s/our_restic_repository/${RESTIC_REPOSITORY}/g" /.backup
sed -i "s/our_restic_password/${RESTIC_PASSWORD}/g" /.backup

crontab /.all_cron


exec "$@"