FROM alpine:latest

RUN apk add --no-cache nginx curl unzip ca-certificates \
    && curl -fsSL -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v26.11.9/Xray-linux-64.zip \
    && unzip -o /tmp/xray.zip -d /usr/local/bin/ \
    && rm /tmp/xray.zip \
    && mkdir -p /run/nginx /etc/xray

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
