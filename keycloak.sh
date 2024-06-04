#!/bin/bash

# 检查是否提供了域名参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <your-domain.com>"
    exit 1
fi

DOMAIN=$1
KEYSTORE_PASSWORD="changeit"

# 更新包列表并安装certbot
sudo apt update
sudo apt install -y certbot

# 生成Let's Encrypt证书
sudo certbot certonly --standalone -d $DOMAIN

# 将证书和私钥转换为PKCS12格式
sudo openssl pkcs12 -export -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -inkey /etc/letsencrypt/live/$DOMAIN/privkey.pem -out keycloak.p12 -name keycloak -CAfile /etc/letsencrypt/live/$DOMAIN/chain.pem -caname root -password pass:$KEYSTORE_PASSWORD

# 将PKCS12文件导入Java Keystore
keytool -importkeystore -deststorepass $KEYSTORE_PASSWORD -destkeypass $KEYSTORE_PASSWORD -destkeystore keycloak.jks -srckeystore keycloak.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASSWORD -alias keycloak

# 创建start-keycloak.sh脚本
cat <<EOL > start-keycloak.sh
#!/bin/bash
/opt/keycloak/bin/kc.sh start --https-key-store-file=/opt/keycloak/ssl/keycloak.jks --https-key-store-password=$KEYSTORE_PASSWORD --hostname=$DOMAIN
EOL

# 设置start-keycloak.sh为可执行
chmod +x start-keycloak.sh

# 创建Dockerfile
cat <<EOL > Dockerfile
FROM quay.io/keycloak/keycloak:24.0.4

USER root

# 创建SSL目录并复制文件
RUN mkdir -p /opt/keycloak/ssl
COPY keycloak.jks /opt/keycloak/ssl/keycloak.jks
COPY start-keycloak.sh /opt/keycloak/start-keycloak.sh

# 设置start-keycloak.sh为可执行
RUN chmod +x /opt/keycloak/start-keycloak.sh

USER 1000

ENTRYPOINT ["/opt/keycloak/start-keycloak.sh"]
EOL

# 构建Docker镜像
docker build -t custom-keycloak .

# 运行Docker容器
docker run -d --name ekycloak \
    -p 8443:8443 \
    -e KEYCLOAK_ADMIN=admin \
    -e KEYCLOAK_ADMIN_PASSWORD=admin \
    custom-keycloak

echo "Keycloak is running on https://$DOMAIN:8443"
