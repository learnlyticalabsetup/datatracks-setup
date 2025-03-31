#!/bin/bash
set -e

echo "📦 Downloading and Installing Sqoop 1.4.7..."
cd /opt
wget -q https://archive.apache.org/dist/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
tar -xzf sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
sudo mv sqoop-1.4.7.bin__hadoop-2.6.0 /usr/local/sqoop

echo "🔧 Setting Environment Variables for Sqoop..."
echo 'export SQOOP_HOME=/usr/local/sqoop' >> ~/.bashrc
echo 'export PATH=$SQOOP_HOME/bin:$PATH' >> ~/.bashrc
echo 'export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HIVE_HOME/lib/*:$SQOOP_HOME/lib/*' >> ~/.bashrc
source ~/.bashrc

echo "🧩 Copying MySQL Connector to Sqoop lib..."
cp /home/ubuntu/mysql-connector-j-8.0.31.jar /usr/local/sqoop/lib/

echo "🧪 Testing Sqoop Version..."
sqoop version

echo "🧾 Creating Sample Table in MySQL for Sqoop Import Test..."
mysql -u root -pX9085565r@ <<EOF
USE hive_metastore;
CREATE TABLE IF NOT EXISTS employees (id INT, name VARCHAR(50));
INSERT INTO employees VALUES (1, 'Alice'), (2, 'Bob');
EOF

echo "🚀 Running Sqoop Import from MySQL to HDFS..."
sqoop import \
--connect jdbc:mysql://localhost:3306/hive_metastore \
--username hive \
--password HivePass123! \
--table employees \
--target-dir /tmp/employees_import \
--m 1

echo "📁 Listing Imported Files in HDFS:"
hdfs dfs -ls /tmp/employees_import
hdfs dfs -cat /tmp/employees_import/part-m-00000

echo "✅ Sqoop Installation and Import Test Completed!"
