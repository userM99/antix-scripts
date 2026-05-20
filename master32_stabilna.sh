#!/bin/bash
# ============================================
# MASTER32_STABILNA - Optimizacija antiX 26
# Bezbedno za mešovite Bookworm/Trixie sisteme
# Pokreni: sudo bash master32_stabilna.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash master32_stabilna.sh${NC}"
    exit 1
fi

# Detekcija korisnika
if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
elif [ -n "$LOGNAME" ] && [ "$LOGNAME" != "root" ]; then
    USERNAME="$LOGNAME"
else
    USERNAME=$(who | awk '{print $1}' | grep -v root | head -1)
fi
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"
USER_HOME="/home/$USERNAME"

# Helperi za SysVinit
svc_start()   { service "$1" start   2>/dev/null; }
svc_stop()    { service "$1" stop    2>/dev/null; }
svc_enable()  { update-rc.d "$1" defaults 2>/dev/null; }
svc_disable() { update-rc.d "$1" disable  2>/dev/null; }
svc_is_running() { service "$1" status &>/dev/null; }
svc_is_enabled() { ls /etc/rc2.d/S*"$1"* &>/dev/null 2>&1; }

clear
echo -e "${CYAN}  ╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║   SIGURNA MASTER OPTIMIZACIJA antiX    ║${NC}"
echo -e "${CYAN}  ║   Arhitektura: 32-bit (i686)           ║${NC}"
echo -e "${CYAN}  ╚════════════════════════════════════════╝${NC}"
echo ""

RAM_PRIJE=$(free -m | awk 'NR==2{print $3}')

# ================================================
echo -e "${CYAN}━━━ [1/8] CPU PERFORMANSE ━━━${NC}"
# ================================================
CPU_COUNT=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo "performance" > "$cpu" 2>/dev/null
        CPU_COUNT=$((CPU_COUNT + 1))
    fi
done
if [ -f /etc/default/cpufrequtils ]; then
    echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
fi
echo -e "${GREEN}  ✓ CPU prebačen na maksimalne performanse ($CPU_COUNT jzg.)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [2/8] SYSCTL RAM & OPTIMIZACIJA JEZGRA ━━━${NC}"
# ================================================
cat > /etc/sysctl.d/99-master32.conf << 'EOF'
vm.swappiness=5
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.dirty_expire_centisecs=1000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=32768
net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
kernel.nmi_watchdog=0
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=1
EOF

sysctl -p /etc/sysctl.d/99-master32.conf &>/dev/null
echo -e "${GREEN}  ✓ Swappiness smanjen na 5 (manje drndanja diska)${NC}"
echo -e "${GREEN}  ✓ IPv6 je deaktiviran radi stabilnije mreže${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [3/8] RADEON GPU KONFIGURACIJA ━━━${NC}"
# ================================================
for card in /sys/class/drm/card*/device; do
    [ -f "$card/power_dpm_force_performance_level" ] && echo "high" > "$card/power_dpm_force_performance_level" 2>/dev/null
    [ -f "$card/power_profile" ] && echo "high" > "$card/power_profile" 2>/dev/null
done

cat > /etc/udev/rules.d/30-gpu-performance.rules << 'EOF'
KERNEL=="card0", SUBSYSTEM=="drm", DRIVERS=="radeon", ATTR{device/power_dpm_force_performance_level}="high"
EOF

mkdir -p /etc/X11/xorg.conf.d/
cat > /etc/X11/xorg.conf.d/20-radeon.conf << 'EOF'
Section "Device"
    Identifier  "AMD Radeon HD 6330M"
    Driver      "radeon"
    Option      "AccelMethod"     "glamor"
    Option      "DRI"             "3"
    Option      "TearFree"        "on"
    Option      "ColorTiling"     "on"
    Option      "SwapbuffersWait" "false"
EndSection
EOF

cat > /etc/profile.d/gpu-opt.sh << 'EOF'
export vblank_mode=0
export AMD_DEBUG=nodma
export LIBGL_DRI3_DISABLE=0
EOF
echo -e "${GREEN}  ✓ Konfigurisano hardversko ubrzanje (Glamor + DRI3)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [4/8] UBRZANJE MODULACIJE DISKA ━━━${NC}"
# ================================================
for disk in /sys/block/sd*; do
    [ -d "$disk" ] || continue
    if [ -f "$disk/queue/scheduler" ]; then
        echo bfq > "$disk/queue/scheduler" 2>/dev/null || echo mq-deadline > "$disk/queue/scheduler" 2>/dev/null
    fi
    [ -f "$disk/queue/read_ahead_kb" ] && echo 1024 > "$disk/queue/read_ahead_kb" 2>/dev/null
done

if ! grep -q "noatime" /etc/fstab; then
    sed -i 's/errors=remount-ro/errors=remount-ro,noatime,nodiratime/g' /etc/fstab 2>/dev/null
fi
echo -e "${GREEN}  ✓ I/O scheduler podešen na optimalan odziv diska${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [5/8] SEČA POZADINSKIH SERVISA ━━━${NC}"
# ================================================
SERVISI=(bluetooth cups avahi-daemon nfs-common rpcbind exim4 ModemManager speech-dispatcher saned colord geoclue packagekit)
UGASENO=0
for servis in "${SERVISI[@]}"; do
    if [ -f "/etc/init.d/$servis" ]; then
        if svc_is_running "$servis" || svc_is_enabled "$servis"; then
            svc_stop "$servis"
            svc_disable "$servis"
            UGASENO=$((UGASENO + 1))
        fi
    fi
done
echo -e "${GREEN}  ✓ Ugašeno $UGASENO servisa koji opterećuju radnu memoriju${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [6/8] ČIŠĆENJE KEŠA I LOGOVA (PRIVATNOST) ━━━${NC}"
# ================================================
sync && echo 3 > /proc/sys/vm/drop_caches
rm -rf $USER_HOME/.cache/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null

for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    cat /dev/null > "$home_dir/.bash_history" 2>/dev/null
done

LOGOVI=(/var/log/auth.log /var/log/syslog /var/log/kern.log)
for log in "${LOGOVI[@]}"; do
    [ -f "$log" ] && cat /dev/null > "$log" 2>/dev/null
done
echo -e "${GREEN}  ✓ Očišćen privremeni keš i istorija terminala${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [7/8] REZOLUCIJA MONITOR (1280x1024 @ 75Hz) ━━━${NC}"
# ================================================
mkdir -p /etc/X11/xorg.conf.d/
cat > /etc/X11/xorg.conf.d/10-rezolucija.conf << 'EOF'
Section "Screen"
    Identifier "Screen0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1280x1024"
    EndSubSection
EndSection
EOF

mkdir -p $USER_HOME/.icewm
cat > $USER_HOME/.icewm/startup << 'EOF'
#!/bin/bash
# Sinhronizacija VGA-0 izlaza i frekvencije monitora
xrandr --newmode "1280x1024_75.00"  138.75  1280 1368 1504 1728  1024 1027 1034 1072 -hsync +vsync 2>/dev/null
xrandr --addmode VGA-0 "1280x1024_75.00" 2>/dev/null
xrandr --output VGA-0 --mode "1280x1024_75.00" 2>/dev/null
EOF
chmod +x $USER_HOME/.icewm/startup
chown -R $USERNAME:$USERNAME $USER_HOME/.icewm 2>/dev/null
echo -e "${GREEN}  ✓ Kreiran automatski xrandr skript za VGA-0 izlaz monitora${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [8/8] UKLANJANJE GRUB ČEKANJA ━━━${NC}"
# ================================================
if [ -f /etc/default/grub ]; then
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    update-grub 2>/dev/null
fi
echo -e "${GREEN}  ✓ GRUB meni postavljen na minimalnih 1 sekundu${NC}"

# ================================================
RAM_POSLIJE=$(free -m | awk 'NR==2{print $3}')
RAM_OSLOBODJENO=$((RAM_PRIJE - RAM_POSLIJE))
echo -e "\n${GREEN}  ✓ OPTIMIZACIJA JE USPEŠNO ZAVRŠENA!${NC}"
echo -e "${YELLOW}  Sada samo unesi komandu za ponovno pokretanje računara: sudo reboot${NC}\n"
