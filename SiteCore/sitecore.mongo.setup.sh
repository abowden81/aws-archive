echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
cat << END > /etc/security/limits.conf
mongod  soft  nofile  64000
mongod  soft  nproc 32000
END
yum install -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools
mkdir -p /data/db
touch /var/run/mongodb/mongod.pid
chown mongod:mongod /var/run/mongodb/mongod.pid
chown -Rv mongod:mongod /data/mongodb
chown -Rv mongod:mongod /data/db
chown -Rv mongod:mongod /var/lib/mongo
chcon -Rv --type=mongod_var_lib_t /data
cat << END > /etc/mongod.conf
# mongod.conf generated from CloudFormation                      
logpath=/var/log/mongodb/mongod.log
logappend=true
fork=true
dbpath=/data/db
pidfilepath=/var/run/mongodb/mongod.pid
replSet=ofx
oplogSize=1024
END
chkconfig mongod on
service mongod start
sleep 20