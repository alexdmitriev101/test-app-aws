#!/bin/bash
set -e

yum update -y

amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

sleep 10

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

mkdir -p /home/ec2-user/html

cat <<'EOF' > /home/ec2-user/docker-compose.yml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped
volumes:
  html:
EOF

cat <<'EOF' > /home/ec2-user/html/index.html
<!DOCTYPE html>
<html><body>
  <h1>Hello from Alex via Nginx + Docker!</h1>
  <p>Served via EC2 + CloudFront</p>
</body></html>
EOF

chown -R ec2-user:ec2-user /home/ec2-user

cd /home/ec2-user
sudo -u ec2-user /usr/local/bin/docker-compose up -d

echo "Nginx started successfully"