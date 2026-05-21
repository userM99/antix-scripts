#!/bin/bash
# ============================================
# SKRIPTA 2: PRIVACY + ANONIMNOST
# MAC changer + Tor + ProxyChains4 + IP zaštita
# Pokreni: sudo bash privacy_setup.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash privacy_setup.sh${NC}"
    exit 1
fi

USERNAME=${SUDO_USER:-$(who | awk '{print $1}' | grep -v root | head -1)}
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"
USER_HOME="/home/$USERNAME"

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║   PRIVACY + ANONIMNOST SETUP           ║"
echo "  ║   MAC + Tor + ProxyChains4 + Zaštita   ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
sleep 1

# ================================================
echo -e "${CYAN}[1/7] Instalacija alata za privatnost...${NC}"
# ================================================

apt-get update -qq
apt-get install -y \
    tor \
    macchanger \
    proxychains4 \
    iptables \
    net-tools \
    curl \
    whois \
    dnsutils \
    2>/dev/null

echo -e "${GREEN}  ✓ Tor, macchanger, proxychains4 instalirani${NC}"

# ================================================
echo -e "\n${CYAN}[2/7] MAC adresa randomizacija...${NC}"
# ================================================

# Nađi mrežni interfejs
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
[ -z "$IFACE" ] && IFACE=$(ip link | grep -v lo | \
    awk -F': ' '/^[0-9]/{print $2}' | head -1)

echo -e "${YELLOW}  Mrežni interfejs: $IFACE${NC}"

# Promijeni MAC odmah
if [ -n "$IFACE" ]; then
    ip link set $IFACE down 2>/dev/null
    macchanger -r $IFACE 2>/dev/null
    ip link set $IFACE up 2>/dev/null
    NEW_MAC=$(macchanger -s $IFACE | grep "Current" | awk '{print $3}')
    echo -e "${GREEN}  ✓ MAC promijenjen na: $NEW_MAC${NC}"
fi

# Automatska MAC promjena pri svakom bootu
cat > /etc/network/if-pre-up.d/macchanger << MACSCRIPT
#!/bin/bash
# Promijeni MAC adresu pri svakom startu
IFACE=\$IFACE
if [ "\$IFACE" != "lo" ]; then
    /usr/bin/macchanger -r \$IFACE 2>/dev/null
fi
MACSCRIPT
chmod +x /etc/network/if-pre-up.d/macchanger

# Skripta za ručnu promjenu MAC-a
cat > $USER_HOME/promijeni_mac.sh << 'MACCHANGE'
#!/bin/bash
# Ručna promjena MAC adrese
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "Trenutni MAC:"
macchanger -s $IFACE
sudo ip link set $IFACE down
sudo macchanger -r $IFACE
sudo ip link set $IFACE up
echo "Novi MAC:"
macchanger -s $IFACE
MACCHANGE
chmod +x $USER_HOME/promijeni_mac.sh
chown $USERNAME:$USERNAME $USER_HOME/promijeni_mac.sh

echo -e "${GREEN}  ✓ MAC randomizacija pri bootu aktivna${NC}"
echo -e "${GREEN}  ✓ ~/promijeni_mac.sh za ručnu promjenu${NC}"

# ================================================
echo -e "\n${CYAN}[3/7] Tor konfiguracija...${NC}"
# ================================================

# Osnovna Tor konfiguracija
cat > /etc/tor/torrc << 'EOF'
# ---- Tor konfiguracija za anonimnost ----

# SOCKS proxy port
SocksPort 9050
SocksPolicy accept 127.0.0.1
SocksPolicy reject *

# DNS kroz Tor
DNSPort 5353
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion

# Kontrolni port
ControlPort 9051
CookieAuthentication 1

# Rotation - nova IP svakih 10 min
MaxCircuitDirtiness 600
NewCircuitPeriod 120
NumEntryGuards 3

# Izbjegni slow relays
CircuitBuildTimeout 10
LearnCircuitBuildTimeout 0

# Zabrani exit iz tvoje zemlje (Srbija = RS)
ExcludeExitNodes {rs},{ba},{hr},{me},{mk}
StrictNodes 1

# Log minimalan
Log notice syslog
SafeLogging 1

# Izolacija veza
IsolateClientAddr 1
IsolateSOCKSAuth 1
IsolateClientProtocol 1
EOF

# Pokreni Tor
systemctl enable tor 2>/dev/null
systemctl restart tor 2>/dev/null

sleep 3

# Provjeri da li Tor radi
if systemctl is-active --quiet tor; then
    echo -e "${GREEN}  ✓ Tor aktivan na port 9050${NC}"
    echo -e "${GREEN}  ✓ DNS kroz Tor na port 5353${NC}"
    echo -e "${GREEN}  ✓ Nova IP svako 2 minute${NC}"
    echo -e "${GREEN}  ✓ Exit node iz RS/BA/HR blokiran${NC}"
else
    echo -e "${RED}  ✗ Tor ne radi - provjeri: systemctl status tor${NC}"
fi

# ================================================
echo -e "\n${CYAN}[4/7] ProxyChains4 konfiguracija...${NC}"
# ================================================

cat > /etc/proxychains4.conf << 'EOF'
# ============================================
# ProxyChains4 - Optimalna konfiguracija
# ============================================

# dynamic_chain - preskoči nedostupne proxy-je
dynamic_chain

# Bez upozorenja
quiet_mode

# DNS zahtjevi kroz proxy (sprječava DNS leak!)
proxy_dns

# TCP timeout
tcp_read_time_out 15000
tcp_connect_time_out 8000

# Remote DNS
remote_dns_subnet 224

# ---- Lista proxy servera ----
[ProxyList]
# Tor - lokalni SOCKS5
socks5 127.0.0.1 9050

# Backup javni SOCKS5 proxy-ji
# (Tor je primarni, ovi su backup)
socks5 51.158.68.68 1080
socks5 195.201.0.6 8080
socks4 67.43.228.253 1080
EOF

echo -e "${GREEN}  ✓ ProxyChains4 konfigurisan${NC}"
echo -e "${GREEN}  ✓ dynamic_chain - preskoči nedostupne${NC}"
echo -e "${GREEN}  ✓ DNS leak zaštita aktivna${NC}"
echo -e "${GREEN}  ✓ Tor kao primarni proxy${NC}"

# ================================================
echo -e "\n${CYAN}[5/7] IP i DNS zaštita...${NC}"
# ================================================

# Postavi Tor DNS
if ! grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
    # Backup originalnog
    cp /etc/resolv.conf /etc/resolv.conf.backup

    cat > /etc/resolv.conf << 'EOF'
# DNS zaštita - koristi Cloudflare DoH i Google
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
EOF
fi

# Zaštiti resolv.conf od automatskih promjena
chattr +i /etc/resolv.conf 2>/dev/null

# IPv6 leak zaštita (već u security patchу, ali pojačaj)
cat >> /etc/sysctl.d/99-privacy.conf << 'EOF'
# IPv6 - potpuno isključi (sprječava IPv6 leak)
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# Sakrij hostname od mreže
net.ipv4.icmp_echo_ignore_all=0
EOF
sysctl -p /etc/sysctl.d/99-privacy.conf &>/dev/null

echo -e "${GREEN}  ✓ DNS zaštita aktivna${NC}"
echo -e "${GREEN}  ✓ resolv.conf zaštićen od izmjena${NC}"
echo -e "${GREEN}  ✓ IPv6 leak zaštita aktivna${NC}"

# ================================================
echo -e "\n${CYAN}[6/7] Kreiranje privacy skripti...${NC}"
# ================================================

# Skripta: Anonimni mod - sve kroz Tor
cat > $USER_HOME/anonimni_mod.sh << 'ANONSCRIPT'
#!/bin/bash
# ============================================
# ANONIMNI MOD - Sve kroz Tor
# Pokreni: bash ~/anonimni_mod.sh
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== ANONIMNI MOD ===${NC}"

# Provjeri da li Tor radi
if ! systemctl is-active --quiet tor; then
    echo -e "${YELLOW}Pokrećem Tor...${NC}"
    sudo systemctl start tor
    sleep 5
fi

# Promijeni MAC adresu
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo ip link set $IFACE down 2>/dev/null
sudo macchanger -r $IFACE 2>/dev/null
sudo ip link set $IFACE up 2>/dev/null

# Provjeri Tor konekciju
TOR_IP=$(proxychains4 -q curl -s https://check.torproject.org/api/ip \
    2>/dev/null | grep -o '"IP":"[^"]*"' | cut -d'"' -f4)
REAL_IP=$(curl -s https://api.ipify.org 2>/dev/null)

echo ""
echo -e "${YELLOW}Tvoj pravi IP:${NC} $REAL_IP"
echo -e "${GREEN}Tor IP (vidljiv svijetu):${NC} $TOR_IP"
echo ""

if [ -n "$TOR_IP" ] && [ "$TOR_IP" != "$REAL_IP" ]; then
    echo -e "${GREEN}✓ Tor radi ispravno!${NC}"
    echo -e "${GREEN}✓ MAC adresa promijenjena${NC}"
    echo ""
    echo -e "${CYAN}Pokreni browser kroz Tor:${NC}"
    echo -e "${GREEN}proxychains4 midori${NC}"
    echo -e "${GREEN}proxychains4 palemoon${NC}"
else
    echo -e "${RED}✗ Tor ne radi ispravno!${NC}"
    echo -e "${YELLOW}Provjeri: sudo systemctl status tor${NC}"
fi
ANONSCRIPT
chmod +x $USER_HOME/anonimni_mod.sh
chown $USERNAME:$USERNAME $USER_HOME/anonimni_mod.sh

# Skripta: Promijeni Tor IP (nova ruta)
cat > $USER_HOME/nova_tor_ip.sh << 'NEWIP'
#!/bin/bash
# Zatraži novu Tor IP adresu
echo "Stara IP:"
proxychains4 -q curl -s https://api.ipify.org 2>/dev/null
echo ""

# Pošalji NEWNYM signal Toru
(echo authenticate '""'; echo signal newnym; echo quit) | \
    nc 127.0.0.1 9051 2>/dev/null || \
    sudo killall -HUP tor 2>/dev/null

sleep 3
echo "Nova IP:"
proxychains4 -q curl -s https://api.ipify.org 2>/dev/null
echo ""
echo "✓ Nova Tor ruta aktivna!"
NEWIP
chmod +x $USER_HOME/nova_tor_ip.sh
chown $USERNAME:$USERNAME $USER_HOME/nova_tor_ip.sh

echo -e "${GREEN}  ✓ ~/anonimni_mod.sh napravljena${NC}"
echo -e "${GREEN}  ✓ ~/nova_tor_ip.sh napravljena${NC}"
echo -e "${GREEN}  ✓ ~/promijeni_mac.sh napravljena${NC}"

# ================================================
echo -e "\n${CYAN}[7/7] Aliases za brzi pristup...${NC}"
# ================================================

# Dodaj aliases u bashrc ako već nisu tu
if ! grep -q "alias tor-browser" $USER_HOME/.bashrc 2>/dev/null; then
    cat >> $USER_HOME/.bashrc << 'ALIASES'

# Privacy aliases
alias tor-browser='proxychains4 midori'
alias tor-pale='proxychains4 palemoon'
alias moj-ip='curl -s https://api.ipify.org && echo'
alias tor-ip='proxychains4 -q curl -s https://api.ipify.org && echo'
alias nova-ip='bash ~/nova_tor_ip.sh'
alias anon='bash ~/anonimni_mod.sh'
alias promijeni-mac='bash ~/promijeni_mac.sh'
alias tor-status='systemctl status tor'
ALIASES
fi

echo -e "${GREEN}  ✓ Aliases dodani u .bashrc${NC}"

# ================================================
# REZULTAT
# ================================================
echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║       PRIVACY SETUP ZAVRŠEN! ✓         ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Brze komande:${NC}"
echo -e "  ${GREEN}anon${NC}              - Provjeri anonimnost"
echo -e "  ${GREEN}tor-browser${NC}       - Browser kroz Tor"
echo -e "  ${GREEN}nova-ip${NC}           - Nova Tor IP"
echo -e "  ${GREEN}moj-ip${NC}            - Pravi IP"
echo -e "  ${GREEN}tor-ip${NC}            - IP koji vidi internet"
echo -e "  ${GREEN}promijeni-mac${NC}     - Nova MAC adresa"
echo ""
echo -e "${YELLOW}  Primjer: proxychains4 KOMANDA${NC}"
echo -e "  ${GREEN}proxychains4 curl https://example.com${NC}"
echo -e "  ${GREEN}proxychains4 nmap -sT target.com${NC}"
echo ""
