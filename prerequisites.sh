#!/bin/bash
set -e

echo "🔧 Updating package list..."
sudo apt update

echo "📦 Installing required packages..."
sudo apt install -y \
    openjdk-8-jdk \
    ssh \
    rsync \
    net-tools \
    mysql-server \
    libmysql-java \
    wget \
    curl \
    vim \
    unzip \
    lsof

echo "🔐 Starting MySQL service..."
sudo service mysql start

echo "🔐 Securing MySQL (set root password to: X9085565r@)..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'X9085565r@';
FLUSH PRIVILEGES;
EOF

echo "✅ MySQL root password set."

echo "🔽 Downloading MySQL JDBC Connector..."
wget -nc https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.31/mysql-connector-java-8.0.31.jar -O /home/ubuntu/mysql-connector-j-8.0.31.jar
chmod 644 /home/ubuntu/mysql-connector-j-8.0.31.jar

echo "📂 Creating base directories for Hadoop and Hive..."
cd /usr/local/
if [ ! -d "hadoop" ]; then
    echo "📦 Downloading Hadoop 3.3.6..."
    wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
    tar -xvzf hadoop-3.3.6.tar.gz
    sudo mv hadoop-3.3.6 hadoop
fi

if [ ! -d "hive" ]; then
    echo "📦 Downloading Hive 3.1.3..."
    wget https://downloads.apache.org/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz
    tar -xvzf apache-hive-3.1.3-bin.tar.gz
    sudo mv apache-hive-3.1.3-bin hive
fi

echo "🔓 Configuring SSH keys..."
[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo -e "Host localhost\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
chmod 600 ~/.ssh/config
sudo service ssh restart

echo "🧪 Verifying Java version..."
java -version

echo "✅ Prerequisites setup complete."
