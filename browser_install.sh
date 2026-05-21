#!/bin/bash
# ============================================
# SKRIPTA 1: BROWSER - Midori instalacija
# i optimizacija + privacy podesavanja
# Pokreni: sudo bash browser_install.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash browser_install.sh${NC}"
    exit 1
fi

# Nađi korisnika
USERNAME=${SUDO_USER:-$(who | awk '{print $1}' | grep -v root | head -1)}
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"
USER_HOME="/home/$USERNAME"

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║   BROWSER INSTALL + PRIVACY SETUP     ║"
echo "  ║   Midori - bajo 150MB RAM              ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

# ================================================
echo -e "${CYAN}[1/5] Instalacija Midori browsera...${NC}"
# ================================================

apt-get update -qq
apt-get install -y midori 2>/dev/null

# Ako Midori nije dostupan, probaj Falkon
if ! command -v midori &>/dev/null; then
    echo -e "${YELLOW}  Midori nije dostupan, instaliram Falkon...${NC}"
    apt-get install -y falkon 2>/dev/null
fi

# Instaliraj i uBlock Origin za Firefox/Palemoon ako treba
apt-get install -y \
    firefox-esr \
    2>/dev/null

echo -e "${GREEN}  ✓ Browser instaliran${NC}"

# ================================================
echo -e "\n${CYAN}[2/5] Ukloni PaleMoon cache i historiju...${NC}"
# ================================================

# Očisti PaleMoon
find $USER_HOME -path "*/Pale Moon/*/cache2" -type d \
    -exec rm -rf {}/* \; 2>/dev/null
find $USER_HOME -path "*/Pale Moon/*/cache" -type d \
    -exec rm -rf {}/* \; 2>/dev/null
find $USER_HOME -name "places.sqlite" \
    -path "*/Pale Moon/*" 2>/dev/null | while read db; do
    sqlite3 "$db" \
        "DELETE FROM moz_historyvisits; \
         DELETE FROM moz_inputhistory;" 2>/dev/null
done

echo -e "${GREEN}  ✓ PaleMoon cache/historija obrisana${NC}"

# ================================================
echo -e "\n${CYAN}[3/5] PaleMoon about:config optimizacija...${NC}"
# ================================================

# Nađi PaleMoon profil
PALE_PROFILE=$(find $USER_HOME -name "prefs.js" \
    -path "*/Pale Moon/*" 2>/dev/null | head -1)

if [ -n "$PALE_PROFILE" ]; then
    cat >> "$PALE_PROFILE" << 'EOF'
/* RAM optimizacije */
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 65536);
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.sessionstore.max_windows_undo", 0);
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.maxrequests", 8);
user_pref("nglayout.initialpaint.delay", 0);

/* Privacy - fingerprint zaštita */
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("geo.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("webgl.disabled", true);
user_pref("dom.battery.enabled", false);
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.spoofSource", true);
user_pref("browser.send_pings", false);
user_pref("browser.safebrowsing.enabled", false);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("dom.webrtc.enabled", false);

/* User Agent spoof - izgleda kao Windows */
user_pref("general.useragent.override",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0");

/* Canvas fingerprint blokada */
user_pref("canvas.poisondata", true);
EOF
    echo -e "${GREEN}  ✓ PaleMoon privacy konfigurisan${NC}"
    echo -e "${GREEN}  ✓ User-Agent spoofovan (izgleda kao Windows)${NC}"
    echo -e "${GREEN}  ✓ WebRTC onemogućen${NC}"
    echo -e "${GREEN}  ✓ Canvas fingerprint blokiran${NC}"
fi

# ================================================
echo -e "\n${CYAN}[4/5] Midori privacy konfiguracija...${NC}"
# ================================================

mkdir -p $USER_HOME/.config/midori

cat > $USER_HOME/.config/midori/config << 'EOF'
[settings]
# Lažni User-Agent
user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
# Blokira trackere
block-ads=true
# Ne sprema historiju
maximum-history-age=0
# Ne sprema lozinke
remember-passwords=false
# Onemogući geolokaciju
enable-geolocation=false
# Minimalan RAM
cache-size=32
EOF

chown -R $USERNAME:$USERNAME $USER_HOME/.config/midori 2>/dev/null
echo -e "${GREEN}  ✓ Midori konfigurisan${NC}"
echo -e "${GREEN}  ✓ User-Agent spoofovan${NC}"
echo -e "${GREEN}  ✓ Cache smanjen na 32MB${NC}"

# ================================================
echo -e "\n${CYAN}[5/5] Napravi skriptu za pokretanje browsera...${NC}"
# ================================================

# Skripta koja pokr browser kroz proxychains ako je dostupan
cat > $USER_HOME/pokreni_browser.sh << 'BROWSERSCRIPT'
#!/bin/bash
# Pokreni browser sa privatnim modovima

BROWSER=""
command -v midori &>/dev/null && BROWSER="midori"
command -v falkon &>/dev/null && BROWSER="falkon"
command -v palemoon &>/dev/null && BROWSER="palemoon"

if command -v proxychains4 &>/dev/null && \
   [ -f /etc/proxychains4.conf ]; then
    echo "Pokretanje kroz proxychains..."
    proxychains4 $BROWSER &
else
    $BROWSER &
fi
BROWSERSCRIPT

chmod +x $USER_HOME/pokreni_browser.sh
chown $USERNAME:$USERNAME $USER_HOME/pokreni_browser.sh

echo -e "${GREEN}  ✓ Browser launcher skripta napravljena${NC}"
echo -e "${GREEN}  ✓ ~/pokreni_browser.sh${NC}"

echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║       BROWSER SETUP ZAVRŠEN! ✓         ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Pokreni browser:${NC}"
echo -e "${GREEN}  bash ~/pokreni_browser.sh${NC}"
echo -e "${YELLOW}  Ili direktno:${NC}"
echo -e "${GREEN}  midori${NC}"
echo ""
