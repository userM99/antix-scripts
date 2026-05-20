#!/bin/bash
# ============================================
# SYSINFO - Pregled sistema antiX 23.2 x64
# RAM | CPU | GPU | Rezolucija | Temperature
# Pokreni: bash sysinfo.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# ---- Instalacija alata ako nedostaju ----
POTREBNO=0
for alat in lm-sensors glxinfo; do
    if ! command -v sensors &>/dev/null && [ "$alat" = "lm-sensors" ]; then
        POTREBNO=1
    fi
    if ! command -v glxinfo &>/dev/null && [ "$alat" = "glxinfo" ]; then
        POTREBNO=1
    fi
done

if [ "$POTREBNO" = "1" ]; then
    echo -e "${YELLOW}Instalacija potrebnih alata...${NC}"
    sudo apt-get install -y lm-sensors mesa-utils -qq 2>/dev/null
    sudo sensors-detect --auto &>/dev/null 2>&1
fi

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║        SISTEM INFO - antiX 23.2 x64          ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ================================================
# RAM
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │               💾  RAM                   │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

RAM_UKUPNO=$(free -m | awk 'NR==2{print $2}')
RAM_ZAUZETO=$(free -m | awk 'NR==2{print $3}')
RAM_SLOBODNO=$(free -m | awk 'NR==2{print $4}')
RAM_CACHE=$(free -m | awk 'NR==2{print $6}')
RAM_PROCENAT=$(( RAM_ZAUZETO * 100 / RAM_UKUPNO ))

# Progres bar za RAM
BAR_PUNI=$(( RAM_PROCENAT / 5 ))
BAR_PRAZNI=$(( 20 - BAR_PUNI ))
BAR=""
for i in $(seq 1 $BAR_PUNI);  do BAR="${BAR}█"; done
for i in $(seq 1 $BAR_PRAZNI); do BAR="${BAR}░"; done

if   [ $RAM_PROCENAT -lt 50 ]; then BOJA_RAM=$GREEN
elif [ $RAM_PROCENAT -lt 80 ]; then BOJA_RAM=$YELLOW
else BOJA_RAM=$RED; fi

printf "  ${WHITE}Ukupno:${NC}    %4d MB\n" $RAM_UKUPNO
printf "  ${WHITE}Zauzeto:${NC}   ${BOJA_RAM}%4d MB (%d%%)${NC}\n" $RAM_ZAUZETO $RAM_PROCENAT
printf "  ${WHITE}Slobodno:${NC}  ${GREEN}%4d MB${NC}\n" $RAM_SLOBODNO
printf "  ${WHITE}Cache:${NC}     %4d MB\n" $RAM_CACHE
echo -e "  ${WHITE}Korištenost:${NC} [${BOJA_RAM}${BAR}${NC}] ${BOJA_RAM}${RAM_PROCENAT}%%${NC}"

# SWAP
SWAP_UKUPNO=$(free -m | awk 'NR==3{print $2}')
SWAP_ZAUZETO=$(free -m | awk 'NR==3{print $3}')
if [ "$SWAP_UKUPNO" -gt 0 ]; then
    printf "  ${WHITE}Swap:${NC}      %d MB / %d MB zauzeto\n" $SWAP_ZAUZETO $SWAP_UKUPNO
else
    echo -e "  ${WHITE}Swap:${NC}      ${GREEN}isključen ✓${NC}"
fi

echo ""

# ================================================
# CPU
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │               🔲  CPU                   │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')
CPU_JEZGRE=$(grep -c "processor" /proc/cpuinfo)

# CPU korištenost - uzmi uzorak 0.5s
CPU_UZORAK=$(grep "^cpu " /proc/stat)
sleep 0.5
CPU_UZORAK2=$(grep "^cpu " /proc/stat)

CPU1=(${CPU_UZORAK})
CPU2=(${CPU_UZORAK2})

IDLE1=${CPU1[4]}
TOTAL1=0
for v in "${CPU1[@]:1}"; do TOTAL1=$((TOTAL1 + v)); done

IDLE2=${CPU2[4]}
TOTAL2=0
for v in "${CPU2[@]:1}"; do TOTAL2=$((TOTAL2 + v)); done

DIFF_IDLE=$(( IDLE2 - IDLE1 ))
DIFF_TOTAL=$(( TOTAL2 - TOTAL1 ))
if [ $DIFF_TOTAL -gt 0 ]; then
    CPU_POSTO=$(( (DIFF_TOTAL - DIFF_IDLE) * 100 / DIFF_TOTAL ))
else
    CPU_POSTO=0
fi

# Frekvencija po jezgrama
FREKVENCIJE=()
MAX_FREQ=0
for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [ -f "$f" ] || continue
    FREQ_KHZ=$(cat "$f" 2>/dev/null)
    FREQ_MHZ=$(( FREQ_KHZ / 1000 ))
    FREKVENCIJE+=($FREQ_MHZ)
    [ $FREQ_MHZ -gt $MAX_FREQ ] && MAX_FREQ=$FREQ_MHZ
done

# Max dostupna frekvencija
MAX_DOSTUPNA_KHZ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
MAX_DOSTUPNA=$(( MAX_DOSTUPNA_KHZ / 1000 ))
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)

# Boja za CPU %
if   [ $CPU_POSTO -lt 40 ]; then BOJA_CPU=$GREEN
elif [ $CPU_POSTO -lt 75 ]; then BOJA_CPU=$YELLOW
else BOJA_CPU=$RED; fi

echo -e "  ${WHITE}Model:${NC}     $CPU_MODEL"
printf  "  ${WHITE}Jezgre:${NC}    %d\n" $CPU_JEZGRE
printf  "  ${WHITE}Korištenost:${NC} ${BOJA_CPU}%d%%${NC}\n" $CPU_POSTO
printf  "  ${WHITE}Freq max:${NC}  %d MHz (dostupno: %d MHz)\n" $MAX_FREQ $MAX_DOSTUPNA
echo -e "  ${WHITE}Governor:${NC}  ${GREEN}$GOVERNOR${NC}"

# Frekvencije po jezgrama
echo -n "  ${WHITE}Po jezgrama:${NC}"
IDX=0
for F in "${FREKVENCIJE[@]}"; do
    echo -n " cpu${IDX}:${F}MHz"
    IDX=$((IDX+1))
done
echo ""

echo ""

# ================================================
# GPU
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │            🎮  GPU (AMD Radeon)          │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

GPU_MODEL=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
if [ -z "$GPU_MODEL" ]; then
    GPU_MODEL="Nije detektovano (lspci nedostaje)"
fi
echo -e "  ${WHITE}Model:${NC}     $GPU_MODEL"

# Driver
GPU_DRIVER=$(lspci -k 2>/dev/null | grep -A3 -i "vga\|3d\|display" | grep "Kernel driver" | head -1 | awk '{print $NF}')
[ -n "$GPU_DRIVER" ] && echo -e "  ${WHITE}Driver:${NC}    $GPU_DRIVER"

# VRAM - pokušaj nekoliko metoda
VRAM=""

# Metoda 1: DRM sysfs (AMD radeon/amdgpu)
for card in /sys/class/drm/card*/device; do
    if [ -f "$card/mem_info_vram_total" ]; then
        VRAM_B=$(cat "$card/mem_info_vram_total" 2>/dev/null)
        VRAM_MB=$(( VRAM_B / 1024 / 1024 ))
        VRAM="${VRAM_MB} MB"
        break
    fi
done

# Metoda 2: glxinfo
if [ -z "$VRAM" ] && command -v glxinfo &>/dev/null; then
    VRAM_GL=$(DISPLAY=:0 glxinfo 2>/dev/null | grep -i "video memory\|dedicated video" | head -1 | grep -oP '\d+')
    [ -n "$VRAM_GL" ] && VRAM="${VRAM_GL} MB"
fi

# Metoda 3: lspci verbose
if [ -z "$VRAM" ]; then
    VRAM_LSPCI=$(lspci -v 2>/dev/null | grep -A20 -i "vga" | grep -i "size=" | grep -i "prefetchable" | grep -oP '\d+[KMG]' | head -1)
    [ -n "$VRAM_LSPCI" ] && VRAM="$VRAM_LSPCI (aprox.)"
fi

if [ -n "$VRAM" ]; then
    echo -e "  ${WHITE}VRAM:${NC}      ${GREEN}$VRAM${NC}"
else
    echo -e "  ${WHITE}VRAM:${NC}      ${YELLOW}nije dostupno direktno${NC}"
fi

# OpenGL verzija
if command -v glxinfo &>/dev/null; then
    OPENGL=$(DISPLAY=:0 glxinfo 2>/dev/null | grep "OpenGL version" | head -1 | cut -d: -f2 | sed 's/^ //')
    [ -n "$OPENGL" ] && echo -e "  ${WHITE}OpenGL:${NC}    $OPENGL"
fi

# GPU DPM nivo
for card in /sys/class/drm/card*/device; do
    if [ -f "$card/power_dpm_force_performance_level" ]; then
        DPM=$(cat "$card/power_dpm_force_performance_level" 2>/dev/null)
        echo -e "  ${WHITE}DPM nivo:${NC}  ${GREEN}$DPM${NC}"
        break
    fi
done

echo ""

# ================================================
# REZOLUCIJA
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │            🖥️   DISPLAY                  │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
    xrandr 2>/dev/null | grep " connected" | while read LINE; do
        OUTPUT=$(echo "$LINE" | awk '{print $1}')
        RES=$(echo "$LINE" | grep -oP '\d+x\d+\+\d+\+\d+' | head -1 | grep -oP '^\d+x\d+')
        FIZICKA=$(echo "$LINE" | grep -oP '\d+mm x \d+mm' | head -1)
        if [ -n "$RES" ]; then
            echo -e "  ${WHITE}Izlaz:${NC}     $OUTPUT"
            echo -e "  ${WHITE}Rezolucija:${NC} ${GREEN}$RES${NC}"
            [ -n "$FIZICKA" ] && echo -e "  ${WHITE}Fizička:${NC}   $FIZICKA"
        fi
    done
    # Refresh rate
    REFRESH=$(xrandr 2>/dev/null | grep "^\s" | grep "*" | awk '{
        for(i=1;i<=NF;i++) if($i ~ /\*/) { gsub(/[^0-9.]/,"",$i); print $i; exit }
    }' | head -1)
    [ -n "$REFRESH" ] && echo -e "  ${WHITE}Refresh:${NC}   ${REFRESH} Hz"
elif [ -f /etc/X11/xorg.conf.d/10-rezolucija.conf ]; then
    RES_CONF=$(grep -i "Modes" /etc/X11/xorg.conf.d/10-rezolucija.conf | head -1 | grep -oP '"\d+x\d+"' | head -1 | tr -d '"')
    echo -e "  ${WHITE}Rezolucija:${NC} ${GREEN}$RES_CONF${NC} (iz xorg.conf)"
else
    echo -e "  ${YELLOW}  X server nije aktivan (pokreni iz X sesije)${NC}"
fi

echo ""

# ================================================
# TEMPERATURE
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │           🌡️   TEMPERATURE               │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

TEMP_NADJENO=0

# CPU temperatura iz lm-sensors
if command -v sensors &>/dev/null; then
    SENSORS_OUT=$(sensors 2>/dev/null)
    if [ -n "$SENSORS_OUT" ]; then
        echo -e "  ${WHITE}── lm-sensors ──${NC}"
        echo "$SENSORS_OUT" | grep -E "Core|temp|CPU|Package|Tdie|Tctl" | \
        grep -v "^$" | head -12 | while read LINE; do
            NAZIV=$(echo "$LINE" | cut -d: -f1 | sed 's/^  *//')
            VRIJEDNOST=$(echo "$LINE" | cut -d: -f2 | awk '{print $1}')
            TEMP_NUM=$(echo "$VRIJEDNOST" | grep -oP '[\d.]+' | head -1)
            if [ -n "$TEMP_NUM" ]; then
                TEMP_INT=${TEMP_NUM%.*}
                if   [ "$TEMP_INT" -lt 50 ] 2>/dev/null; then BOJA_T=$GREEN
                elif [ "$TEMP_INT" -lt 70 ] 2>/dev/null; then BOJA_T=$YELLOW
                else BOJA_T=$RED; fi
                printf "  ${WHITE}%-20s${NC} ${BOJA_T}%s°C${NC}\n" "$NAZIV:" "$TEMP_INT"
                TEMP_NADJENO=1
            fi
        done
    fi
fi

# GPU temperatura iz DRM hwmon (AMD radeon/amdgpu)
GPU_TEMP_NADJENO=0
for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
    [ -f "$hwmon" ] || continue
    GPU_TEMP_RAW=$(cat "$hwmon" 2>/dev/null)
    GPU_TEMP=$(( GPU_TEMP_RAW / 1000 ))
    if [ "$GPU_TEMP" -gt 0 ] 2>/dev/null; then
        if   [ $GPU_TEMP -lt 60 ]; then BOJA_G=$GREEN
        elif [ $GPU_TEMP -lt 80 ]; then BOJA_G=$YELLOW
        else BOJA_G=$RED; fi
        echo -e "  ${WHITE}── GPU (DRM hwmon) ──${NC}"
        printf "  ${WHITE}%-20s${NC} ${BOJA_G}%d°C${NC}\n" "GPU temp:" "$GPU_TEMP"
        GPU_TEMP_NADJENO=1
        TEMP_NADJENO=1
        break
    fi
done

# /sys/class/thermal (alternativa)
if [ -d /sys/class/thermal ]; then
    echo -e "  ${WHITE}── Thermal zones ──${NC}"
    for zone in /sys/class/thermal/thermal_zone*/; do
        [ -f "${zone}temp" ] || continue
        TEMP_RAW=$(cat "${zone}temp" 2>/dev/null)
        TEMP_C=$(( TEMP_RAW / 1000 ))
        TIP=$(cat "${zone}type" 2>/dev/null)
        [ "$TEMP_C" -lt 1 ]   2>/dev/null && continue
        [ "$TEMP_C" -gt 120 ] 2>/dev/null && continue
        if   [ $TEMP_C -lt 50 ]; then BOJA_Z=$GREEN
        elif [ $TEMP_C -lt 70 ]; then BOJA_Z=$YELLOW
        else BOJA_Z=$RED; fi
        printf "  ${WHITE}%-20s${NC} ${BOJA_Z}%d°C${NC}\n" "$TIP:" "$TEMP_C"
        TEMP_NADJENO=1
    done
fi

if [ "$TEMP_NADJENO" = "0" ]; then
    echo -e "  ${YELLOW}  Temperature nisu dostupne.${NC}"
    echo -e "  ${YELLOW}  Pokreni: sudo apt-get install lm-sensors${NC}"
    echo -e "  ${YELLOW}  Zatim:   sudo sensors-detect${NC}"
fi

echo ""

# ================================================
# UPTIME & PROCESI
# ================================================
echo -e "${CYAN}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │          📊  SISTEM PREGLED              │${NC}"
echo -e "${CYAN}  └─────────────────────────────────────────┘${NC}"

UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | cut -d, -f1)
LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
PROCESI=$(ps aux | wc -l)
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

echo -e "  ${WHITE}Hostname:${NC}  $HOSTNAME"
echo -e "  ${WHITE}Kernel:${NC}    $KERNEL"
echo -e "  ${WHITE}Uptime:${NC}    $UPTIME"
echo -e "  ${WHITE}Load avg:${NC}  $LOAD"
echo -e "  ${WHITE}Procesi:${NC}   $((PROCESI - 1))"

echo ""
echo -e "${CYAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Top 5 procesa po RAM-u:${NC}"
ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
    printf "  \033[1;37m%-28s\033[0m RAM:\033[0;32m%4.1f%%\033[0m  CPU:\033[0;33m%4.1f%%\033[0m\n",
    $11, $4, $3
}'

echo ""
echo -e "${CYAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Disk:${NC}"
df -h 2>/dev/null | grep -v "tmpfs\|udev\|loop" | awk '
NR==1 { printf "  \033[1;37m%-20s %6s %6s %6s %5s\033[0m\n", $1,$2,$3,$4,$5 }
NR>1  { printf "  %-20s %6s %6s %6s %5s\n", $1,$2,$3,$4,$5 }
'

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║              Provjera završena ✓             ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════╝${NC}"
echo ""
