ubuntu@ip-172-31-36-189:~$ cat install_hadoop_hive2.sh 
#!/bin/bash
set -e

########################################
# Script: install_hadoop_hive.sh (Java 8 compatible)
# Purpose: Clean install Hadoop 3.3.6 + Hive 3.1.3 with Java 8 compatibility
########################################

# === Set environment ===
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export HADOOP_HOME="/usr/local/hadoop"
export HIVE_HOME="/usr/local/hive"
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$PATH"
HDFS_USER="ubuntu"
NAMENODE_DIR="$HADOOP_HOME/hdfs/namenode"
DATANODE_DIR="$HADOOP_HOME/hdfs/datanode"
MYSQL_ROOT_PASS="X9085565r@"
MYSQL_JDBC_JAR="/home/ubuntu/mysql-connector-j-8.0.31.jar"

# === Ensure Java 8 is installed ===
echo "\n🧪 Checking for Java 8..."
if ! java -version 2>&1 | grep -q "1.8"; then
  echo "Installing OpenJDK 8..."
  sudo apt update
  sudo apt install openjdk-8-jdk -y
fi

# === Cleanup Hadoop ===
echo "\n🧹 Cleaning previous Hadoop installation..."
sudo $HADOOP_HOME/sbin/stop-dfs.sh || true
sudo $HADOOP_HOME/sbin/stop-yarn.sh || true
pkill -f NameNode || true
pkill -f DataNode || true
pkill -f ResourceManager || true
pkill -f NodeManager || true
sudo rm -rf $HADOOP_HOME/hdfs $HADOOP_HOME/logs/* /tmp/hadoop-* ~/.hadoop/
sudo mkdir -p $NAMENODE_DIR $DATANODE_DIR
sudo chown -R $USER:$USER $HADOOP_HOME

# === Hadoop XML Configs ===
echo "\n⚙️ Generating Hadoop configs..."
cat > $HADOOP_HOME/etc/hadoop/core-site.xml <<EOF
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOF

cat > $HADOOP_HOME/etc/hadoop/hdfs-site.xml <<EOF
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

cat > $HADOOP_HOME/etc/hadoop/yarn-site.xml <<EOF
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOF

cat > $HADOOP_HOME/etc/hadoop/mapred-site.xml <<EOF
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF

sed -i "/^export JAVA_HOME/c\export JAVA_HOME=$JAVA_HOME" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# === Format and Start Hadoop ===
echo "\n🧱 Formatting HDFS..."
hdfs namenode -format -force

export HDFS_NAMENODE_USER=$USER
export HDFS_DATANODE_USER=$USER
export HDFS_SECONDARYNAMENODE_USER=$USER
export YARN_RESOURCEMANAGER_USER=$USER
export YARN_NODEMANAGER_USER=$USER

echo "\n🚀 Starting HDFS and YARN..."
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
sleep 5

# === Verify Hadoop ===
echo "\n📋 Verifying Hadoop Daemons..."
jps | grep -E "NameNode|DataNode|SecondaryNameNode|ResourceManager|NodeManager"

# === Create HDFS Directories ===
echo "\n📁 Creating user and warehouse dirs in HDFS..."
hdfs dfs -mkdir -p /user/$USER
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod -R 777 /user/hive/warehouse

# === Cleanup Hive ===
echo "\n🧹 Cleaning previous Hive setup..."
pkill -f "hive.*metastore" || true
pkill -f "hive.*hiveserver2" || true
sudo rm -rf $HIVE_HOME/logs/*
sudo rm -rf /tmp/hive/*

# === MySQL Setup ===
echo "\n🛠️ Configuring Hive Metastore in MySQL..."
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS hive_metastore;
CREATE DATABASE hive_metastore;
DROP USER IF EXISTS 'hive'@'localhost';
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'HivePass123!';
GRANT ALL PRIVILEGES ON hive_metastore.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
EOF

cp "$MYSQL_JDBC_JAR" "$HIVE_HOME/lib/"

# === Configure hive-site.xml ===
echo "\n⚙️ Configuring Hive..."
mkdir -p $HIVE_HOME/conf
cat > $HIVE_HOME/conf/hive-site.xml <<EOF
<configuration>
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

# === Init Schema ===
echo "\n🧱 Initializing Hive schema..."
$HIVE_HOME/bin/schematool -initSchema -dbType mysql || true

# === Start Hive ===
echo "\n🚀 Starting Hive Metastore & HiveServer2..."
nohup $HIVE_HOME/bin/hive --service metastore > ~/hive_metastore.log 2>&1 &
sleep 10
nohup $HIVE_HOME/bin/hive --service hiveserver2 > ~/hive_server2.log 2>&1 &
sleep 15

# === Verify Hive ===
echo "\n📋 Verifying Hive CLI..."
hive -e "SHOW DATABASES;"

beeline -u jdbc:hive2://localhost:10000 -n $USER -e "SHOW TABLES;"

# === Sample Table ===
echo "\n📊 Creating demo table..."
hive -e "
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE test_table (id INT, name STRING);
INSERT INTO test_table VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM test_table;
"

echo "\n✅ Hadoop and Hive (Java 8) setup complete. Ready to use!"
