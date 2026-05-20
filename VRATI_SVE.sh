#!/bin/bash
# ============================================
# VRATI_SVE.sh - Restore nakon 64-bit install
# Pokreni: sudo bash /backup_sistem/VRATI_SVE.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- PROVJERE ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash /backup_sistem/VRATI_SVE.sh${NC}"
    exit 1
fi

BACKUP_DIR="/backup_sistem"

# Provjeri da li backup postoji
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Backup folder $BACKUP_DIR nije pronađen!${NC}"
    echo -e "${RED}Provjeri da li je particija mountovana.${NC}"
    exit 1
fi

# Učitaj stari username iz backupa
if [ -f "$BACKUP_DIR/USERNAME.txt" ]; then
    OLD_USERNAME=$(cat $BACKUP_DIR/USERNAME.txt)
    echo -e "${GREEN}  ✓ Stari username iz backupa: $OLD_USERNAME${NC}"
else
    OLD_USERNAME="Buyn4_G4L4"
    echo -e "${YELLOW}  USERNAME.txt nije pronađen, koristim: $OLD_USERNAME${NC}"
fi

# Nađi novog korisnika
if [ -n "$SUDO_USER" ]; then
    NEW_USERNAME="$SUDO_USER"
elif [ -n "$LOGNAME" ] && [ "$LOGNAME" != "root" ]; then
    NEW_USERNAME="$LOGNAME"
else
    NEW_USERNAME=$(who | awk '{print $1}' | grep -v root | head -1)
fi

if [ -z "$NEW_USERNAME" ]; then
    NEW_USERNAME="Buyn4_G4L4"
fi

NEW_HOME="/home/$NEW_USERNAME"

# Provjeri da li novi home postoji
if [ ! -d "$NEW_HOME" ]; then
    echo -e "${RED}Home folder $NEW_HOME ne postoji!${NC}"
    echo -e "${YELLOW}Dostupni korisnici:${NC}"
    ls /home/
    echo -e "${YELLOW}Upiši tačan username novog sistema:${NC}"
    read NEW_USERNAME
    NEW_HOME="/home/$NEW_USERNAME"
fi

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║       RESTORE SISTEMA - antiX 64-bit  ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Stari user:  $OLD_USERNAME${NC}"
echo -e "${YELLOW}  Novi user:   $NEW_USERNAME${NC}"
echo -e "${YELLOW}  Nova home:   $NEW_HOME${NC}"
echo -e "${YELLOW}  Backup dir:  $BACKUP_DIR${NC}"
echo ""
echo -e "${YELLOW}  Počinjemo za 3 sekunde...${NC}"
sleep 3

# ================================================
echo -e "\n${CYAN}[1/8] Vraćanje APT repozitorija...${NC}"
# ================================================

if [ -f "$BACKUP_DIR/apt/sources.list" ]; then
    cp $BACKUP_DIR/apt/sources.list /etc/apt/
    echo -e "${GREEN}  ✓ sources.list vraćen${NC}"
fi

if [ -d "$BACKUP_DIR/apt/sources.list.d" ]; then
    cp -r $BACKUP_DIR/apt/sources.list.d/* /etc/apt/sources.list.d/ 2>/dev/null
    echo -e "${GREEN}  ✓ sources.list.d vraćen${NC}"
fi

if [ -d "$BACKUP_DIR/apt/trusted.gpg.d" ]; then
    cp -r $BACKUP_DIR/apt/trusted.gpg.d/* /etc/apt/trusted.gpg.d/ 2>/dev/null
    echo -e "${GREEN}  ✓ GPG ključevi vraćeni${NC}"
fi

if [ -f "$BACKUP_DIR/apt/apt_keys.gpg" ]; then
    apt-key add $BACKUP_DIR/apt/apt_keys.gpg 2>/dev/null
fi

apt-get update -qq
echo -e "${GREEN}  ✓ APT update završen${NC}"

# ================================================
echo -e "\n${CYAN}[2/8] Reinstalacija paketa (može trajati dugo)...${NC}"
# ================================================

echo -e "${YELLOW}  Reinstalira sve pakete uključujući Kali alate...${NC}"
echo -e "${YELLOW}  Nemoj prekidati ovaj korak!${NC}"

if [ -f "$BACKUP_DIR/paketi/svi_paketi.txt" ]; then
    dpkg --set-selections < $BACKUP_DIR/paketi/svi_paketi.txt 2>/dev/null
    apt-get dselect-upgrade -y 2>/dev/null
    echo -e "${GREEN}  ✓ Paketi reinstalirani${NC}"
else
    echo -e "${RED}  ✗ svi_paketi.txt nije pronađen!${NC}"
fi

# ================================================
echo -e "\n${CYAN}[3/8] Vraćanje konfiguracija...${NC}"
# ================================================

# Shell konfiguracije
for cfg in .bashrc .bash_profile .zshrc .profile \
           .vimrc .gitconfig .tmux.conf; do
    if [ -f "$BACKUP_DIR/configs/$cfg" ]; then
        cp "$BACKUP_DIR/configs/$cfg" $NEW_HOME/ 2>/dev/null
        echo -e "${GREEN}  ✓ $cfg vraćen${NC}"
    fi
done

# IceWM
if [ -d "$BACKUP_DIR/configs/.icewm" ]; then
    cp -r $BACKUP_DIR/configs/.icewm $NEW_HOME/
    echo -e "${GREEN}  ✓ IceWM konfiguracija vraćena${NC}"
fi

# .config
if [ -d "$BACKUP_DIR/configs/.config" ]; then
    cp -r $BACKUP_DIR/configs/.config $NEW_HOME/
    echo -e "${GREEN}  ✓ .config vraćen${NC}"
fi

# SSH ključevi
if [ -d "$BACKUP_DIR/configs/.ssh" ]; then
    cp -r $BACKUP_DIR/configs/.ssh $NEW_HOME/
    chmod 700 $NEW_HOME/.ssh
    chmod 600 $NEW_HOME/.ssh/* 2>/dev/null
    echo -e "${GREEN}  ✓ SSH ključevi vraćeni${NC}"
fi

# ================================================
echo -e "\n${CYAN}[4/8] Vraćanje home foldera...${NC}"
# ================================================

if [ -d "$BACKUP_DIR/home" ]; then
    rsync -a \
        --exclude='.cache' \
        --exclude='*.iso' \
        --exclude='*.tmp' \
        $BACKUP_DIR/home/ $NEW_HOME/ 2>/dev/null
    echo -e "${GREEN}  ✓ Home folder vraćen${NC}"
else
    echo -e "${RED}  ✗ Backup home folder nije pronađen!${NC}"
fi

# ================================================
echo -e "\n${CYAN}[5/8] Vraćanje mrežnih postavki...${NC}"
# ================================================

[ -f "$BACKUP_DIR/mreza/hosts" ] && \
    cp $BACKUP_DIR/mreza/hosts /etc/hosts && \
    echo -e "${GREEN}  ✓ hosts vraćen${NC}"

[ -f "$BACKUP_DIR/mreza/resolv.conf" ] && \
    cp $BACKUP_DIR/mreza/resolv.conf /etc/resolv.conf && \
    echo -e "${GREEN}  ✓ resolv.conf vraćen${NC}"

# ================================================
echo -e "\n${CYAN}[6/8] Vraćanje skripti...${NC}"
# ================================================

if [ -d "$BACKUP_DIR/skripte" ]; then
    cp $BACKUP_DIR/skripte/*.sh $NEW_HOME/ 2>/dev/null
    chmod +x $NEW_HOME/*.sh 2>/dev/null
    echo -e "${GREEN}  ✓ Skripte vraćene i executable${NC}"
fi

# Kopiraj master64.sh posebno ako postoji
[ -f "$BACKUP_DIR/skripte/master64.sh" ] && \
    cp $BACKUP_DIR/skripte/master64.sh $NEW_HOME/ && \
    chmod +x $NEW_HOME/master64.sh

# ================================================
echo -e "\n${CYAN}[7/8] Vraćanje Wordlista i SecLists...${NC}"
# ================================================

if [ -d "$BACKUP_DIR/kali/wordlists" ]; then
    cp -r $BACKUP_DIR/kali/wordlists/ /usr/share/
    echo -e "${GREEN}  ✓ Wordlists vraćene u /usr/share/${NC}"
else
    echo -e "${YELLOW}  - Wordlists nisu u backupu${NC}"
fi

if [ -d "$BACKUP_DIR/kali/seclists" ]; then
    cp -r $BACKUP_DIR/kali/seclists/ /usr/share/
    echo -e "${GREEN}  ✓ SecLists vraćene u /usr/share/${NC}"
else
    echo -e "${YELLOW}  - SecLists nisu u backupu${NC}"
fi

# ================================================
echo -e "\n${CYAN}[8/8] Postavljanje vlasništva i permisija...${NC}"
# ================================================

chown -R $NEW_USERNAME:$NEW_USERNAME $NEW_HOME/ 2>/dev/null
echo -e "${GREEN}  ✓ Vlasništvo postavljeno na $NEW_USERNAME${NC}"

# ================================================
# REZULTAT
# ================================================
echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║         RESTORE ZAVRŠEN! ✓             ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${GREEN}Vraćeno:${NC}"
echo -e "  ✓ APT repozitoriji i Kali sources"
echo -e "  ✓ Svi paketi i Kali alati"
echo -e "  ✓ Konfiguracije (.bashrc, IceWM...)"
echo -e "  ✓ Cijeli home folder"
echo -e "  ✓ Mrežne postavke"
echo -e "  ✓ Sve skripte"
echo -e "  ✓ Wordlists i SecLists"
echo ""
echo -e "  ${YELLOW}Sljedeći korak — optimizuj sistem:${NC}"
echo -e "  ${GREEN}sudo bash ~/master64.sh${NC}"
echo ""
echo -e "  ${YELLOW}Pa restart:${NC}"
echo -e "  ${GREEN}sudo reboot${NC}"
echo ""
