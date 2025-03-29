#!/bin/bash
set -e

############################################
# Script: install_oozie.sh
# Description: Installs and configures Oozie 5.2.1 on top of Hadoop 3.3.6 and Hive 3.1.3
############################################

export OOZIE_VERSION=5.2.1
export HADOOP_VERSION=3.3.6
export OOZIE_HOME=/usr/local/oozie
export HADOOP_HOME=/usr/local/hadoop
export HIVE_HOME=/usr/local/hive
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HIVE_HOME/bin:$OOZIE_HOME/bin:$PATH

echo "📥 Downloading Oozie $OOZIE_VERSION..."
cd /tmp
wget https://downloads.apache.org/oozie/$OOZIE_VERSION/oozie-$OOZIE_VERSION.tar.gz
tar -xzf oozie-$OOZIE_VERSION.tar.gz
sudo mv oozie-$OOZIE_VERSION $OOZIE_HOME

echo "📁 Creating libext directory..."
mkdir -p $OOZIE_HOME/libext

echo "🔗 Copying Hadoop and Hive libraries to Oozie libext..."
cp $HADOOP_HOME/share/hadoop/common/*.jar $OOZIE_HOME/libext/
cp $HADOOP_HOME/share/hadoop/common/lib/*.jar $OOZIE_HOME/libext/
cp $HADOOP_HOME/share/hadoop/hdfs/*.jar $OOZIE_HOME/libext/
cp $HADOOP_HOME/share/hadoop/mapreduce/*.jar $OOZIE_HOME/libext/
cp $HADOOP_HOME/share/hadoop/yarn/*.jar $OOZIE_HOME/libext/
cp $HIVE_HOME/lib/hive-exec-*.jar $OOZIE_HOME/libext/
cp $HIVE_HOME/lib/libfb303-*.jar $OOZIE_HOME/libext/

echo "🧩 Copying Ext JS (required for Oozie web UI)..."
cd $OOZIE_HOME
wget https://archive.apache.org/dist/oozie/$OOZIE_VERSION/oozie-$OOZIE_VERSION.tar.gz -O oozie.tar.gz
tar -xzf oozie.tar.gz -C /tmp
cp -r /tmp/oozie-$OOZIE_VERSION/docs/ext-2.2 $OOZIE_HOME/libext/ext-2.2

echo "⚙️ Building Oozie WAR..."
cd $OOZIE_HOME
bin/oozie-setup.sh prepare-war

echo "🚀 Starting Oozie..."
bin/oozied.sh start
sleep 10

echo "🌐 Oozie UI available at: http://localhost:11000/oozie"

echo "✅ Oozie installation complete!"
