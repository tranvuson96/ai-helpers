#!/usr/bin/env bash
set -e

# --- Colors for Terminal Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}  Automated Deployment: 9Router, DSH & Hermes Agent ${NC}"
echo -e "${BLUE}====================================================${NC}"

# --- 1. Parse Arguments & Environment Variables ---
ROUTER_DOMAIN="${ROUTER_DOMAIN:-router.sontv.test}"
DSH_DOMAIN="${DSH_DOMAIN:-dsh.sontv.test}"
HERMES_DOMAIN="${HERMES_DOMAIN:-hermes.sontv.test}"
SELECTED_APP="${ONLY:-all}"
INITIAL_PASSWORD="${INITIAL_PASSWORD:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --router-domain)
      ROUTER_DOMAIN="$2"
      shift 2
      ;;
    --dsh-domain)
      DSH_DOMAIN="$2"
      shift 2
      ;;
    --hermes-domain)
      HERMES_DOMAIN="$2"
      shift 2
      ;;
    --only|--app)
      SELECTED_APP="$2"
      shift 2
      ;;
    --initial-password|--password)
      INITIAL_PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./deploy.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --only APP_NAME          Select specific agent to deploy: '9router', 'dsh', 'hermes', or 'all' (default: all)"
      echo "  --router-domain DOMAIN   Domain name for 9Router (default: router.sontv.test)"
      echo "  --dsh-domain DOMAIN      Domain name for DeepSeek Harness (default: dsh.sontv.test)"
      echo "  --hermes-domain DOMAIN   Domain name for Hermes Agent (default: hermes.sontv.test)"
      echo "  --initial-password PASS  Set initial login password for 9Router"
      echo "  -h, --help               Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./deploy.sh --only hermes --hermes-domain hermes.mydomain.com"
      echo "  ./deploy.sh --only all"
      echo ""
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Normalize app selection name
RUN_9ROUTER=false
RUN_DSH=false
RUN_HERMES=false

case "$SELECTED_APP" in
  9router|router)
    RUN_9ROUTER=true
    ;;
  dsh|deepseek|deepseek-harness)
    RUN_DSH=true
    ;;
  hermes|hermes-agent)
    RUN_HERMES=true
    ;;
  all|*)
    RUN_9ROUTER=true
    RUN_DSH=true
    RUN_HERMES=true
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}[1/5] Configuration:${NC}"
echo -e "  - Selected Target(s):   ${GREEN}${SELECTED_APP}${NC}"
if [ "$RUN_9ROUTER" = true ]; then
  echo -e "  - 9Router Domain:       ${GREEN}${ROUTER_DOMAIN}${NC}"
fi
if [ "$RUN_DSH" = true ]; then
  echo -e "  - DeepSeek Harness Domain: ${GREEN}${DSH_DOMAIN}${NC}"
fi
if [ "$RUN_HERMES" = true ]; then
  echo -e "  - Hermes Agent Domain:     ${GREEN}${HERMES_DOMAIN}${NC}"
fi
echo -e "  - Project Directory:    ${GREEN}${SCRIPT_DIR}${NC}"

# --- 2. Check & Setup Environment Binaries ---
echo -e "\n${YELLOW}[2/5] Checking required tools & paths...${NC}"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Ensure PM2 is accessible
if ! command -v pm2 &> /dev/null; then
  if [ -f "$HOME/.hermes/node/bin/pm2" ]; then
    ln -sf "$HOME/.hermes/node/bin/pm2" "$HOME/.local/bin/pm2"
  fi
fi

# Ensure PNPM is accessible
if ! command -v pnpm &> /dev/null; then
  if command -v npm &> /dev/null; then
    echo -e "${BLUE}Installing pnpm globally via npm...${NC}"
    npm install -g pnpm || true
    if [ -f "$HOME/.hermes/node/bin/pnpm" ]; then
      ln -sf "$HOME/.hermes/node/bin/pnpm" "$HOME/.local/bin/pnpm"
    fi
  fi
fi

# Verify critical binaries
for cmd in node npm pnpm pm2 nginx; do
  if command -v $cmd &> /dev/null; then
    echo -e "  ✓ ${cmd} found: $(command -v $cmd)"
  else
    echo -e "  ${RED}✗ Warning: ${cmd} is not installed or not in PATH.${NC}"
  fi
done

# --- 3. Check Submodules, Install Dependencies & Build ---
echo -e "\n${YELLOW}[3/5] Checking submodules, installing dependencies and building projects...${NC}"

# Auto-initialize target submodule if empty
if [ "$RUN_9ROUTER" = true ] && [ ! -f "$SCRIPT_DIR/9router/package.json" ]; then
  echo -e "${BLUE}--> Submodule 9router empty. Running 'git submodule update --init 9router'...${NC}"
  cd "$SCRIPT_DIR" && git submodule update --init 9router || true
fi

if [ "$RUN_DSH" = true ] && [ ! -f "$SCRIPT_DIR/dsh/package.json" ]; then
  echo -e "${BLUE}--> Submodule dsh empty. Running 'git submodule update --init dsh'...${NC}"
  cd "$SCRIPT_DIR" && git submodule update --init dsh || true
fi

if [ "$RUN_HERMES" = true ] && [ ! -f "$SCRIPT_DIR/hermes/package.json" ]; then
  echo -e "${BLUE}--> Submodule hermes empty. Running 'git submodule update --init hermes'...${NC}"
  cd "$SCRIPT_DIR" && git submodule update --init hermes || true
fi

if [ "$RUN_9ROUTER" = true ]; then
  echo -e "${BLUE}--> Building 9Router...${NC}"
  cd "$SCRIPT_DIR/9router"
  if [ ! -d "node_modules" ]; then
    pnpm approve-builds --all 2>/dev/null || true
    pnpm install || pnpm install --ignore-scripts
  fi
  if [ ! -d ".next" ]; then pnpm run build; fi
  
  if [ -n "$INITIAL_PASSWORD" ]; then
    if [ -f .env ]; then
      sed -i "s/^INITIAL_PASSWORD=.*/INITIAL_PASSWORD=\"$INITIAL_PASSWORD\"/" .env 2>/dev/null || echo "INITIAL_PASSWORD=\"$INITIAL_PASSWORD\"" >> .env
    else
      echo "INITIAL_PASSWORD=\"$INITIAL_PASSWORD\"" > .env
    fi
  fi
fi

if [ "$RUN_DSH" = true ]; then
  echo -e "${BLUE}--> Installing DeepSeek Harness dependencies & building bundles...${NC}"
  cd "$SCRIPT_DIR/dsh"
  if [ ! -d "node_modules" ]; then
    pnpm approve-builds --all 2>/dev/null || true
    pnpm install || pnpm install --ignore-scripts
  fi
  pnpm run build
fi

if [ "$RUN_HERMES" = true ]; then
  echo -e "${BLUE}--> Installing Hermes Agent dependencies...${NC}"
  cd "$SCRIPT_DIR/hermes/web"
  if ! grep -q "allowedHosts" vite.config.ts 2>/dev/null; then
    sed -i '/server: {/a \    allowedHosts: true,' vite.config.ts 2>/dev/null || true
  fi
  if [ ! -d "node_modules" ]; then
    pnpm approve-builds --all 2>/dev/null || true
    pnpm install || pnpm install --ignore-scripts
  fi
fi

# --- 4. Generate Local Nginx Configurations ---
echo -e "\n${YELLOW}[4/5] Generating Nginx Virtual Host files...${NC}"

NGINX_OUT_DIR="$SCRIPT_DIR/config/nginx"
mkdir -p "$NGINX_OUT_DIR"

ACTIVE_DOMAINS=()

if [ "$RUN_9ROUTER" = true ]; then
  ROUTER_CONF="$NGINX_OUT_DIR/$ROUTER_DOMAIN.conf"
  cat <<EOF > "$ROUTER_CONF"
server {
    listen 80;
    server_name $ROUTER_DOMAIN;

    auth_basic "Restricted Access - 9Router";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:20128;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
    }
}
EOF
  ACTIVE_DOMAINS+=("$ROUTER_DOMAIN")
fi

if [ "$RUN_DSH" = true ]; then
  DSH_CONF="$NGINX_OUT_DIR/$DSH_DOMAIN.conf"
  cat <<EOF > "$DSH_CONF"
server {
    listen 80;
    server_name $DSH_DOMAIN;

    auth_basic "Restricted Access - DeepSeek Harness";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:3080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF
  ACTIVE_DOMAINS+=("$DSH_DOMAIN")
fi

if [ "$RUN_HERMES" = true ]; then
  HERMES_CONF="$NGINX_OUT_DIR/$HERMES_DOMAIN.conf"
  cat <<EOF > "$HERMES_CONF"
server {
    listen 80;
    server_name $HERMES_DOMAIN;

    auth_basic "Restricted Access - Hermes Agent";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:3090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF
  ACTIVE_DOMAINS+=("$HERMES_DOMAIN")
fi

echo -e "  ✓ Nginx configs generated in ${GREEN}$NGINX_OUT_DIR${NC}"

# Attempt copying to system Nginx if user has permissions
SUDO=""
if [ $(id -u) -ne 0 ]; then SUDO="sudo"; fi

if $SUDO -n true 2>/dev/null; then
  echo -e "${BLUE}Installing configs into /etc/nginx/sites-available/...${NC}"
  for domain in "${ACTIVE_DOMAINS[@]}"; do
    $SUDO cp "$NGINX_OUT_DIR/$domain.conf" "/etc/nginx/sites-available/$domain"
    $SUDO ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"
    if [[ "$domain" == *.test ]] || [[ "$domain" == *.local ]]; then
      if ! grep -q "$domain" /etc/hosts; then
        echo "127.0.0.1 $domain" | $SUDO tee -a /etc/hosts > /dev/null
        echo -e "  ✓ Added $domain to /etc/hosts"
      fi
    fi
  done
  $SUDO nginx -t && $SUDO systemctl reload nginx
  echo -e "  ✓ Nginx reloaded successfully."
else
  echo -e "${YELLOW}Note: Run the following commands with sudo to activate Nginx configs:${NC}"
  for domain in "${ACTIVE_DOMAINS[@]}"; do
    echo -e "  sudo cp \"$NGINX_OUT_DIR/$domain.conf\" /etc/nginx/sites-available/$domain"
    echo -e "  sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain"
  done
  echo -e "  sudo systemctl reload nginx"
fi

# --- 5. Start PM2 Processes ---
echo -e "\n${YELLOW}[5/5] Starting PM2 processes...${NC}"
cd "$SCRIPT_DIR"

export INITIAL_PASSWORD="${INITIAL_PASSWORD:-123456}"

if [ "$SELECTED_APP" = "9router" ]; then
  pm2 delete 9router 2>/dev/null || true
  ROUTER_BASE_URL="http://$ROUTER_DOMAIN" INITIAL_PASSWORD="$INITIAL_PASSWORD" pm2 start "$SCRIPT_DIR/config/ecosystem.config.js" --only 9router
elif [ "$SELECTED_APP" = "dsh" ]; then
  pm2 delete deepseek-harness 2>/dev/null || true
  pm2 start "$SCRIPT_DIR/config/ecosystem.config.js" --only deepseek-harness
elif [ "$SELECTED_APP" = "hermes" ]; then
  pm2 delete hermes-agent 2>/dev/null || true
  pm2 start "$SCRIPT_DIR/config/ecosystem.config.js" --only hermes-agent
else
  pm2 delete 9router deepseek-harness hermes-agent 2>/dev/null || true
  ROUTER_BASE_URL="http://$ROUTER_DOMAIN" INITIAL_PASSWORD="$INITIAL_PASSWORD" pm2 start "$SCRIPT_DIR/config/ecosystem.config.js"
fi

pm2 save

# --- Completion Summary ---
echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}  ✓ Deployment Completed Successfully!             ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Services running on PM2:"
pm2 status
echo ""
echo -e "Access URLs:"
if [ "$RUN_9ROUTER" = true ]; then
  echo -e "  - 9Router:          ${GREEN}http://${ROUTER_DOMAIN}${NC}"
fi
if [ "$RUN_DSH" = true ]; then
  echo -e "  - DeepSeek Harness: ${GREEN}http://${DSH_DOMAIN}${NC}"
fi
if [ "$RUN_HERMES" = true ]; then
  echo -e "  - Hermes Agent:     ${GREEN}http://${HERMES_DOMAIN}${NC}"
fi
echo -e "Basic Auth Credentials:"
echo -e "  - User: ${YELLOW}admin${NC}"
echo -e "  - Pass: ${YELLOW}admin${NC} (or contents of /etc/nginx/.htpasswd)"
echo ""
