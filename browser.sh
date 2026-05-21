cat > /mnt/user-data/outputs/browser_setup.sh << 'ENDSCRIPT'
#!/bin/bash
# ============================================
# BROWSER_SETUP.SH - Midori zamjena PaleMoon
# Pokreni: sudo bash browser_setup.sh
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && echo -e "${RED}sudo bash browser_setup.sh${NC}" && exit 1

USERNAME=${SUDO_USER:-$(who | awk '{print $1}' | grep -v root | head -1)}
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"
USER_HOME="/home/$USERNAME"

clear
echo -e "${CYAN}  ╔════════════════════════════════════╗"
echo "  ║   BROWSER SETUP - Zamjena PaleMoon  ║"
echo -e "  ╚════════════════════════════════════╝${NC}"
echo -e "${YELLOW}  PaleMoon: ~400MB RAM${NC}"
echo -e "${GREEN}  Midori:   ~85-150MB RAM${NC}\n"
sleep 2

echo -e "${CYAN}━━━ [1/5] UKLONI PALEMOON ━━━${NC}"
apt-get remove -y palemoon* 2>/dev/null && \
    echo -e "${GREEN}  ✓ PaleMoon uklonjen${NC}" || \
    echo -e "${YELLOW}  - PaleMoon nije bio instaliran${NC}"

echo -e "\n${CYAN}━━━ [2/5] INSTALIRAJ MIDORI ━━━${NC}"
apt-get update -qq
apt-get install -y midori 2>/dev/null
command -v midori &>/dev/null && \
    echo -e "${GREEN}  ✓ Midori instaliran (~85MB RAM)${NC}" || \
    { apt-get install -y netsurf-gtk 2>/dev/null
      echo -e "${GREEN}  ✓ NetSurf instaliran (backup)${NC}"; }
apt-get install -y falkon 2>/dev/null && \
    echo -e "${GREEN}  ✓ Falkon instaliran (backup ~120MB RAM)${NC}"

echo -e "\n${CYAN}━━━ [3/5] MIDORI KONFIGURACIJA ━━━${NC}"
mkdir -p $USER_HOME/.config/midori
cat > $USER_HOME/.config/midori/config << 'EOF'
[settings]
enable-plugins=false
enable-developer-extras=false
maximum-cache-size=32
remember-last-visited-pages=false
remember-last-downloaded-files=false
save-session=false
first-party-cookies-only=true
user-agent=Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0
enable-dns-prefetching=true
show-crash-dialog=false
EOF
chown -R $USERNAME:$USERNAME $USER_HOME/.config/midori
echo -e "${GREEN}  ✓ Cache 32MB, plugins off, user-agent promijenjen${NC}"

echo -e "\n${CYAN}━━━ [4/5] DNS-OVER-HTTPS ━━━${NC}"
apt-get install -y dnscrypt-proxy 2>/dev/null
if command -v dnscrypt-proxy &>/dev/null; then
    cat > /etc/dnscrypt-proxy/dnscrypt-proxy.toml << 'EOF'
server_names = ['cloudflare', 'quad9-dnscrypt-ip4-filter-pri']
listen_addresses = ['127.0.0.1:53']
require_dnssec = true
require_nolog = true
require_nofilter = true
ipv6_servers = false
block_ipv6 = true
[cache]
cache = true
cache_size = 512
EOF
    systemctl enable dnscrypt-proxy 2>/dev/null
    systemctl restart dnscrypt-proxy 2>/dev/null
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null
    echo -e "${GREEN}  ✓ DNS-over-HTTPS, DNSSEC, DNS leak zaštita${NC}"
else
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 9.9.9.9" >> /etc/resolv.conf
    echo -e "${GREEN}  ✓ Cloudflare + Quad9 DNS${NC}"
fi

echo -e "\n${CYAN}━━━ [5/5] ALIASI ━━━${NC}"
grep -q "alias browser=" $USER_HOME/.bashrc 2>/dev/null || cat >> $USER_HOME/.bashrc << 'EOF'

# Browser
alias browser='midori'
alias safebrowser='proxychains4 midori'
alias cleanbrowser='midori --private'
EOF
chown $USERNAME:$USERNAME $USER_HOME/.bashrc
echo -e "${GREEN}  ✓ browser / safebrowser / cleanbrowser${NC}"

echo -e "\n${CYAN}  ╔════════════════════════════╗"
echo "  ║   BROWSER SETUP ZAVRŠEN! ✓  ║"
echo -e "  ╚════════════════════════════╝${NC}"
echo -e "${GREEN}  Ušteda RAM-a: ~250MB!${NC}"
echo -e "${YELLOW}  Pokreni: midori${NC}"
echo -e "${YELLOW}  Tor:     proxychains4 midori${NC}"
ENDSCRIPT
echo "Done"
