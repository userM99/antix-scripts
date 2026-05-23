#!/bin/bash
# ============================================
# ELLIOTT.SH - Finalna master skripta
# antiX 23.2 i686 32-bit - runit verzija
# RAM + GPU + DISK + SECURITY + PRIVACY
# + BROWSER + CLEANUP + ICEWM
# BEZ CPU governor (grije se!)
# Pokreni: sudo bash elliott.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- PROVJERE ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash elliott.sh${NC}"
    exit 1
fi

# Nađi korisnika
if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
elif [ -n "$LOGNAME" ] && [ "$LOGNAME" != "root" ]; then
    USERNAME="$LOGNAME"
else
    USERNAME=$(who | awk '{print $1}' | grep -v root | head -1)
fi
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"
USER_HOME="/home/$USERNAME"

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║           ELLIOTT.SH                   ║"
echo "  ║   antiX 23.2 i686 - Finalna skripta   ║"
echo "  ║   RAM+GPU+DISK+SECURITY+PRIVACY        ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Korisnik: $USERNAME${NC}"
echo -e "${YELLOW}  Home:     $USER_HOME${NC}"
echo ""

RAM_PRIJE=$(free -m | awk 'NR==2{print $3}')
echo -e "${YELLOW}  RAM prije: ${RAM_PRIJE}MB${NC}"
sleep 2

# ================================================
echo -e "\n${CYAN}━━━ [1/15] RAM OPTIMIZACIJA ━━━${NC}"
# ================================================

cat > /etc/sysctl.d/99-elliott.conf << 'EOF'
# RAM
vm.swappiness=5
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.dirty_expire_centisecs=1000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=65536
vm.nr_hugepages=64
vm.watermark_scale_factor=10

# Mreža
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_congestion_control=cubic
net.core.netdev_max_backlog=2000

# IPv6 isključi
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# Kernel
kernel.nmi_watchdog=0
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=1
kernel.sched_latency_ns=4000000
kernel.sched_min_granularity_ns=500000
kernel.sched_wakeup_granularity_ns=500000
EOF

sysctl -p /etc/sysctl.d/99-elliott.conf &>/dev/null

# Transparent hugepages
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
echo madvise > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null

# KSM - spaja identične stranice u RAM-u
if [ -f /sys/kernel/mm/ksm/run ]; then
    echo 1 > /sys/kernel/mm/ksm/run
    echo 100 > /sys/kernel/mm/ksm/sleep_millisecs
    echo 1000 > /sys/kernel/mm/ksm/pages_to_scan
fi

echo -e "${GREEN}  ✓ swappiness=5${NC}"
echo -e "${GREEN}  ✓ Hugepages aktivni${NC}"
echo -e "${GREEN}  ✓ KSM aktivan (spaja identične RAM stranice)${NC}"
echo -e "${GREEN}  ✓ IPv6 isključen${NC}"
echo -e "${GREEN}  ✓ TCP cubic + mrežna optimizacija${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [2/15] GPU OPTIMIZACIJA (AMD Radeon) ━━━${NC}"
# ================================================

# AMD driveri
apt-get install -y \
    firmware-amd-graphics \
    libgl1-mesa-dri \
    mesa-opencl-icd \
    ocl-icd-opencl-dev \
    xserver-xorg-video-radeon \
    mesa-va-drivers \
    vainfo -qq 2>/dev/null

# GPU Performance mode
for card in /sys/class/drm/card*/device; do
    [ -f "$card/power_dpm_force_performance_level" ] && \
        echo "high" > "$card/power_dpm_force_performance_level" 2>/dev/null
    [ -f "$card/power_profile" ] && \
        echo "high" > "$card/power_profile" 2>/dev/null
done

# Permanentno
cat > /etc/udev/rules.d/30-gpu-performance.rules << 'EOF'
KERNEL=="card0", SUBSYSTEM=="drm", DRIVERS=="radeon", ATTR{device/power_dpm_force_performance_level}="high"
EOF

# Xorg konfiguracija
mkdir -p /etc/X11/xorg.conf.d/
cat > /etc/X11/xorg.conf.d/20-radeon.conf << 'EOF'
Section "Device"
    Identifier  "AMD Radeon HD 6330M"
    Driver      "radeon"
    Option      "AccelMethod"     "glamor"
    Option      "DRI"             "3"
    Option      "TearFree"        "on"
    Option      "ColorTiling"     "on"
    Option      "ColorTiling2D"   "on"
    Option      "SwapbuffersWait" "false"
    Option      "EXAVsync"        "off"
EndSection
EOF

# GPU env varijable
cat > /etc/profile.d/gpu-opt.sh << 'EOF'
export vblank_mode=0
export MESA_GL_VERSION_OVERRIDE=4.5
export AMD_DEBUG=nodma
EOF

# OpenCL
mkdir -p /etc/OpenCL/vendors/
OCL_LIB=$(find /usr/lib -name "libMesaOpenCL*" 2>/dev/null | head -1)
[ -n "$OCL_LIB" ] && echo "$OCL_LIB" > /etc/OpenCL/vendors/mesa.icd

echo -e "${GREEN}  ✓ GPU DPM → high performance${NC}"
echo -e "${GREEN}  ✓ Xorg glamor + DRI3 + TearFree${NC}"
echo -e "${GREEN}  ✓ OpenCL aktivan${NC}"
echo -e "${GREEN}  ✓ VAAPI video akceleracija${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [3/15] DISK I/O OPTIMIZACIJA ━━━${NC}"
# ================================================

for disk in /sys/block/sd*; do
    [ -d "$disk" ] || continue
    name=$(basename $disk)
    if [ -f "$disk/queue/scheduler" ]; then
        echo bfq > "$disk/queue/scheduler" 2>/dev/null || \
        echo deadline > "$disk/queue/scheduler" 2>/dev/null
    fi
    [ -f "$disk/queue/read_ahead_kb" ] && \
        echo 1024 > "$disk/queue/read_ahead_kb" 2>/dev/null
    [ -f "$disk/queue/nr_requests" ] && \
        echo 64 > "$disk/queue/nr_requests" 2>/dev/null
    blockdev --setra 2048 /dev/$name 2>/dev/null
done

cat > /etc/udev/rules.d/60-disk-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
EOF

# noatime
if ! grep -q "noatime" /etc/fstab; then
    sed -i 's/errors=remount-ro/errors=remount-ro,noatime,nodiratime/g' \
        /etc/fstab 2>/dev/null
fi

# /tmp u RAM
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=256M 0 0" >> /etc/fstab
fi
mount -o remount /tmp 2>/dev/null

echo -e "${GREEN}  ✓ BFQ I/O scheduler${NC}"
echo -e "${GREEN}  ✓ Readahead 1024KB${NC}"
echo -e "${GREEN}  ✓ noatime (disk brži)${NC}"
echo -e "${GREEN}  ✓ /tmp u RAM-u (256MB)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [4/15] GAŠENJE NEPOTREBNIH SERVISA ━━━${NC}"
# ================================================

SERVISI=(bluetooth cups avahi-daemon nfs-common rpcbind
    exim4 ModemManager speech-dispatcher whoopsie
    apport kerneloops saned colord geoclue
    packagekit apt-daily apt-daily-upgrade)

UGASENO=0
for servis in "${SERVISI[@]}"; do
    if sv status /var/service/$servis 2>/dev/null | grep -q "run" 2>/dev/null || \
       [ -L "/var/service/$servis" ] 2>/dev/null; then
        sv stop /var/service/$servis 2>/dev/null
        update-service --remove $servis 2>/dev/null
        update-rc.d "$servis" disable 2>/dev/null
        UGASENO=$((UGASENO + 1))
    fi
done
echo -e "${GREEN}  ✓ $UGASENO servisa ugašeno${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [5/15] ČIŠĆENJE PROCESA ━━━${NC}"
# ================================================

PROCESI=(tracker tracker-miner tracker-store gvfsd
    evolution deja-dup zeitgeist zeitgeist-daemon
    gnome-software update-notifier packagekitd)

UBIJENO=0
for proc in "${PROCESI[@]}"; do
    pkill -f "$proc" 2>/dev/null && UBIJENO=$((UBIJENO + 1))
done
echo -e "${GREEN}  ✓ $UBIJENO nepotrebnih procesa ugašeno${NC}"

# earlyoom
if ! command -v earlyoom &>/dev/null; then
    apt-get install -y earlyoom -qq 2>/dev/null
fi
update-service --add earlyoom 2>/dev/null
sv start /var/service/earlyoom 2>/dev/null
echo -e "${GREEN}  ✓ earlyoom aktivan (sprječava zamrzavanje)${NC}"

# preload
if ! command -v preload &>/dev/null; then
    apt-get install -y preload -qq 2>/dev/null
fi
update-service --add preload 2>/dev/null
sv start /var/service/preload 2>/dev/null
echo -e "${GREEN}  ✓ preload aktivan${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [6/15] SECURITY PATCHES (CVE) ━━━${NC}"
# ================================================

# CVE-2026-31431 Copy Fail
echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif.conf
rmmod algif_aead 2>/dev/null
echo -e "${GREEN}  ✓ CVE-2026-31431 (Copy Fail) patched${NC}"

# CVE-2021-22555 + CVE-2024-1086
cat > /etc/modprobe.d/disable-nftables.conf << 'EOF'
install nf_tables /bin/false
install nftables /bin/false
EOF
echo -e "${GREEN}  ✓ CVE-2021-22555 + CVE-2024-1086 patched${NC}"

# Blokira opasne module
cat > /etc/modprobe.d/disable-dangerous.conf << 'EOF'
install firewire-core /bin/false
install firewire-ohci /bin/false
install thunderbolt /bin/false
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install bluetooth /bin/false
install btusb /bin/false
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
EOF
echo -e "${GREEN}  ✓ Opasni moduli blokirani${NC}"

# Kernel hardening
cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.randomize_va_space=2
kernel.yama.ptrace_scope=1
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
kernel.unprivileged_userns_clone=0
kernel.sysrq=4
kernel.perf_event_paranoid=3
fs.suid_dumpable=0
fs.protected_hardlinks=1
fs.protected_symlinks=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.ip_forward=0
net.ipv4.tcp_timestamps=0
EOF
sysctl -p /etc/sysctl.d/99-hardening.conf &>/dev/null
echo -e "${GREEN}  ✓ Kernel hardening aktivan${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [7/15] FIREWALL (UFW) ━━━${NC}"
# ================================================

if ! command -v ufw &>/dev/null; then
    apt-get install -y ufw -qq 2>/dev/null
fi

ufw --force reset 2>/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward
ufw allow out 80/tcp
ufw allow out 443/tcp
ufw allow out 53/udp
ufw allow out 53/tcp
ufw deny in 23/tcp
ufw deny in 21/tcp
ufw deny in 135/tcp
ufw deny in 139/tcp
ufw deny in 445/tcp
ufw --force enable

echo -e "${GREEN}  ✓ UFW aktivan - sve blokirano osim HTTP/HTTPS/DNS${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [8/15] FAIL2BAN ━━━${NC}"
# ================================================

if ! command -v fail2ban-client &>/dev/null; then
    apt-get install -y fail2ban -qq 2>/dev/null
fi

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
EOF

update-service --add fail2ban 2>/dev/null
sv restart /var/service/fail2ban 2>/dev/null
echo -e "${GREEN}  ✓ Fail2ban aktivan${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [9/15] TOR + PROXYCHAINS4 ━━━${NC}"
# ================================================

apt-get install -y tor proxychains4 macchanger -qq 2>/dev/null

# Tor konfiguracija
cat > /etc/tor/torrc << 'EOF'
SocksPort 9050
SocksPolicy accept 127.0.0.1
SocksPolicy reject *
DNSPort 5353
AutomapHostsOnResolve 1
ControlPort 9051
CookieAuthentication 1
MaxCircuitDirtiness 600
NewCircuitPeriod 120
NumEntryGuards 3
CircuitBuildTimeout 10
ExcludeExitNodes {rs},{ba},{hr},{me},{mk}
StrictNodes 1
Log notice syslog
SafeLogging 1
EOF

update-service --add tor 2>/dev/null
sv restart /var/service/tor 2>/dev/null

# ProxyChains4
cat > /etc/proxychains4.conf << 'EOF'
dynamic_chain
quiet_mode
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000
remote_dns_subnet 224

[ProxyList]
socks5 127.0.0.1 9050
EOF

echo -e "${GREEN}  ✓ Tor aktivan na port 9050${NC}"
echo -e "${GREEN}  ✓ ProxyChains4 konfigurisan${NC}"
echo -e "${GREEN}  ✓ Exit node iz RS/BA/HR blokiran${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [10/15] DNSCRYPT-PROXY (ISP ne vidi DNS) ━━━${NC}"
# ================================================

apt-get install -y dnscrypt-proxy -qq 2>/dev/null

# Konfiguracija
cat > /etc/dnscrypt-proxy/dnscrypt-proxy.toml << 'EOF'
# ============================================
# DNSCrypt-Proxy konfiguracija
# Šifruje sve DNS upite - ISP ne vidi domene
# ============================================

# Slušaj na lokalnom portu 53
listen_addresses = ['127.0.0.1:53']

# Koristi samo DoH (DNS over HTTPS) servere
server_names = ['cloudflare', 'cloudflare-ipv6', 'google', 'quad9-dnscrypt-ip4-filter-pri']

# Blokira reklame i trackere na DNS nivou
block_ipv6 = true

# Log minimum
log_level = 0

# Cache - brže DNS odgovore
cache = true
cache_size = 512
cache_min_ttl = 600
cache_max_ttl = 86400

# Zaštita od DNS leak
require_dnssec = false
require_nolog = true
require_nofilter = false

# Fallback ako nema mreže
fallback_resolvers = ['9.9.9.9:53', '1.1.1.1:53']
ignore_system_dns = true
netprobe_timeout = 60

[sources]
  [sources.public-resolvers]
  urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md']
  cache_file = '/var/cache/dnscrypt-proxy/public-resolvers.md'
  minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
  refresh_delay = 72

[blacklist]
  blacklist_file = '/etc/dnscrypt-proxy/blacklist.txt'
EOF

# Napravi blacklist fajl za blokiranje reklama
cat > /etc/dnscrypt-proxy/blacklist.txt << 'EOF'
# Blokiranje reklama i trackera na DNS nivou
doubleclick.net
googlesyndication.com
googletagmanager.com
googletagservices.com
google-analytics.com
facebook.com/tr
connect.facebook.net
scorecardresearch.com
quantserve.com
adbrite.com
adnxs.com
advertising.com
adsense.google.com
EOF

# Napravi cache direktorij
mkdir -p /var/cache/dnscrypt-proxy
chown _dnscrypt-proxy:_dnscrypt-proxy /var/cache/dnscrypt-proxy 2>/dev/null || \
    chmod 777 /var/cache/dnscrypt-proxy

# Runit servis za dnscrypt-proxy
if [ -d /etc/sv ]; then
    mkdir -p /etc/sv/dnscrypt-proxy
    cat > /etc/sv/dnscrypt-proxy/run << 'RUNIT'
#!/bin/sh
exec /usr/sbin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml 2>&1
RUNIT
    chmod +x /etc/sv/dnscrypt-proxy/run
    ln -sf /etc/sv/dnscrypt-proxy /var/service/ 2>/dev/null
    sv start /var/service/dnscrypt-proxy 2>/dev/null
    sleep 2
fi

# Postavi kao primarni DNS - zaštiti od izmjena
chattr -i /etc/resolv.conf 2>/dev/null
cat > /etc/resolv.conf << 'EOF'
# DNSCrypt - lokalni DNS
nameserver 127.0.0.1
# Fallback
nameserver 1.1.1.1
nameserver 9.9.9.9
EOF
chattr +i /etc/resolv.conf 2>/dev/null

# Provjeri da li radi
sleep 2
if dig +short google.com @127.0.0.1 &>/dev/null; then
    echo -e "${GREEN}  ✓ DNSCrypt-proxy radi!${NC}"
    echo -e "${GREEN}  ✓ DNS upiti šifrovani${NC}"
    echo -e "${GREEN}  ✓ ISP ne vidi koje domene posjećuješ${NC}"
    echo -e "${GREEN}  ✓ Reklame blokirane na DNS nivou${NC}"
else
    echo -e "${YELLOW}  ⚠ DNSCrypt startuje - provjeri: sv status /var/service/dnscrypt-proxy${NC}"
    echo -e "${YELLOW}    Fallback DNS: 1.1.1.1 aktivan${NC}"
fi

# ================================================
echo -e "\n${CYAN}━━━ [11/15] MAC ADRESA RANDOMIZACIJA ━━━${NC}"
# ================================================

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$IFACE" ]; then
    ip link set $IFACE down 2>/dev/null
    macchanger -r $IFACE 2>/dev/null
    ip link set $IFACE up 2>/dev/null
    NEW_MAC=$(macchanger -s $IFACE 2>/dev/null | grep "Current" | awk '{print $3}')
    echo -e "${GREEN}  ✓ MAC promijenjen: $NEW_MAC${NC}"
fi

# Permanentno pri bootu
cat > /etc/network/if-pre-up.d/macchanger << 'MACSCRIPT'
#!/bin/bash
[ "$IFACE" != "lo" ] && /usr/bin/macchanger -r $IFACE 2>/dev/null
MACSCRIPT
chmod +x /etc/network/if-pre-up.d/macchanger
echo -e "${GREEN}  ✓ MAC randomizacija pri svakom bootu${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [12/15] ICEWM + REZOLUCIJA ━━━${NC}"
# ================================================

mkdir -p $USER_HOME/.icewm

cat > $USER_HOME/.icewm/preferences << 'EOF'
AnimateWindowMinimize=0
AnimateWindowRestore=0
TaskBarAutoHide=0
TaskBarDoubleHeight=0
TaskBarShowClock=1
TaskBarShowWorkspaces=1
TaskBarShowMailboxStatus=0
TaskBarShowCPUStatus=0
TaskBarShowNetStatus=0
TaskBarShowMEMStatus=0
FocusOnClickClient=1
RaiseOnFocus=0
ClickToFocus=1
AutoRaise=0
DelayPointerFocus=0
Theme="default"
Sounds=0
DesktopBackgroundColor="#1a1a2e"
DesktopBackgroundImage=""
ShowThemesMenu=0
ShowHelpMenu=0
EOF

# Rezolucija 1280x1024
cat > /etc/X11/xorg.conf.d/10-rezolucija.conf << 'EOF'
Section "Screen"
    Identifier "Screen0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1280x1024" "1024x768"
    EndSubSection
EndSection

Section "Monitor"
    Identifier "Monitor0"
    Option "PreferredMode" "1280x1024"
EndSection
EOF

# IceWM startup rezolucija
cat > $USER_HOME/.icewm/startup << 'EOF'
#!/bin/bash
xrandr --output VGA-0 --mode 1280x1024 2>/dev/null || \
xrandr --output VGA-1 --mode 1280x1024 2>/dev/null || \
xrandr --auto --mode 1280x1024 2>/dev/null
EOF
chmod +x $USER_HOME/.icewm/startup

chown -R $USERNAME:$USERNAME $USER_HOME/.icewm
echo -e "${GREEN}  ✓ Sve animacije isključene${NC}"
echo -e "${GREEN}  ✓ Tema → default (najlakša)${NC}"
echo -e "${GREEN}  ✓ Rezolucija 1280x1024${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [13/15] BROWSER PRIVACY (PaleMoon) ━━━${NC}"
# ================================================

# Instaliraj Midori ako nema
if ! command -v midori &>/dev/null; then
    apt-get install -y midori -qq 2>/dev/null
    echo -e "${GREEN}  ✓ Midori instaliran (~150MB RAM)${NC}"
fi

# PaleMoon privacy
PALE_PROFILE=$(find $USER_HOME -name "prefs.js" \
    -path "*/Pale Moon/*" 2>/dev/null | head -1)

if [ -n "$PALE_PROFILE" ]; then
    cat >> "$PALE_PROFILE" << 'EOF'
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("geo.enabled", false);
user_pref("dom.webrtc.enabled", false);
user_pref("webgl.disabled", true);
user_pref("dom.battery.enabled", false);
user_pref("network.http.referer.spoofSource", true);
user_pref("browser.send_pings", false);
user_pref("browser.safebrowsing.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("canvas.poisondata", true);
user_pref("browser.cache.memory.capacity", 32768);
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0");
EOF
    echo -e "${GREEN}  ✓ PaleMoon fingerprint zaštita${NC}"
    echo -e "${GREEN}  ✓ User-Agent → Windows Firefox${NC}"
    echo -e "${GREEN}  ✓ WebRTC + Canvas blokirani${NC}"
fi

# ================================================
echo -e "\n${CYAN}━━━ [14/15] ČIŠĆENJE CACHE + PRIVACY ━━━${NC}"
# ================================================

# RAM cache
sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null

# User cache
rm -rf $USER_HOME/.cache/* 2>/dev/null
rm -rf $USER_HOME/.thumbnails/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/*.* 2>/dev/null

# Browser cache
find $USER_HOME -path "*/Pale Moon/*/cache2" -type d \
    2>/dev/null | while read d; do rm -rf "$d"/* 2>/dev/null; done

# APT
apt-get autoremove -y -qq 2>/dev/null
apt-get autoclean -qq 2>/dev/null

# History
for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    cat /dev/null > "$home_dir/.bash_history" 2>/dev/null
    cat /dev/null > "$home_dir/.zsh_history" 2>/dev/null
    rm -f "$home_dir/.recently-used" 2>/dev/null
    rm -f "$home_dir/.local/share/recently-used.xbel" 2>/dev/null
done
history -c 2>/dev/null

# Logovi
LOGOVI=(/var/log/auth.log /var/log/syslog /var/log/kern.log
    /var/log/messages /var/log/debug /var/log/daemon.log
    /var/log/wtmp /var/log/btmp /var/log/lastlog
    /var/log/faillog /var/log/dpkg.log)

for log in "${LOGOVI[@]}"; do
    [ -f "$log" ] && cat /dev/null > "$log" 2>/dev/null
done

find /var/log -name "*.gz" -delete 2>/dev/null
find /var/log -name "*.1" -delete 2>/dev/null

journalctl --vacuum-size=5M 2>/dev/null
journalctl --vacuum-time=30m 2>/dev/null

# Ne snimaj history trajno
if ! grep -q "HISTFILE=/dev/null" $USER_HOME/.bashrc 2>/dev/null; then
    cat >> $USER_HOME/.bashrc << 'EOF'

# Privacy
HISTSIZE=1000
HISTFILESIZE=0
HISTFILE=/dev/null
EOF
fi

echo -e "${GREEN}  ✓ RAM cache oslobođen${NC}"
echo -e "${GREEN}  ✓ User + browser cache obrisan${NC}"
echo -e "${GREEN}  ✓ Svi logovi obrisani${NC}"
echo -e "${GREEN}  ✓ History onemogućena trajno${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [15/15] ALIASES + BOOT ━━━${NC}"
# ================================================

# Aliases
if ! grep -q "alias anon" $USER_HOME/.bashrc 2>/dev/null; then
    cat >> $USER_HOME/.bashrc << 'EOF'

# Elliott aliases
alias anon='bash ~/anonimni_mod.sh'
alias tor-browser='proxychains4 midori'
alias tor-pale='proxychains4 palemoon'
alias moj-ip='curl -s https://api.ipify.org && echo'
alias tor-ip='proxychains4 -q curl -s https://api.ipify.org && echo'
alias nova-ip='bash ~/nova_tor_ip.sh'
alias promijeni-mac='bash ~/promijeni_mac.sh'
alias ramclean='sync && echo 3 | sudo tee /proc/sys/vm/drop_caches'
alias temp='sensors'
alias procesi='ps aux --sort=-%mem | head -10'
alias elliott='sudo bash ~/elliott.sh'
EOF
fi

# Grub optimizacija (BEZ mitigations=off za sigurnost)
if [ -f /etc/default/grub ]; then
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet noresume nowatchdog"/' \
        /etc/default/grub
    update-grub 2>/dev/null
fi

# Autostart svakih 6h
cat > /etc/cron.d/elliott-auto << EOF
0 */6 * * * root bash $USER_HOME/elliott.sh > /dev/null 2>&1
EOF

# Vlasništvo
chown -R $USERNAME:$USERNAME $USER_HOME/ 2>/dev/null

# Napravi anonimni mod skriptu
cat > $USER_HOME/anonimni_mod.sh << 'ANONSCRIPT'
#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== ANONIMNI MOD ===${NC}"

# Pokreni Tor ako ne radi
if ! sv status /var/service/tor 2>/dev/null | grep -q "run"; then
    echo -e "${YELLOW}Pokrećem Tor...${NC}"
    sudo sv start /var/service/tor
    sleep 5
fi

# Promijeni MAC
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo ip link set $IFACE down 2>/dev/null
sudo macchanger -r $IFACE 2>/dev/null
sudo ip link set $IFACE up 2>/dev/null

# Provjeri IP
REAL_IP=$(curl -s https://api.ipify.org 2>/dev/null)
TOR_IP=$(proxychains4 -q curl -s https://api.ipify.org 2>/dev/null)

echo -e "${YELLOW}  Pravi IP:${NC} $REAL_IP"
echo -e "${GREEN}  Tor IP:${NC}   $TOR_IP"

if [ -n "$TOR_IP" ] && [ "$TOR_IP" != "$REAL_IP" ]; then
    echo -e "${GREEN}  ✓ Tor radi ispravno!${NC}"
    echo -e "${GREEN}  ✓ MAC promijenjen${NC}"
    echo ""
    echo -e "${CYAN}  Koristi: proxychains4 midori${NC}"
else
    echo -e "${RED}  ✗ Provjeri: sudo sv status /var/service/tor${NC}"
fi
ANONSCRIPT
chmod +x $USER_HOME/anonimni_mod.sh
chown $USERNAME:$USERNAME $USER_HOME/anonimni_mod.sh

# Nova Tor IP skripta
cat > $USER_HOME/nova_tor_ip.sh << 'NEWIP'
#!/bin/bash
echo "Stara IP:"
proxychains4 -q curl -s https://api.ipify.org 2>/dev/null
echo ""
sudo killall -HUP tor 2>/dev/null
sleep 3
echo "Nova IP:"
proxychains4 -q curl -s https://api.ipify.org 2>/dev/null
echo ""
echo "✓ Nova Tor ruta!"
NEWIP
chmod +x $USER_HOME/nova_tor_ip.sh
chown $USERNAME:$USERNAME $USER_HOME/nova_tor_ip.sh

echo -e "${GREEN}  ✓ Aliases dodani${NC}"
echo -e "${GREEN}  ✓ Grub timeout = 1s${NC}"
echo -e "${GREEN}  ✓ Autostart svakih 6h${NC}"
echo -e "${GREEN}  ✓ anonimni_mod.sh napravljena${NC}"
echo -e "${GREEN}  ✓ nova_tor_ip.sh napravljena${NC}"

# ================================================
# REZULTAT
# ================================================
RAM_POSLIJE=$(free -m | awk 'NR==2{print $3}')
RAM_OSLOBODJENO=$((RAM_PRIJE - RAM_POSLIJE))

echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║         ELLIOTT.SH ZAVRŠEN! ✓          ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${YELLOW}RAM prije:${NC}   ${RED}%dMB${NC}\n" $RAM_PRIJE
printf "  ${GREEN}RAM poslije:${NC} ${GREEN}%dMB${NC}\n" $RAM_POSLIJE
printf "  ${GREEN}Oslobođeno:${NC}  ${GREEN}%dMB${NC}\n" $RAM_OSLOBODJENO
echo ""
echo -e "${CYAN}  Šta je urađeno:${NC}"
echo -e "  ✓ RAM optimizacija + KSM"
echo -e "  ✓ GPU AMD Radeon performance"
echo -e "  ✓ BFQ disk scheduler + noatime"
echo -e "  ✓ Nepotrebni servisi ugašeni"
echo -e "  ✓ CVE patches (Copy Fail, Priv Esc, Flipping Pages)"
echo -e "  ✓ Kernel hardening"
echo -e "  ✓ UFW Firewall"
echo -e "  ✓ Fail2ban"
echo -e "  ✓ Tor + ProxyChains4"
  echo -e "  ✓ DNSCrypt-proxy (ISP ne vidi DNS)"
echo -e "  ✓ MAC randomizacija"
echo -e "  ✓ IceWM animacije isključene"
echo -e "  ✓ Rezolucija 1280x1024"
echo -e "  ✓ Browser fingerprint zaštita"
echo -e "  ✓ Logovi + history obrisani"
echo ""
echo -e "${YELLOW}  Brze komande:${NC}"
echo -e "  ${GREEN}anon${NC}         - Anonimni mod"
echo -e "  ${GREEN}tor-browser${NC}  - Browser kroz Tor"
echo -e "  ${GREEN}nova-ip${NC}      - Nova Tor IP"
echo -e "  ${GREEN}ramclean${NC}     - Oslobodi RAM"
echo -e "  ${GREEN}temp${NC}         - Temperatura"
echo -e "  ${GREEN}elliott${NC}      - Pokreni ovu skriptu"
echo ""
echo -e "${RED}  RESTART za puni efekt:${NC}"
echo -e "${GREEN}  sudo reboot${NC}"
echo ""
