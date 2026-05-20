#!/bin/bash
# ============================================
# FINALNI BACKUP - antiX 32bit → 64bit
# Pokreni: sudo bash backup_final.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- PROVJERE ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash backup_final.sh${NC}"
    exit 1
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
    echo -e "${YELLOW}Ne mogu automatski naći korisnika. Upiši username:${NC}"
    USERNAME="Buyn4_G4L4"
fi

USER_HOME="/home/$USERNAME"
BACKUP_DIR="/backup_sistem"

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     FINALNI BACKUP SISTEMA           ║"
echo "  ║     antiX 32-bit → 64-bit            ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Korisnik: $USERNAME${NC}"
echo -e "${YELLOW}  Home:     $USER_HOME${NC}"
echo -e "${YELLOW}  Backup:   $BACKUP_DIR${NC}"
echo ""

# Provjeri home folder
if [ ! -d "$USER_HOME" ]; then
    echo -e "${RED}Home folder $USER_HOME ne postoji!${NC}"
    echo -e "${YELLOW}Dostupni korisnici:${NC}"
    ls /home/
    echo -e "${YELLOW}Upiši tačan username:${NC}"
    USERNAME="Buyn4_G4L4"
    USER_HOME="/home/$USERNAME"
fi

# Provjeri slobodan prostor
FREE_KB=$(df / | awk 'NR==2{print $4}')
if [ "$FREE_KB" -lt 3000000 ]; then
    echo -e "${RED}Nedovoljno prostora! Treba min 3GB${NC}"
    df -h /
    exit 1
fi

echo -e "${GREEN}  ✓ Korisnik: $USERNAME${NC}"
echo -e "${GREEN}  ✓ Slobodan prostor: $(df -h / | awk 'NR==2{print $4}')${NC}"
echo ""
echo -e "${YELLOW}  Počinjemo za 3 sekunde...${NC}"
sleep 3

# Napravi strukturu i sačuvaj username
mkdir -p $BACKUP_DIR/{paketi,apt,configs,home,mreza,skripte,kali}
echo "$USERNAME" > $BACKUP_DIR/USERNAME.txt

# ================================================
echo -e "\n${CYAN}[1/7] Lista paketa...${NC}"
# ================================================

dpkg --get-selections > $BACKUP_DIR/paketi/svi_paketi.txt
apt-mark showmanual > $BACKUP_DIR/paketi/rucno_instalirani.txt
pip3 list 2>/dev/null > $BACKUP_DIR/paketi/pip3_paketi.txt

# Kali alati
dpkg --get-selections | grep -iE \
"nmap|metasploit|aircrack|wireshark|hydra|sqlmap|\
nikto|hashcat|john|masscan|netcat|dirb|gobuster|\
wfuzz|ffuf|amass|recon|maltego|theharvester|\
dnsenum|dnsrecon|fierce|sublist3r|enum4linux|\
smbclient|impacket|responder|crackmapexec|\
evil-winrm|beef|setoolkit|msfconsole|\
openvas|autopsy|volatility|binwalk|\
radare2|ghidra|tcpdump|tshark|ettercap|\
bettercap|proxychains|tor|wpscan|\
exploitdb|searchsploit|kali|python3-impacket|\
burp|zaproxy|dirbuster|feroxbuster" \
> $BACKUP_DIR/kali/kali_alati.txt

echo -e "${GREEN}  ✓ $(wc -l < $BACKUP_DIR/paketi/svi_paketi.txt) paketa sačuvano${NC}"
echo -e "${GREEN}  ✓ $(wc -l < $BACKUP_DIR/kali/kali_alati.txt) Kali alata sačuvano${NC}"

# ================================================
echo -e "\n${CYAN}[2/7] APT repozitoriji i ključevi...${NC}"
# ================================================

cp /etc/apt/sources.list $BACKUP_DIR/apt/
cp -r /etc/apt/sources.list.d/ $BACKUP_DIR/apt/ 2>/dev/null
cp -r /etc/apt/trusted.gpg.d/ $BACKUP_DIR/apt/ 2>/dev/null
apt-key exportall > $BACKUP_DIR/apt/apt_keys.gpg 2>/dev/null

echo -e "${GREEN}  ✓ APT sources sačuvani${NC}"
echo -e "${GREEN}  ✓ GPG ključevi sačuvani${NC}"

# ================================================
echo -e "\n${CYAN}[3/7] Home folder i konfiguracije...${NC}"
# ================================================

# Kopiraj home bez cache i iso fajlova
rsync -a \
    --exclude='.cache' \
    --exclude='*.iso' \
    --exclude='*.tmp' \
    $USER_HOME/ $BACKUP_DIR/home/ 2>/dev/null

# Shell konfiguracije
for cfg in .bashrc .bash_profile .zshrc .profile \
           .vimrc .gitconfig .tmux.conf; do
    [ -f "$USER_HOME/$cfg" ] && \
        cp "$USER_HOME/$cfg" $BACKUP_DIR/configs/ 2>/dev/null
done

# IceWM tema i postavke
[ -d "$USER_HOME/.icewm" ] && \
    cp -r "$USER_HOME/.icewm" $BACKUP_DIR/configs/

# .config folder
[ -d "$USER_HOME/.config" ] && \
    cp -r "$USER_HOME/.config" $BACKUP_DIR/configs/

# SSH ključevi
if [ -d "$USER_HOME/.ssh" ]; then
    cp -r "$USER_HOME/.ssh" $BACKUP_DIR/configs/
    chmod 700 $BACKUP_DIR/configs/.ssh 2>/dev/null
    echo -e "${GREEN}  ✓ SSH ključevi sačuvani${NC}"
fi

echo -e "${GREEN}  ✓ Home folder sačuvan${NC}"
echo -e "${GREEN}  ✓ Konfiguracije sačuvane${NC}"

# ================================================
echo -e "\n${CYAN}[4/7] Mrežne postavke...${NC}"
# ================================================

cp /etc/hosts $BACKUP_DIR/mreza/ 2>/dev/null
cp /etc/hostname $BACKUP_DIR/mreza/ 2>/dev/null
cp /etc/resolv.conf $BACKUP_DIR/mreza/ 2>/dev/null
cp -r /etc/network/ $BACKUP_DIR/mreza/ 2>/dev/null

echo -e "${GREEN}  ✓ Mrežne postavke sačuvane${NC}"

# ================================================
echo -e "\n${CYAN}[5/7] Sistemske konfiguracije...${NC}"
# ================================================

cp /etc/fstab $BACKUP_DIR/configs/ 2>/dev/null
cp -r /etc/sysctl.d/ $BACKUP_DIR/configs/ 2>/dev/null
cp /etc/sysctl.conf $BACKUP_DIR/configs/ 2>/dev/null
cp /etc/default/grub $BACKUP_DIR/configs/ 2>/dev/null
cp -r /etc/ufw/ $BACKUP_DIR/configs/ 2>/dev/null
cp -r /etc/modprobe.d/ $BACKUP_DIR/configs/ 2>/dev/null
cp -r /etc/fail2ban/ $BACKUP_DIR/configs/ 2>/dev/null

echo -e "${GREEN}  ✓ Sistemske konfiguracije sačuvane${NC}"

# ================================================
echo -e "\n${CYAN}[6/7] Wordliste i Kali resursi...${NC}"

if [ -d "/usr/share/wordlists" ]; then
    cp -r /usr/share/wordlists/ $BACKUP_DIR/kali/
    echo -e "${GREEN}  ✓ Wordlists sačuvane${NC}"
else
    echo -e "${YELLOW}  - Wordlists nisu pronađene${NC}"
fi

if [ -d "/usr/share/seclists" ]; then
    cp -r /usr/share/seclists/ $BACKUP_DIR/kali/
    echo -e "${GREEN}  ✓ SecLists sačuvane${NC}"
else
    echo -e "${YELLOW}  - SecLists nisu pronađene${NC}"
fi

echo -e "\n${CYAN}[7/7] Skripte...${NC}"
# ================================================

find $USER_HOME -maxdepth 2 -name "*.sh" \
    -exec cp {} $BACKUP_DIR/skripte/ \; 2>/dev/null

echo -e "${GREEN}  ✓ Skripte sačuvane${NC}"

# ================================================
echo -e "\n${CYAN}[7/7] Pravljenje VRATI_SVE.sh...${NC}"
# ================================================

cat > $BACKUP_DIR/VRATI_SVE.sh << 'RESTORE'
#!/bin/bash
# ============================================
# RESTORE SKRIPTA
# Pokreni nakon 64-bit instalacije:
# sudo bash /backup_sistem/VRATI_SVE.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash /backup_sistem/VRATI_SVE.sh${NC}"
    exit 1
fi

BACKUP_DIR="/backup_sistem"

# Učitaj sačuvani username
if [ -f "$BACKUP_DIR/USERNAME.txt" ]; then
    OLD_USERNAME=$(cat $BACKUP_DIR/USERNAME.txt)
else
    echo -e "${YELLOW}Upiši username sa starog sistema:${NC}"
    read OLD_USERNAME
fi

# Nađi novog korisnika
if [ -n "$SUDO_USER" ]; then
    NEW_USERNAME="$SUDO_USER"
else
    echo -e "${YELLOW}Upiši username novog sistema:${NC}"
    read NEW_USERNAME
fi

NEW_HOME="/home/$NEW_USERNAME"

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║         RESTORE SISTEMA              ║"
echo "  ║         antiX 64-bit                 ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Stari user: $OLD_USERNAME${NC}"
echo -e "${YELLOW}  Novi user:  $NEW_USERNAME${NC}"
echo -e "${YELLOW}  Nova home:  $NEW_HOME${NC}"
echo ""
sleep 2

# [1] APT sources
echo -e "${CYAN}[1/6] Vraćanje APT repozitorija...${NC}"
cp $BACKUP_DIR/apt/sources.list /etc/apt/ 2>/dev/null
cp -r $BACKUP_DIR/apt/sources.list.d/* /etc/apt/sources.list.d/ 2>/dev/null
cp -r $BACKUP_DIR/apt/trusted.gpg.d/* /etc/apt/trusted.gpg.d/ 2>/dev/null
apt-key add $BACKUP_DIR/apt/apt_keys.gpg 2>/dev/null
apt-get update -qq
echo -e "${GREEN}  ✓ APT sources vraćeni${NC}"

# [2] Reinstaliraj pakete
echo -e "\n${CYAN}[2/6] Reinstalacija paketa (može trajati dugo)...${NC}"
echo -e "${YELLOW}  Reinstalira sve pakete uključujući Kali alate...${NC}"
dpkg --set-selections < $BACKUP_DIR/paketi/svi_paketi.txt 2>/dev/null
apt-get dselect-upgrade -y 2>/dev/null
echo -e "${GREEN}  ✓ Paketi reinstalirani${NC}"

# [3] Konfiguracije
echo -e "\n${CYAN}[3/6] Vraćanje konfiguracija...${NC}"
for cfg in .bashrc .bash_profile .zshrc .profile \
           .vimrc .gitconfig .tmux.conf; do
    [ -f "$BACKUP_DIR/configs/$cfg" ] && \
        cp "$BACKUP_DIR/configs/$cfg" $NEW_HOME/ 2>/dev/null
done

[ -d "$BACKUP_DIR/configs/.icewm" ] && \
    cp -r $BACKUP_DIR/configs/.icewm $NEW_HOME/
[ -d "$BACKUP_DIR/configs/.config" ] && \
    cp -r $BACKUP_DIR/configs/.config $NEW_HOME/
[ -d "$BACKUP_DIR/configs/.ssh" ] && \
    cp -r $BACKUP_DIR/configs/.ssh $NEW_HOME/ && \
    chmod 700 $NEW_HOME/.ssh && \
    chmod 600 $NEW_HOME/.ssh/* 2>/dev/null
echo -e "${GREEN}  ✓ Konfiguracije vraćene${NC}"

# [4] Home folder
echo -e "\n${CYAN}[4/6] Vraćanje home foldera...${NC}"
rsync -a \
    --exclude='.cache' \
    $BACKUP_DIR/home/ $NEW_HOME/ 2>/dev/null
echo -e "${GREEN}  ✓ Home folder vraćen${NC}"

# [5] Mrežne postavke
echo -e "\n${CYAN}[5/6] Vraćanje mrežnih postavki...${NC}"
cp $BACKUP_DIR/mreza/hosts /etc/hosts 2>/dev/null
cp $BACKUP_DIR/mreza/resolv.conf /etc/resolv.conf 2>/dev/null
echo -e "${GREEN}  ✓ Mreža vraćena${NC}"

# [6] Skripte
echo -e "\n${CYAN}[6/6] Vraćanje skripti...${NC}"
cp $BACKUP_DIR/skripte/*.sh $NEW_HOME/ 2>/dev/null
chmod +x $NEW_HOME/*.sh 2>/dev/null
echo -e "${GREEN}  ✓ Skripte vraćene${NC}"

# Postavi vlasništvo
chown -R $NEW_USERNAME:$NEW_USERNAME $NEW_HOME/ 2>/dev/null

echo -e "\n${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║       RESTORE ZAVRŠEN! ✓             ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Sljedeći korak — pokreni optimizaciju:${NC}"
echo -e "${GREEN}  sudo bash ~/master64.sh${NC}"
echo ""
RESTORE

chmod +x $BACKUP_DIR/VRATI_SVE.sh
echo -e "${GREEN}  ✓ VRATI_SVE.sh napravljena${NC}"

# ================================================
# IZVJEŠTAJ
# ================================================
BACKUP_SIZE=$(du -sh $BACKUP_DIR | cut -f1)

echo -e "\n${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║         BACKUP ZAVRŠEN! ✓            ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${YELLOW}Lokacija:${NC}  $BACKUP_DIR"
echo -e "  ${YELLOW}Veličina:${NC}  $BACKUP_SIZE"
echo -e "  ${YELLOW}Slobodno:${NC}  $(df -h / | awk 'NR==2{print $4}')"
echo ""
echo -e "  ${GREEN}Sačuvano:${NC}"
echo -e "  ✓ $(wc -l < $BACKUP_DIR/paketi/svi_paketi.txt) paketa"
echo -e "  ✓ $(wc -l < $BACKUP_DIR/kali/kali_alati.txt) Kali alata"
echo -e "  ✓ APT sources i GPG ključevi"
echo -e "  ✓ Cijeli home folder"
echo -e "  ✓ Sve konfiguracije"
echo -e "  ✓ Mrežne postavke"
echo -e "  ✓ Sve skripte"
echo -e "  ✓ VRATI_SVE.sh restore skripta"
echo ""
echo -e "  ${RED}VAŽNO pri instalaciji:${NC}"
echo -e "  ${RED}→ Odaberi Manual partitioning${NC}"
echo -e "  ${RED}→ Formatiraj SAMO / particiju${NC}"
echo -e "  ${RED}→ NE diraj /backup_sistem!${NC}"
echo ""
echo -e "  ${YELLOW}Nakon instalacije pokreni:${NC}"
echo -e "  ${GREEN}sudo bash /backup_sistem/VRATI_SVE.sh${NC}"
