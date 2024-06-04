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
