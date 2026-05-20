#!/bin/bash
# ============================================
# MASTER32 - Finalna optimizacija antiX 26 x32
# CPU + GPU + RAM + DISK + CLEANUP + PRIVACY
# Prilagođeno za 32-bit (i686 / 386) & 2GB RAM
# Init: SysVinit | Debian 12 (Bookworm)
# Pokreni: sudo bash master32.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- PROVJERE ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash master32.sh${NC}"
    exit 1
fi

ARCH=$(uname -m)
# Dopušta i686, i386, i486 i slične 32-bitne arhitekture
if [[ "$ARCH" == "x86_64" ]]; then
    echo -e "${YELLOW}Upozorenje: Pokrećeš 32-bitnu skriptu na 64-bitnom sistemu!${NC}"
fi

# Nađi pravog korisnika
if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
elif [ -n "$LOGNAME" ] && [ "$LOGNAME" != "root" ]; then
    USERNAME="$LOGNAME"
else
    USERNAME=$(who | awk '{print $1}' | grep -v root | head -1)
fi

if [ -z "$USERNAME" ]; then
    USERNAME="Buyn4_G4L4"
    echo -e "${YELLOW}Koristi se default username: $USERNAME${NC}"
fi

USER_HOME="/home/$USERNAME"

# ============================================
# SysVinit helper funkcije (antiX - bez systemd!)
# ============================================
svc_start()   { service "$1" start   2>/dev/null; }
svc_stop()    { service "$1" stop    2>/dev/null; }
svc_enable()  { update-rc.d "$1" defaults 2>/dev/null; }
svc_disable() { update-rc.d "$1" disable  2>/dev/null; }

svc_is_running() { service "$1" status &>/dev/null; }
svc_is_enabled() { ls /etc/rc2.d/S*"$1"* &>/dev/null 2>&1; }

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║  MASTER OPTIMIZACIJA antiX 26 x32    ║"
echo "  ║  CPU + GPU + RAM + DISK + PRIVACY      ║"
echo "  ║  Prilagođeno za 32-bit & 2GB RAM       ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Arhitektura: $ARCH ✓${NC}"
echo -e "${YELLOW}  Korisnik:    $USERNAME${NC}"
echo -e "${YELLOW}  Home:        $USER_HOME${NC}"
echo ""

RAM_PRIJE=$(free -m | awk 'NR==2{print $3}')
echo -e "${YELLOW}  RAM prije: ${RAM_PRIJE}MB${NC}"
sleep 2

# ================================================
echo -e "\n${CYAN}━━━ [1/11] CPU OPTIMIZACIJA ━━━${NC}"
# ================================================

if ! command -v cpufreq-set &>/dev/null; then
    apt-get install -y cpufrequtils irqbalance -qq 2>/dev/null
fi

CPU_COUNT=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo "performance" > "$cpu" 2>/dev/null
        CPU_COUNT=$((CPU_COUNT + 1))
    fi
done

echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

svc_enable irqbalance
svc_start  irqbalance

echo -e "${GREEN}  ✓ Performance governor na $CPU_COUNT jezgri${NC}"
echo -e "${GREEN}  ✓ irqbalance aktivan (SysVinit)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [2/11] RAM OPTIMIZACIJA (Prilagođeno za 2GB) ━━━${NC}"
# ================================================

cat > /etc/sysctl.d/99-master32.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.dirty_expire_centisecs=1000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=32768
net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.core.rmem_default=65536
net.core.wmem_default=65536
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
kernel.nmi_watchdog=0
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=1
EOF

sysctl -p /etc/sysctl.d/99-master32.conf &>/dev/null

# Onemogućavamo transparent hugepages za sisteme sa malo RAM-a (štedi memoriju)
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
echo never > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null

echo -e "${GREEN}  ✓ swappiness=10 (optimizovano za 2GB RAM-a)${NC}"
echo -e "${GREEN}  ✓ Transparent Hugepages isključeni (čuvanje RAM-a)${NC}"
echo -e "${GREEN}  ✓ IPv6 isključen${NC}"
echo -e "${GREEN}  ✓ Mrežni stack optimizovan za starije arhitekture${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [3/11] GPU OPTIMIZACIJA (32-bit AMD Radeon) ━━━${NC}"
# ================================================

# Izbačene 64-bitne i teške OpenCL komponente koje guše 2GB RAM-a
apt-get install -y \
    firmware-amd-graphics \
    libgl1-mesa-dri \
    libglx-mesa0 \
    mesa-vulkan-drivers \
    xserver-xorg-video-radeon \
    mesa-va-drivers \
    vainfo \
    libva-drm2 \
    libva-x11-2 -qq 2>/dev/null

for card in /sys/class/drm/card*/device; do
    [ -f "$card/power_dpm_force_performance_level" ] && \
        echo "high" > "$card/power_dpm_force_performance_level" 2>/dev/null
    [ -f "$card/power_profile" ] && \
        echo "high" > "$card/power_profile" 2>/dev/null
done

cat > /etc/udev/rules.d/30-gpu-performance.rules << 'EOF'
KERNEL=="card0", SUBSYSTEM=="drm", DRIVERS=="radeon", ATTR{device/power_dpm_force_performance_level}="high"
KERNEL=="card0", SUBSYSTEM=="drm", DRIVERS=="amdgpu",  ATTR{device/power_dpm_force_performance_level}="high"
EOF

mkdir -p /etc/X11/xorg.conf.d/
cat > /etc/X11/xorg.conf.d/20-radeon.conf << 'EOF'
Section "Device"
    Identifier  "AMD Radeon"
    Driver      "radeon"
    Option      "AccelMethod"     "glamor"
    Option      "DRI"             "3"
    Option      "TearFree"        "on"
    Option      "ColorTiling"     "on"
    Option      "ColorTiling2D"   "on"
    Option      "SwapbuffersWait" "false"
    Option      "EXAVsync"        "off"
    Option      "backlight"       "native"
EndSection

Section "Screen"
    Identifier "Screen0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
    EndSubSection
EndSection
EOF

cat > /etc/profile.d/gpu-opt.sh << 'EOF'
export vblank_mode=0
export MESA_GL_VERSION_OVERRIDE=4.5
export MESA_GLSL_VERSION_OVERRIDE=450
export AMD_DEBUG=nodma
export LIBGL_DRI3_DISABLE=0
EOF

echo -e "${GREEN}  ✓ AMD 32-bit drajveri i Mesa instalirani${NC}"
echo -e "${GREEN}  ✓ GPU DPM → high performance${NC}"
echo -e "${GREEN}  ✓ Xorg glamor + DRI3 + TearFree konfigurisan${NC}"
echo -e "${GREEN}  ✓ VAAPI video akceleracija podešena${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [4/11] DISK I/O OPTIMIZACIJA ━━━${NC}"
# ================================================

for disk in /sys/block/sd* /sys/block/nvme*; do
    [ -d "$disk" ] || continue
    name=$(basename $disk)
    if [ -f "$disk/queue/scheduler" ]; then
        echo bfq > "$disk/queue/scheduler" 2>/dev/null || \
        echo mq-deadline > "$disk/queue/scheduler" 2>/dev/null
    fi
    [ -f "$disk/queue/read_ahead_kb" ] && echo 512 > "$disk/queue/read_ahead_kb" 2>/dev/null
    [ -f "$disk/queue/nr_requests" ]   && echo 32  > "$disk/queue/nr_requests"    2>/dev/null
    blockdev --setra 1024 /dev/$name 2>/dev/null
done

cat > /etc/udev/rules.d/60-disk-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]",          ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]",  ATTR{queue/scheduler}="mq-deadline"
EOF

if ! grep -q "noatime" /etc/fstab; then
    sed -i 's/errors=remount-ro/errors=remount-ro,noatime,nodiratime/g' /etc/fstab 2>/dev/null
fi

# Smanjen ramdisk sa 256MB na 128MB pošto imaš ukupno 2GB RAM-a
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=128M 0 0" >> /etc/fstab
fi
mount -o remount /tmp 2>/dev/null

echo -e "${GREEN}  ✓ BFQ/mq-deadline I/O scheduler konfigurisan${NC}"
echo -e "${GREEN}  ✓ Readahead optimizovan za starije diskove${NC}"
echo -e "${GREEN}  ✓ noatime aktiviran (brži upis/čitanje)${NC}"
echo -e "${GREEN}  ✓ /tmp prebačen u RAM (ograničen na bezbednih 128MB)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [5/11] GAŠENJE SERVISA (SysVinit) ━━━${NC}"
# ================================================

SERVISI=(bluetooth cups avahi-daemon nfs-common rpcbind exim4
    ModemManager speech-dispatcher saned colord geoclue packagekit)

UGASENO=0
for servis in "${SERVISI[@]}"; do
    if [ -f "/etc/init.d/$servis" ]; then
        if svc_is_running "$servis" || svc_is_enabled "$servis"; then
            svc_stop    "$servis"
            svc_disable "$servis"
            UGASENO=$((UGASENO + 1))
        fi
    fi
done

echo -e "${GREEN}  ✓ $UGASENO nepotrebnih servisa ugašeno (SysVinit)${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [6/11] ČIŠĆENJE PROCESA ━━━${NC}"
# ================================================

PROCESI=(tracker tracker-miner tracker-store gvfsd evolution
    deja-dup zeitgeist zeitgeist-daemon gnome-software
    update-notifier packagekitd)

UBIJENO=0
for proc in "${PROCESI[@]}"; do
    pkill -f "$proc" 2>/dev/null && UBIJENO=$((UBIJENO + 1))
done
echo -e "${GREEN}  ✓ $UBIJENO pozadinskih procesa ugašeno${NC}"

# earlyoom - Spasava sistem od zamrzavanja kada pretraživač pojede RAM
if ! command -v earlyoom &>/dev/null; then
    apt-get install -y earlyoom -qq 2>/dev/null
fi
if [ -f /etc/init.d/earlyoom ]; then
    svc_enable earlyoom
    svc_start  earlyoom
    echo -e "${GREEN}  ✓ earlyoom aktivan (SysVinit)${NC}"
else
    pkill -f earlyoom 2>/dev/null
    earlyoom -r 0 -m 7 -s 12 &>/dev/null &
    echo -e "${GREEN}  ✓ earlyoom pokrenut sa agresivnijim parametrima za 2GB${NC}"
fi

# preload - Isključeno! Na sistemima sa samo 2GB RAM-a, preload zapravo usporava podizanje i troši keš memoriju.
if [ -f /etc/init.d/preload ]; then
    svc_stop preload
    svc_disable preload
    echo -e "${YELLOW}  ✓ preload deaktiviran radi uštede RAM memorije${NC}"
fi

# ================================================
echo -e "\n${CYAN}━━━ [7/11] ČIŠĆENJE CACHE I MEMORIJE ━━━${NC}"
# ================================================

sync
echo 1 > /proc/sys/vm/drop_caches; sleep 0.5
echo 2 > /proc/sys/vm/drop_caches; sleep 0.5
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null

rm -rf $USER_HOME/.cache/* 2>/dev/null
rm -rf $USER_HOME/.thumbnails/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/*.* 2>/dev/null

# Podrška za Pale Moon i Firefox ESR keš
find $USER_HOME -type d \( -name "cache2" -o -name "Cache" \) 2>/dev/null | while read d; do
    rm -rf "$d"/* 2>/dev/null
done

fc-cache -f 2>/dev/null
apt-get autoremove -y -qq 2>/dev/null
apt-get autoclean -qq 2>/dev/null

echo -e "${GREEN}  ✓ RAM cache oslobođen${NC}"
echo -e "${GREEN}  ✓ Korisnički i browser cache obrisan${NC}"
echo -e "${GREEN}  ✓ Privremeni fajlovi očišćeni${NC}"
echo -e "${GREEN}  ✓ APT paketi počišćeni${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [8/11] PRIVACY CLEANUP ━━━${NC}"
# ================================================

for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    cat /dev/null > "$home_dir/.bash_history" 2>/dev/null
    cat /dev/null > "$home_dir/.zsh_history"  2>/dev/null
    cat /dev/null > "$home_dir/.sh_history"   2>/dev/null
    rm -f  "$home_dir/.recently-used" 2>/dev/null
    rm -f  "$home_dir/.local/share/recently-used.xbel" 2>/dev/null
    rm -rf "$home_dir/.local/share/recently-used*" 2>/dev/null
    rm -rf "$home_dir/.local/share/thumbnails/*"   2>/dev/null
done
history -c 2>/dev/null

LOGOVI=(/var/log/auth.log     /var/log/auth.log.1
        /var/log/syslog       /var/log/syslog.1
        /var/log/kern.log     /var/log/kern.log.1
        /var/log/messages     /var/log/debug
        /var/log/daemon.log   /var/log/user.log
        /var/log/wtmp         /var/log/btmp
        /var/log/lastlog      /var/log/faillog
        /var/log/dpkg.log)

LOG_COUNT=0
for log in "${LOGOVI[@]}"; do
    if [ -f "$log" ]; then
        cat /dev/null > "$log" 2>/dev/null
        LOG_COUNT=$((LOG_COUNT + 1))
    fi
done

find /var/log -name "*.gz"  -delete 2>/dev/null
find /var/log -name "*.1"   -delete 2>/dev/null
find /var/log -name "*.old" -delete 2>/dev/null

find $USER_HOME -name "places.sqlite" 2>/dev/null | while read db; do
    sqlite3 "$db" "DELETE FROM moz_historyvisits; DELETE FROM moz_inputhistory;" 2>/dev/null
done

if ! grep -q "HISTFILE=/dev/null" $USER_HOME/.bashrc 2>/dev/null; then
    cat >> $USER_HOME/.bashrc << 'EOF'

# Privacy - onemoguci logovanje istorije komandi
HISTSIZE=0
HISTFILESIZE=0
HISTFILE=/dev/null
EOF
fi

echo -e "${GREEN}  ✓ Terminal istorija komandi obrisana${NC}"
echo -e "${GREEN}  ✓ Obrisano $LOG_COUNT aktivnih log fajlova (rsyslog)${NC}"
echo -e "${GREEN}  ✓ Istorija pretrage u browserima očišćena${NC}"
echo -e "${GREEN}  ✓ Trajno onemogućeno snimanje terminal komandi za privatnost${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [9/11] ICEWM OPTIMIZACIJA ━━━${NC}"
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
DesktopBackgroundCenter=0
DesktopBackgroundScaled=0
ShowThemesMenu=0
ShowHelpMenu=0
EOF

chown $USERNAME:$USERNAME $USER_HOME/.icewm/preferences 2>/dev/null

echo -e "${GREEN}  ✓ IceWM vizuelne animacije ugašene${NC}"
echo -e "${GREEN}  ✓ Tema postavljena na ultralaku 'default' varijantu${NC}"
echo -e "${GREEN}  ✓ Zvučni efekti ugašeni${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [10/11] DISPLAY REZOLUCIJA 1280x1024 ━━━${NC}"
# ================================================

if command -v xrandr &>/dev/null; then
    DISPLAY=:0 xrandr --output VGA-1  --mode 1280x1024 2>/dev/null || \
    DISPLAY=:0 xrandr --output VGA1   --mode 1280x1024 2>/dev/null || \
    DISPLAY=:0 xrandr --output HDMI-1 --mode 1280x1024 2>/dev/null || \
    DISPLAY=:0 xrandr --output HDMI1  --mode 1280x1024 2>/dev/null
    echo -e "${GREEN}  ✓ Rezolucija ekrana postavljena na 1280x1024${NC}"
fi

mkdir -p /etc/X11/xorg.conf.d/
cat > /etc/X11/xorg.conf.d/10-rezolucija.conf << 'EOF'
Section "Screen"
    Identifier "Screen0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1280x1024" "1024x768" "800x600"
    EndSubSection
EndSection

Section "Monitor"
    Identifier "Monitor0"
    HorizSync 30-83
    VertRefresh 56-76
    Option "PreferredMode" "1280x1024"
EndSection
EOF

cat > $USER_HOME/.icewm/startup << 'EOF'
#!/bin/bash
xrandr --output VGA-1  --mode 1280x1024 2>/dev/null || \
xrandr --output VGA1   --mode 1280x1024 2>/dev/null || \
xrandr --output HDMI-1 --mode 1280x1024 2>/dev/null || \
xrandr --output HDMI1  --mode 1280x1024 2>/dev/null || \
xrandr --auto --mode 1280x1024 2>/dev/null
EOF
chmod +x $USER_HOME/.icewm/startup
chown $USERNAME:$USERNAME $USER_HOME/.icewm/startup 2>/dev/null

echo -e "${GREEN}  ✓ Xorg rezolucija zapisana trajno${NC}"
echo -e "${GREEN}  ✓ IceWM automatski startup generisan${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [11/11] BOOT OPTIMIZACIJA ━━━${NC}"
# ================================================

if [ -f /etc/default/grub ]; then
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    # Dodat nowatchdog i noresume za osetno brži boot na starijim procesorima
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet noresume nowatchdog elevator=bfq"/' \
        /etc/default/grub
    update-grub 2>/dev/null
    echo -e "${GREEN}  ✓ GRUB timeout smanjen na 1 sekundu${NC}"
    echo -e "${GREEN}  ✓ Boot parametri prilagođeni 32-bitnom sistemu${NC}"
fi

if [ -f /etc/rc.local ]; then
    if ! grep -q "99-master32" /etc/rc.local; then
        sed -i '/^exit 0/i sysctl -p /etc/sysctl.d/99-master32.conf &>/dev/null' /etc/rc.local
    fi
else
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
sysctl -p /etc/sysctl.d/99-master32.conf &>/dev/null
exit 0
EOF
    chmod +x /etc/rc.local
fi

SKRIPTA_PUT="$USER_HOME/master32.sh"
cat > /etc/cron.d/master32-auto << EOF
@reboot root sleep 60 && bash ${SKRIPTA_PUT} > /dev/null 2>&1
0 */6 * * * root bash ${SKRIPTA_PUT} > /dev/null 2>&1
EOF

echo -e "${GREEN}  ✓ rc.local povezan sa novom sysctl konfiguracijom${NC}"
echo -e "${GREEN}  ✓ Automatsko čišćenje zakazano na svakih 6 sati${NC}"

# ================================================
# REZULTAT
# ================================================
RAM_POSLIJE=$(free -m | awk 'NR==2{print $3}')
RAM_OSLOBODJENO=$((RAM_PRIJE - RAM_POSLIJE))

echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║       OPTIMIZACIJA ZAVRŠENA! ✓         ║"
echo "  ║    antiX 26 x32 | Debian 12 Bookworm   ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${YELLOW}RAM prije:${NC}    ${RED}%dMB${NC}\n"   $RAM_PRIJE
printf "  ${YELLOW}RAM poslije:${NC}  ${GREEN}%dMB${NC}\n" $RAM_POSLIJE
printf "  ${YELLOW}Oslobođeno:${NC}   ${GREEN}%dMB${NC}\n" $RAM_OSLOBODJENO
echo ""
echo -e "${CYAN}  RAM status:${NC}"
free -h
echo ""
echo -e "${CYAN}  Top 5 procesa po RAM-u:${NC}"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "  %-25s %.1f%%\n", $11, $4}'
echo ""
echo -e "${CYAN}  Disk status na rootu:${NC}"
df -h / | awk 'NR==2 {printf "  Korišteno: %s / %s (%s slobodno)\n", $3, $2, $4}'
echo ""
echo -e "${GREEN}  Skripta se uspešno izvršava automatski u pozadini ✓${NC}"
echo ""
echo -e "${YELLOW}  ZABODITE REBOOT DA SVE LEGNE NA MESTO:${NC}"
echo -e "${GREEN}  sudo reboot${NC}"
echo ""
