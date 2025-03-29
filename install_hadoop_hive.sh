#!/bin/bash
set -e

########################################
# Script: install_hadoop_hive2.sh
# Final: Hadoop 3.3.6 + Hive 3.1.3 setup (Java 8)
########################################

# === ENV Setup ===
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export HADOOP_HOME="/usr/local/hadoop"
export HIVE_HOME="/usr/local/hive"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$PATH"

echo "💻 Exporting environment variables..."
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc
echo "export HADOOP_HOME=$HADOOP_HOME" >> ~/.bashrc
echo "export HIVE_HOME=$HIVE_HOME" >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$PATH' >> ~/.bashrc
echo "export HADOOP_CONF_DIR=$HADOOP_CONF_DIR" >> ~/.bashrc
source ~/.bashrc

MYSQL_ROOT_PASS="X9085565r@"
MYSQL_JDBC_JAR="/home/ubuntu/mysql-connector-j-8.0.31.jar"
NAMENODE_DIR="$HADOOP_HOME/hdfs/namenode"
DATANODE_DIR="$HADOOP_HOME/hdfs/datanode"

# === Java 8 Check ===
echo "🥪 Checking Java 8..."
java -version 2>&1 | grep "1.8" || sudo apt update && sudo apt install openjdk-8-jdk -y

# === SSH Setup ===
echo "🔐 Configuring SSH for localhost..."
[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo -e "Host localhost\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
chmod 600 ~/.ssh/config
sudo service ssh restart

# === Cleanup Previous Services and Ports ===
echo "🧹 Cleaning old processes and ports..."
pkill -f NameNode || true
pkill -f DataNode || true
pkill -f ResourceManager || true
pkill -f NodeManager || true
pkill -f SecondaryNameNode || true
lsof -ti :9870 | xargs -r sudo kill -9
for port in 9864 8088 10000 9083; do lsof -ti :$port | xargs -r sudo kill -9; done

# === Cleanup Hadoop Directories ===
echo "🪜 Cleaning Hadoop data & logs..."
sudo rm -rf $HADOOP_HOME/hdfs $HADOOP_HOME/logs/* /tmp/hadoop-* ~/.hadoop/
sudo mkdir -p $NAMENODE_DIR $DATANODE_DIR
sudo chown -R $USER:$USER $HADOOP_HOME

# === Hadoop Config ===
echo "⚙️ Generating Hadoop configs..."
cat > $HADOOP_CONF_DIR/core-site.xml <<EOF
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOF

cat > $HADOOP_CONF_DIR/hdfs-site.xml <<EOF
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file://$NAMENODE_DIR</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file://$DATANODE_DIR</value>
  </property>
</configuration>
EOF

cat > $HADOOP_CONF_DIR/yarn-site.xml <<EOF
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOF

cat > $HADOOP_CONF_DIR/mapred-site.xml <<EOF
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF

sed -i "/^export JAVA_HOME/c\export JAVA_HOME=$JAVA_HOME" $HADOOP_CONF_DIR/hadoop-env.sh

# === Format HDFS ===
echo "🧱 Formatting HDFS..."
hdfs namenode -format -force

# === Export Daemon Users ===
export HDFS_NAMENODE_USER=$USER
export HDFS_DATANODE_USER=$USER
export HDFS_SECONDARYNAMENODE_USER=$USER
export YARN_RESOURCEMANAGER_USER=$USER
export YARN_NODEMANAGER_USER=$USER

# === Start Hadoop ===
echo "🚀 Starting Hadoop Services..."
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
sleep 10

echo "📋 Checking Hadoop daemons..."
jps

# === HDFS Directories ===
echo "📁 Creating Hive HDFS directories..."
hdfs dfs -mkdir -p /user/$USER
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod -R 777 /user/hive/warehouse

# === Cleanup Hive ===
echo "🧹 Resetting Hive setup..."
pkill -f "hive.*metastore" || true
pkill -f "hive.*hiveserver2" || true
rm -rf /tmp/hive/* $HIVE_HOME/logs/*

# === MySQL Hive Metastore Setup ===
echo "🛠️ Configuring Hive Metastore DB..."
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS hive_metastore;
CREATE DATABASE hive_metastore;
DROP USER IF EXISTS 'hive'@'localhost';
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'HivePass123!';
GRANT ALL PRIVILEGES ON hive_metastore.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
EOF

cp "$MYSQL_JDBC_JAR" "$HIVE_HOME/lib/"

# === Hive Config ===
echo "⚙️ Setting hive-site.xml..."
mkdir -p $HIVE_HOME/conf
cat > $HIVE_HOME/conf/hive-site.xml <<EOF
<configuration>
  <property>
    <name>hive.server2.transport.mode</name>
    <value>binary</value>
  </property>
  <property>
    <name>hive.server2.thrift.port</name>
    <value>10000</value>
  </property>
  <property>
    <name>hive.server2.thrift.bind.host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>hive.server2.authentication</name>
    <value>NONE</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://localhost:3306/hive_metastore?createDatabaseIfNotExist=true</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>com.mysql.cj.jdbc.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>HivePass123!</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
  </property>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://localhost:9083</value>
  </property>
</configuration>
EOF

# === Set HEAP Size ===
echo "🔧 Setting HEAP size..."
export HADOOP_HEAPSIZE=1024
export HIVE_SERVER2_HEAPSIZE=1024

# === Initialize Hive Schema ===
echo "🧱 Initializing Hive Schema..."
$HIVE_HOME/bin/schematool -initSchema -dbType mysql --verbose

# === Start Hive Services ===
echo "🚀 Starting Hive Services..."
nohup $HIVE_HOME/bin/hive --service metastore > ~/hive_metastore.log 2>&1 &
sleep 10
if netstat -tuln | grep -q 9083; then
  echo "✅ Hive Metastore running on port 9083"
else
  echo "❌ Hive Metastore failed to start. Check ~/hive_metastore.log"
  exit 1
fi

nohup $HIVE_HOME/bin/hive --service hiveserver2 > ~/hive_server2.log 2>&1 &
sleep 15
if netstat -tuln | grep -q 10000; then
  echo "✅ HiveServer2 running on port 10000"
else
  echo "❌ HiveServer2 failed to start. Check ~/hive_server2.log"
  exit 1
fi

# === Validate Hive ===
echo "📋 Validating Hive CLI..."
hive -e "SHOW DATABASES;"

echo "📋 Validating Beeline..."
beeline -u jdbc:hive2://localhost:10000 -n $USER -e "SHOW TABLES;"

# === Sample Table ===
echo "📊 Creating demo table..."
hive -e "
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE test_table (id INT, name STRING);
INSERT INTO test_table VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM test_table;
"

echo "✅ Hadoop + Hive installation successful!"
