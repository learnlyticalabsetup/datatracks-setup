#!/bin/bash
set -e

echo "🔧 Installing dependencies for Hue 4.10.0..."
sudo apt update
sudo apt install -y \
  build-essential python3-dev python3-pip python3-venv \
  libffi-dev libssl-dev libgmp3-dev libkrb5-dev \
  libsasl2-dev libldap2-dev libsqlite3-dev \
  libmysqlclient-dev libxml2-dev libxslt1-dev \
  npm nodejs git maven

echo "📁 Cloning Hue source code..."
cd /usr/local
sudo git clone https://github.com/cloudera/hue.git
cd hue
sudo git checkout release-4.10.0
sudo chown -R $USER:$USER .

echo "🏗 Building Hue..."
make apps

echo "⚙️ Configuring hue.ini..."
cp desktop/conf/hue.ini desktop/conf/hue.ini.bak

cat <<EOF > desktop/conf/hue.ini
[desktop]
secret_key=mysupersecretkey
http_host=0.0.0.0
http_port=8888
time_zone=UTC

[hadoop]
hdfs_url=hdfs://localhost:9000
webhdfs_url=http://localhost:9870/webhdfs/v1

[beeswax]
hive_server_host=localhost
hive_server_port=10000

[oozie]
oozie_url=http://localhost:11000/oozie
EOF

echo "🚀 Starting Hue in background on port 8888..."
nohup build/env/bin/hue runserver 0.0.0.0:8888 > ~/hue.log 2>&1 &

echo "✅ Hue 4.10.0 installed and running at http://<your-ip>:8888"
