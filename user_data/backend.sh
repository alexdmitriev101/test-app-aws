#!/bin/bash
set -e

yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

sleep 10

mkdir -p /home/ec2-user/app
chown -R ec2-user:ec2-user /home/ec2-user

# app.py
cat <<'EOF' > /home/ec2-user/app/app.py
from flask import Flask, jsonify
import os
import psycopg2

app = Flask(__name__)

def get_db():
    return psycopg2.connect(os.environ['DATABASE_URL'])

@app.route('/api/health')
def health():
    try:
        conn = get_db()
        conn.close()
        return jsonify({"status": "ok", "db": "connected", "env": "${local}"})
    except Exception as e:
        return jsonify({"status": "error", "db": str(e)}), 500

@app.route('/api/data')
def data():
    return jsonify({"message": "Hello from backend!", "env": "${local}"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# docker-compose.yml
cat <<EOF > /home/ec2-user/docker-compose.yml
version: '3.8'
services:
  api:
    image: python:3.11-slim
    ports:
      - "5000:5000"
    environment:
      - DATABASE_URL=postgresql://app:${DB_PASSWORD}@${DB_HOST}:5432/appdb
    volumes:
      - ./app:/app
    working_dir: /app
    command: bash -c "pip install flask psycopg2-binary && python app.py"
    restart: unless-stopped
EOF

# Запуск
cd /home/ec2-user
sudo -u ec2-user /usr/local/bin/docker-compose up -d

echo "Backend started on port 5000"