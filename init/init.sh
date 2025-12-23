#!/bin/bash

### Colors
NC='\033[0m'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BMAGENTA='\033[1;35m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

CR() { printf "${RED}%s${NC}" "$*"; }        # red
CG() { printf "${GREEN}%s${NC}" "$*"; }      # green
CY() { printf "${YELLOW}%s${NC}" "$*"; }     # yellow
CB() { printf "${BLUE}%s${NC}" "$*"; }       # blue
CM() { printf "${MAGENTA}%s${NC}" "$*"; }    # magenta
CC() { printf "${CYAN}%s${NC}" "$*"; }       # cyan
CW() { printf "${WHITE}%s${NC}" "$*"; }      # white

CRB() { printf "${BRED}%s${NC}" "$*"; }      # bold red
CGB() { printf "${BGREEN}%s${NC}" "$*"; }    # bold green
CYB() { printf "${BYELLOW}%s${NC}" "$*"; }   # bold yellow
CBB() { printf "${BBLUE}%s${NC}" "$*"; }     # bold blue
CMB() { printf "${BMAGENTA}%s${NC}" "$*"; }  # bold magenta
CCB() { printf "${BCYAN}%s${NC}" "$*"; }     # bold cyan
CWB() { printf "${BWHITE}%s${NC}" "$*"; }    # bold white
### Colors

#############################################################################
echo

### USER INPUT ###
user_input_ip() {
  local ip

  while true; do
    read -p "$(CCB Enter VPS IPv4:) " ip
    if [[ -n "$ip" ]]; then
      echo "$ip"
      break
    fi
  done
}

user_input_cert_email() {
  local email

  while true; do
    read -p "$(CMB Enter Email for CERTBOT \(SSL\):) " email
    if [[ -n "$email" ]]; then
      echo "$email"
      break
    fi
  done
}

user_input_domains() {
  local domains=()
  local domain
  local i=1
  
  # First (panel) domain
  while true; do
    read -p "$(CGB Enter domain) $(CYB \(ZTNet Panel-WebUI,) $(CRB required)$(CYB \))$(CGB :) " domain
    if [[ -n "$domain" ]]; then
      domains+=("$domain")
      break
    fi
  done
  
  # Apps domains
  while true; do
    read -p "$(CGB Enter domain app) #$i $(CYB \(or Enter to continue\))$(CGB :) " domain
    if [[ -z "$domain" ]]; then
        break
    fi
    domains+=("$domain")
    i=$((i+1))
  done
  
  echo "${domains[@]}"
}

VPS_IP=$(user_input_ip)
CERTBOT_EMAIL=$(user_input_cert_email)
DOMAINS=($(user_input_domains))
PANEL_DOMAIN=${DOMAINS[0]}

echo
echo "$(CCB === VPS IP ===)"
echo $VPS_IP
echo "$(CMB === Certbot Email ===)"
echo $CERTBOT_EMAIL
echo "$(CGB === Panel Domain ===)"
echo $PANEL_DOMAIN
echo "$(CYB === App Domains ===)"
echo "${DOMAINS[@]:1}"
echo
read -p "OK OR NOT (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    exit 1
fi
echo


### RANDOM ###
POSTGRES_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
NEXTAUTH_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)


### ZTNet docker-compose.yml ###
wget -O docker-compose.yml https://raw.githubusercontent.com/sinamics/ztnet/main/docker-compose.yml

# IP replace (DEBUG)
sed -i "s|http://localhost:3000|http://${VPS_IP}:3000|" docker-compose.yml

# Panel domain add
sed -i 's/^\([[:space:]]*\)\(NEXTAUTH_URL:.*\)$/\1# \2/' docker-compose.yml
sed -i '/#[[:space:]]*NEXTAUTH_URL:/a\      NEXTAUTH_URL: "https://'"${PANEL_DOMAIN}"'"' docker-compose.yml

# Postgres password
sed -i "s/^\([[:space:]]*POSTGRES_PASSWORD:\).*/\1 ${POSTGRES_PASS}/" docker-compose.yml

# NEXTAUTH_SECRET secret
sed -i "s/^\([[:space:]]*NEXTAUTH_SECRET:\).*/\1 \"${NEXTAUTH_SECRET}\"/" docker-compose.yml

# NGINX docker
sed -i '/^[[:space:]]*- zerotier$/{
a\

r init/conf/nginx_docker

a\

}' docker-compose.yml

# ZeroTier ports
sed -i '/"9993:9993\/udp"/{
a\      - "80:80"
a\      - "443:443"
}' docker-compose.yml


### NGINX ###
mkdir -p nginx/conf.d

src_panel="init/nginx_conf/panel-ztnet.domain.org.conf"
dst_panel="nginx/conf.d/${PANEL_DOMAIN}.conf"

cp "$src_panel" "$dst_panel"
sed -i "s|ztnet-panel.domain.org|${PANEL_DOMAIN}|g" "$dst_panel"

for i in "${!DOMAINS[@]}"; do
  if [ "$i" -eq 0 ]; then
    continue  # skip first domain (panel)
  fi

  site_domain=${DOMAINS[$i]}
  src_site="init/nginx_conf/your-app.domain.org.conf"
  dst_site="nginx/conf.d/${site_domain}.conf"

  cp "$src_site" "$dst_site"
  sed -i "s|your-app.domain.org|${site_domain}|g" "$dst_site"
done
echo


### CERTBOT ###
apt install certbot -y
for domain in "${DOMAINS[@]}"; do
  echo "SSL for $domain"
  certbot certonly --standalone --non-interactive --agree-tos --email "$CERTBOT_EMAIL" -d "$domain"
done

ls /etc/letsencrypt/live/


### START ###
docker compose up -d
echo


### LOG ###
# clear
echo "=== === === DONE === === ==="
echo "Panel URL: https://${PANEL_DOMAIN}"
echo
docker compose logs -f