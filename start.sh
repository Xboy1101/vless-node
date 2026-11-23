#!/bin/sh
# PaaS VLESS+WS node (runs as non-root; all nginx paths under /tmp).
# The platform terminates TLS at its ingress and forwards plain HTTP to this
# container. nginx answers the platform health probe on / with 200 and
# proxies the VLESS WebSocket path to xray. xray itself listens on
# localhost only, so the probe never hits it.
# PORT: the platform sets $PORT (default 8080). UUID and WS_PATH come from env vars.
set -e
PORT="${PORT:-8080}"
UUID="${UUID:?UUID env var is required}"
WS_PATH="${WS_PATH:-/vless}"
XRAY_PORT=10000
NGX_TMP=/tmp/nginx

mkdir -p /etc/xray "$NGX_TMP/client_body" "$NGX_TMP/proxy" "$NGX_TMP/fastcgi" "$NGX_TMP/uwsgi" "$NGX_TMP/scgi"

cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": ${XRAY_PORT},
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${UUID}" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

cat > /etc/nginx/nginx.conf <<EOF
worker_processes 1;
error_log /dev/stderr warn;
pid /tmp/nginx.pid;
events { worker_connections 256; }
http {
    access_log off;
    client_body_temp_path $NGX_TMP/client_body;
    proxy_temp_path $NGX_TMP/proxy;
    fastcgi_temp_path $NGX_TMP/fastcgi;
    uwsgi_temp_path $NGX_TMP/uwsgi;
    scgi_temp_path $NGX_TMP/scgi;
    server {
        listen ${PORT};
        location = / {
            add_header Content-Type text/plain;
            return 200 'OK';
        }
        location ${WS_PATH} {
            proxy_pass http://127.0.0.1:${XRAY_PORT};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
        }
    }
}
EOF

/usr/local/bin/xray run -c /etc/xray/config.json &
exec nginx -e /dev/stderr -c /etc/nginx/nginx.conf -g 'daemon off;'
