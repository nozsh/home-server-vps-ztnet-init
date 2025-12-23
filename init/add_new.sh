#!/bin/bash

docker compose down
echo

user_input_cert_email() {
  local email

  while true; do
    read -p "Enter Email for CERTBOT (SSL): " email
    if [[ -n "$email" ]]; then
      echo "$email"
      break
    fi
  done
}

user_input_domain() {
  local domain

  while true; do
    read -p "Enter domain: " domain
    if [[ -n "$domain" ]]; then
      echo "$domain"
      break
    fi
  done
}

user_input_proxy() {
  local proxy

  while true; do
    read -p "Enter proxy - <ZeroTier_IP>:APP_PORT: " proxy
    if [[ -n "$proxy" ]]; then
      echo "$proxy"
      break
    fi
  done
}

CERTBOT_EMAIL=$(user_input_cert_email)
DOMAIN=$(user_input_domain)
PROXY=$(user_input_proxy)

echo
echo "CERTBOT EMAIL: $CERTBOT_EMAIL"
echo "DOMAIN: $DOMAIN"
echo "PROXY: $PROXY"
echo

read -p "OK OR NOT (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    exit 1
fi
echo

src_site="init/nginx_conf/your-app.domain.org.conf"
dst_site="nginx/conf.d/${DOMAIN}.conf"
cp "$src_site" "$dst_site"

sed -i "s|your-app.domain.org|${DOMAIN}|g" "$dst_site"
sed -i "s|<ZeroTier_IP:APP_PORT|${PROXY}|" "$dst_site"
echo

# CERTBOT
certbot certonly --standalone --non-interactive --agree-tos --email "$CERTBOT_EMAIL" -d "$DOMAIN"
echo

# END
docker compose up -d && docker compose logs -f