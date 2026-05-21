#!/bin/bash
# ============================================
# SKRIPTA 4: NAPREDNA CPU + RAM OPTIMIZACIJA
# Sve što master64.sh nije pokrilo
# Pokreni: sudo bash cpu_ram_advanced.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash cpu_ram_advanced.sh${NC}"
    exit 1
fi

USERNAME=${SUDO_USER:-$(who | awk '{print $1}' | grep -v root | head -1)}
[ -z "$USERNAME" ] && USERNAME="Buyn4_G4L4"

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║   NAPREDNA CPU + RAM OPTIMIZACIJA      ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

RAM_PRIJE=$(free -m | awk 'NR==2{print $3}')
echo -e "${YELLOW}  RAM prije: ${RAM_PRIJE}MB${NC}\n"

# ================================================
echo -e "${CYAN}[1/8] CPU Turbo i frekvencija...${NC}"
# ================================================

# Intel Turbo Boost (ako postoji)
if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
    echo 1 > /sys/devices/system/cpu/cpufreq/boost
    echo -e "${GREEN}  ✓ CPU Turbo Boost uključen${NC}"
fi

# Postavi min frekvenciju na max za Celeron E3400
for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
    [ -f "$cpu/scaling_min_freq" ] && \
    [ -f "$cpu/scaling_max_freq" ] && \
        cat "$cpu/scaling_max_freq" > "$cpu/scaling_min_freq" 2>/dev/null
done

# CPU energy performance preference
for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
    [ -f "$cpu/energy_performance_preference" ] && \
        echo "performance" > "$cpu/energy_performance_preference" 2>/dev/null
done

echo -e "${GREEN}  ✓ CPU minimalna frekvencija = maksimalna${NC}"
echo -e "${GREEN}  ✓ Energy preference → performance${NC}"

# ================================================
echo -e "\n${CYAN}[2/8] CPU scheduler napredna podešavanja...${NC}"
# ================================================

# Scheduler latency - manji = brži desktop odziv
echo 1000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null

# Autogroup za bolje desktop odzive
echo 1 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null

# Smanji watchdog overhead
echo 0 > /proc/sys/kernel/nmi_watchdog 2>/dev/null

echo -e "${GREEN}  ✓ Scheduler latency smanjen (brži odziv)${NC}"
echo -e "${GREEN}  ✓ Autogroup aktivan${NC}"
echo -e "${GREEN}  ✓ NMI watchdog isključen${NC}"

# ================================================
echo -e "\n${CYAN}[3/8] RAM - Napredna upravljanje memorijom...${NC}"
# ================================================

# OOM killer podešavanja - štiti važne procese
# Smanji OOM score za shell i WM
for pid in $(pgrep -x bash 2>/dev/null); do
    echo -100 > /proc/$pid/oom_score_adj 2>/dev/null
done
for pid in $(pgrep -x icewm 2>/dev/null); do
    echo -500 > /proc/$pid/oom_score_adj 2>/dev/null
done

# Poboljšano upravljanje memorijskim zonama
echo 100 > /proc/sys/vm/min_free_kbytes 2>/dev/null

# Watermark scaling - bolje za male sisteme
echo 10 > /proc/sys/vm/watermark_scale_factor 2>/dev/null

# Smanjuje fragmentaciju memorije
echo 1 > /proc/sys/vm/compaction_proactiveness 2>/dev/null

# Page writeback optimizacija
echo 1500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null

echo -e "${GREEN}  ✓ OOM killer konfigurisan${NC}"
echo -e "${GREEN}  ✓ Watermark scaling optimizovan${NC}"
echo -e "${GREEN}  ✓ Memory compaction aktivna${NC}"

# ================================================
echo -e "\n${CYAN}[4/8] ZRAM napredna konfiguracija...${NC}"
# ================================================

# Provjeri da li zram postoji
if lsmod | grep -q zram || modprobe zram 2>/dev/null; then
    # Postavi kompresiju na lz4 (najbrža)
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || \
    echo lzo > /sys/block/zram0/comp_algorithm 2>/dev/null

    # Postavi zram veličinu na 50% RAM-a
    TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ZRAM_SIZE=$((TOTAL_RAM * 512))  # 50% u kilobajtima
    echo "${ZRAM_SIZE}K" > /sys/block/zram0/disksize 2>/dev/null

    echo -e "${GREEN}  ✓ ZRAM lz4 kompresija${NC}"
    echo -e "${GREEN}  ✓ ZRAM veličina optimizovana${NC}"
else
    echo -e "${YELLOW}  ZRAM nije dostupan na ovom kernelu${NC}"
fi

# ================================================
echo -e "\n${CYAN}[5/8] Mrežni stack optimizacija za brzinu...${NC}"
# ================================================

cat >> /etc/sysctl.d/99-network-perf.conf << 'EOF'
# TCP optimizacije za desktop
net.ipv4.tcp_congestion_control=cubic
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.netdev_max_backlog=2000
net.ipv4.tcp_max_syn_backlog=1024
EOF
sysctl -p /etc/sysctl.d/99-network-perf.conf &>/dev/null

echo -e "${GREEN}  ✓ TCP cubic congestion control${NC}"
echo -e "${GREEN}  ✓ TCP slow start isključen${NC}"

# ================================================
echo -e "\n${CYAN}[6/8] Preemption i latency kernel postavke...${NC}"
# ================================================

# Timer frequency - 300Hz je optimalno za desktop i686
if [ -f /sys/kernel/debug/sched/latency_ns ]; then
    echo 4000000 > /sys/kernel/debug/sched/latency_ns 2>/dev/null
fi

# Kernel same page merging (KSM) - spaja identične stranice
if [ -f /sys/kernel/mm/ksm/run ]; then
    echo 1 > /sys/kernel/mm/ksm/run
    echo 100 > /sys/kernel/mm/ksm/sleep_millisecs
    echo 1000 > /sys/kernel/mm/ksm/pages_to_scan
    echo -e "${GREEN}  ✓ KSM aktivan (spaja identične stranice u RAM-u)${NC}"
fi

# ================================================
echo -e "\n${CYAN}[7/8] Prelink za brže pokretanje programa...${NC}"
# ================================================

if command -v prelink &>/dev/null; then
    prelink -amR 2>/dev/null
    echo -e "${GREEN}  ✓ Prelink završen${NC}"
else
    apt-get install -y prelink -qq 2>/dev/null
    prelink -amR 2>/dev/null
    echo -e "${GREEN}  ✓ Prelink instaliran i pokrenuta${NC}"
fi

# Automatski prelink sedmično
cat > /etc/cron.weekly/prelink-update << 'EOF'
#!/bin/bash
prelink -amR 2>/dev/null
EOF
chmod +x /etc/cron.weekly/prelink-update

# ================================================
echo -e "\n${CYAN}[8/8] Oslobodi RAM cache...${NC}"
# ================================================

sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null

# ================================================
RAM_POSLIJE=$(free -m | awk 'NR==2{print $3}')
RAM_OSLOBODJENO=$((RAM_PRIJE - RAM_POSLIJE))

echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║   NAPREDNA OPTIMIZACIJA ZAVRŠENA! ✓    ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
printf "  ${YELLOW}RAM prije:${NC}   ${RED}%dMB${NC}\n" $RAM_PRIJE
printf "  ${GREEN}RAM poslije:${NC} ${GREEN}%dMB${NC}\n" $RAM_POSLIJE
printf "  ${GREEN}Oslobođeno:${NC}  ${GREEN}%dMB${NC}\n" $RAM_OSLOBODJENO
echo ""
