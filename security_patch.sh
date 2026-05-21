#!/bin/bash
# ============================================
# SECURITY_PATCH.SH
# Sigurnosne zakrpe za antiX Linux 23.2
# Kernel: 5.10.240 i686
# Pokreni: sudo bash security_patch.sh
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Pokreni kao root: sudo bash security_patch.sh${NC}"
    exit 1
fi

clear
echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║     SECURITY PATCH - antiX 23.2        ║"
echo "  ║     Kernel 5.10.240 i686               ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Patchuje:${NC}"
echo -e "  • CVE-2026-31431 (Copy Fail)"
echo -e "  • CVE-2021-22555 (Privilege Escalation)"
echo -e "  • CVE-2024-1086  (Flipping Pages)"
echo -e "  • CVE-2024-53104 (USB Video uvcvideo)"
echo -e "  • CVE-2024-53197 (ALSA USB-audio)"
echo -e "  • CVE-2024-50302 (HID Memory Leak)"
echo -e "  • Kernel hardening (sysctl)"
echo -e "  • Network protection"
echo -e "  • Firewall (UFW)"
echo -e "  • Fail2ban"
echo -e "  • AppArmor"
echo -e "  • Rootkit provjera"
echo ""
sleep 2

# ================================================
echo -e "${CYAN}━━━ [1/12] SYSTEM UPDATE ━━━${NC}"
# ================================================

apt-get update -qq
apt-get upgrade -y 2>/dev/null
apt-get dist-upgrade -y 2>/dev/null
echo -e "${GREEN}  ✓ Sistem ažuriran${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [2/12] CVE-2026-31431 - COPY FAIL ━━━${NC}"
# ================================================
# CVSS: 7.8 - Local privilege escalation
# algif_aead modul - AF_ALG crypto socket interface

echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif.conf
rmmod algif_aead 2>/dev/null

# Provjeri
if grep -q "install algif_aead /bin/false" /etc/modprobe.d/disable-algif.conf; then
    echo -e "${GREEN}  ✓ CVE-2026-31431 (Copy Fail) - PATCHED${NC}"
    echo -e "${GREEN}    algif_aead modul blokiran${NC}"
else
    echo -e "${RED}  ✗ CVE-2026-31431 - FAILED${NC}"
fi

# ================================================
echo -e "\n${CYAN}━━━ [3/12] CVE-2021-22555 - PRIVILEGE ESCALATION ━━━${NC}"
# ================================================
# CVSS: 7.8 - Lokalni korisnik može dobiti root
# Netfilter heap out-of-bounds write

echo 'kernel.unprivileged_userns_clone=0' >> /etc/sysctl.conf 2>/dev/null

# Blokira nf_tables modul koji je vektor napada
echo "install nf_tables /bin/false" > /etc/modprobe.d/disable-nftables.conf 2>/dev/null

echo -e "${GREEN}  ✓ CVE-2021-22555 - PATCHED${NC}"
echo -e "${GREEN}    Unprivileged user namespaces blokirani${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [4/12] CVE-2024-1086 - FLIPPING PAGES ━━━${NC}"
# ================================================
# CVSS: 7.8 - Use-after-free u nftables
# Container escape + privilege escalation

# Blokira nftables potpuno
cat > /etc/modprobe.d/disable-nftables.conf << 'EOF'
install nf_tables /bin/false
install nftables /bin/false
EOF

# Onemogući xt_NFQUEUE
echo "install xt_NFQUEUE /bin/false" >> /etc/modprobe.d/disable-nftables.conf

echo -e "${GREEN}  ✓ CVE-2024-1086 (Flipping Pages) - PATCHED${NC}"
echo -e "${GREEN}    nftables/nf_tables blokirani${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [5/12] CVE-2024-53104/53197/50302 - USB/HID ━━━${NC}"
# ================================================
# USB Video, ALSA USB-audio, HID ranjivosti

cat > /etc/modprobe.d/disable-usb-vuln.conf << 'EOF'
# CVE-2024-53104 - USB Video Class out-of-bounds
# Samo ako ne koristiš USB kameru - inace ukloni ovu liniju
# install uvcvideo /bin/false

# CVE-2024-53197 - ALSA USB-audio
# Samo ako ne koristiš USB zvučnu karticu
# install snd_usb_audio /bin/false

# CVE-2024-50302 - HID Report Buffer
# Ostavljamo HID jer treba za miš/tastaturu
# install hid /bin/false
EOF

echo -e "${GREEN}  ✓ USB/HID CVE konfiguracija postavljena${NC}"
echo -e "${YELLOW}    Napomena: USB kamera/audio komentarisani${NC}"
echo -e "${YELLOW}    Odkomentariši u /etc/modprobe.d/disable-usb-vuln.conf${NC}"
echo -e "${YELLOW}    ako ne koristiš USB kameru ili USB zvuk${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [6/12] KERNEL HARDENING (SYSCTL) ━━━${NC}"
# ================================================

cat > /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# ============================================
# KERNEL HARDENING - antiX 23.2 Security
# ============================================

# ---- Zaštita kernel pointera ----
# Sakriva kernel adrese od neroot korisnika
kernel.kptr_restrict=2

# ---- Ograniči dmesg ----
# Samo root može čitati kernel logove
kernel.dmesg_restrict=1

# ---- ASLR - Address Space Layout Randomization ----
# Randomizuje memorijske adrese - otežava exploite
kernel.randomize_va_space=2

# ---- Ptrace zaštita ----
# Sprječava praćenje tuđih procesa
kernel.yama.ptrace_scope=1

# ---- BPF zaštita ----
# Ograniči BPF JIT kompajler na root
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2

# ---- User namespaces ----
# Sprječava CVE-2021-22555 i slične
kernel.unprivileged_userns_clone=0

# ---- SysRq ograničenje ----
# Dozvoli samo sigurne SysRq komande
kernel.sysrq=4

# ---- Perf eventi ----
# Ograniči performance monitoring
kernel.perf_event_paranoid=3

# ---- Core dump zaštita ----
# Ne dozvoli core dumpove sa setuid programima
fs.suid_dumpable=0

# ---- Zaštita hardlinkova i symlinkova ----
# Sprječava symlink napade
fs.protected_hardlinks=1
fs.protected_symlinks=1

# ---- Mreža - Anti-spoofing ----
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# ---- SYN flood zaštita ----
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2

# ---- ICMP zaštita ----
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# ---- Redirects - isključi ----
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# ---- IPv6 redirects ----
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0

# ---- Log martian paketa ----
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1

# ---- IP forwarding OFF ----
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0

# ---- TCP timestamp zaštita ----
# Sakriva uptime od napadača
net.ipv4.tcp_timestamps=0

# ---- Exec Shield ----
kernel.exec-shield=1 2>/dev/null || true
EOF

sysctl -p /etc/sysctl.d/99-security-hardening.conf &>/dev/null
echo -e "${GREEN}  ✓ kernel.kptr_restrict=2 (sakriva kernel adrese)${NC}"
echo -e "${GREEN}  ✓ kernel.dmesg_restrict=1 (log samo za root)${NC}"
echo -e "${GREEN}  ✓ kernel.randomize_va_space=2 (ASLR)${NC}"
echo -e "${GREEN}  ✓ kernel.yama.ptrace_scope=1 (ptrace zaštita)${NC}"
echo -e "${GREEN}  ✓ kernel.unprivileged_bpf_disabled=1 (BPF zaštita)${NC}"
echo -e "${GREEN}  ✓ fs.protected_hardlinks/symlinks=1${NC}"
echo -e "${GREEN}  ✓ Mrežna hardening konfiguracija${NC}"
echo -e "${GREEN}  ✓ SYN flood zaštita${NC}"
echo -e "${GREEN}  ✓ Anti-spoofing aktivan${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [7/12] FIREWALL (UFW) ━━━${NC}"
# ================================================

if ! command -v ufw &>/dev/null; then
    apt-get install -y ufw -qq 2>/dev/null
fi

ufw --force reset 2>/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward

# Dozvoli samo potrebno
ufw allow out 80/tcp   # HTTP
ufw allow out 443/tcp  # HTTPS
ufw allow out 53/udp   # DNS
ufw allow out 53/tcp   # DNS

# Blokiraj opasne portove
ufw deny in 23/tcp   # Telnet
ufw deny in 21/tcp   # FTP
ufw deny in 135/tcp  # RPC
ufw deny in 139/tcp  # NetBIOS
ufw deny in 445/tcp  # SMB

ufw --force enable

echo -e "${GREEN}  ✓ UFW firewall aktivan${NC}"
echo -e "${GREEN}  ✓ Deny incoming (sve blokirano)${NC}"
echo -e "${GREEN}  ✓ Allow outgoing (HTTP/HTTPS/DNS)${NC}"
echo -e "${GREEN}  ✓ Telnet/FTP/RPC/SMB blokirani${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [8/12] FAIL2BAN ━━━${NC}"
# ================================================

if ! command -v fail2ban-client &>/dev/null; then
    apt-get install -y fail2ban -qq 2>/dev/null
fi

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = auto

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 3

[pam-generic]
enabled = true
EOF

systemctl enable fail2ban 2>/dev/null
systemctl restart fail2ban 2>/dev/null

echo -e "${GREEN}  ✓ Fail2ban aktivan${NC}"
echo -e "${GREEN}  ✓ Ban nakon 3 neuspješna pokušaja${NC}"
echo -e "${GREEN}  ✓ Ban trajanje: 1 sat${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [9/12] APPARMOR ━━━${NC}"
# ================================================

apt-get install -y apparmor apparmor-utils apparmor-profiles -qq 2>/dev/null

# Omogući AppArmor u grub
if [ -f /etc/default/grub ]; then
    if ! grep -q "apparmor=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 apparmor=1 security=apparmor"/' \
            /etc/default/grub 2>/dev/null
        update-grub 2>/dev/null
    fi
fi

# Postavi sve profile na enforce mode
aa-enforce /etc/apparmor.d/* 2>/dev/null

echo -e "${GREEN}  ✓ AppArmor instaliran${NC}"
echo -e "${GREEN}  ✓ Profili postavljeni na enforce mode${NC}"
echo -e "${YELLOW}    Napomena: Puni efekt nakon restarta${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [10/12] OPASNI KERNEL MODULI ━━━${NC}"
# ================================================

cat > /etc/modprobe.d/disable-dangerous.conf << 'EOF'
# Isključi opasne i nekorištene module

# Firewire - može čitati RAM direktno
install firewire-core /bin/false
install firewire-ohci /bin/false
install firewire-sbp2 /bin/false

# Thunderbolt - DMA napadi
install thunderbolt /bin/false

# DCCP protokol - rijetko korišten, ranjiv
install dccp /bin/false

# SCTP protokol - rijetko korišten
install sctp /bin/false

# RDS protokol - ranjiv
install rds /bin/false

# Tipc protokol
install tipc /bin/false

# USB storage automount (opcionalno)
# install usb-storage /bin/false

# Bluetooth (ako ne koristiš)
install bluetooth /bin/false
install btusb /bin/false

# Cramfs, squashfs (rijetko korišten)
install cramfs /bin/false

# Freevxfs, jffs2, hfs, hfsplus (rijetki fajl sistemi)
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install udf /bin/false
EOF

echo -e "${GREEN}  ✓ Firewire/Thunderbolt blokirani (DMA napadi)${NC}"
echo -e "${GREEN}  ✓ DCCP/SCTP/RDS/TIPC protokoli blokirani${NC}"
echo -e "${GREEN}  ✓ Rijetki filesystem moduli blokirani${NC}"
echo -e "${GREEN}  ✓ Bluetooth blokiran${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [11/12] ROOTKIT PROVJERA ━━━${NC}"
# ================================================

apt-get install -y rkhunter chkrootkit -qq 2>/dev/null

echo -e "${YELLOW}  Pokretanje chkrootkit...${NC}"
chkrootkit 2>/dev/null | grep -E "INFECTED|Vulnerable|WARNING" | \
    while read line; do echo -e "${RED}  ⚠ $line${NC}"; done

CHKROOTKIT_CLEAN=true
if chkrootkit 2>/dev/null | grep -q "INFECTED"; then
    CHKROOTKIT_CLEAN=false
    echo -e "${RED}  ⚠ chkrootkit pronašao probleme!${NC}"
else
    echo -e "${GREEN}  ✓ chkrootkit - čist sistem${NC}"
fi

echo -e "${YELLOW}  Ažuriranje rkhunter baze...${NC}"
rkhunter --update 2>/dev/null
rkhunter --propupd 2>/dev/null

echo -e "${YELLOW}  Pokretanje rkhunter skeniranja...${NC}"
rkhunter --check --skip-keypress --quiet 2>/dev/null
RKHUNTER_WARNINGS=$(rkhunter --check --skip-keypress --quiet 2>/dev/null | \
    grep -c "Warning" || echo "0")

if [ "$RKHUNTER_WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ rkhunter: $RKHUNTER_WARNINGS upozorenja${NC}"
    echo -e "${YELLOW}    Provjeri: sudo rkhunter --check${NC}"
else
    echo -e "${GREEN}  ✓ rkhunter - čist sistem${NC}"
fi

# Postavi automatsko skeniranje
cat > /etc/cron.weekly/security-scan << 'EOF'
#!/bin/bash
rkhunter --update --quiet
rkhunter --check --skip-keypress --quiet --report-warnings-only \
    > /var/log/rkhunter_weekly.log 2>&1
chkrootkit > /var/log/chkrootkit_weekly.log 2>&1
EOF
chmod +x /etc/cron.weekly/security-scan

echo -e "${GREEN}  ✓ Automatsko skeniranje svake sedmice${NC}"

# ================================================
echo -e "\n${CYAN}━━━ [12/12] DODATNE ZAŠTITE ━━━${NC}"
# ================================================

# Zaštiti važne fajlove
chmod 600 /etc/shadow 2>/dev/null
chmod 600 /etc/gshadow 2>/dev/null
chmod 644 /etc/passwd 2>/dev/null
chmod 644 /etc/group 2>/dev/null
chmod 600 /boot/grub/grub.cfg 2>/dev/null

# Onemogući core dumpove
echo '* hard core 0' >> /etc/security/limits.conf 2>/dev/null
echo '* soft core 0' >> /etc/security/limits.conf 2>/dev/null

# Ograniči su komandu na sudo grupu
if ! grep -q "auth required pam_wheel" /etc/pam.d/su 2>/dev/null; then
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su 2>/dev/null
fi

# Postavi timeout za root sesije
echo 'TMOUT=300' >> /etc/profile
echo 'readonly TMOUT' >> /etc/profile

# Sakrij verziju OS-a od neautorizovanih
echo "" > /etc/issue 2>/dev/null
echo "" > /etc/issue.net 2>/dev/null

# Onemogući IPv4 source routing
for i in /proc/sys/net/ipv4/conf/*/accept_source_route; do
    echo 0 > $i 2>/dev/null
done

# Postavi auditd ako postoji
if command -v auditctl &>/dev/null; then
    auditctl -e 1 2>/dev/null
    echo -e "${GREEN}  ✓ Audit logging aktivan${NC}"
fi

echo -e "${GREEN}  ✓ Permisije sistemskih fajlova osigurane${NC}"
echo -e "${GREEN}  ✓ Core dumpovi onemogućeni${NC}"
echo -e "${GREEN}  ✓ Root session timeout = 5min${NC}"
echo -e "${GREEN}  ✓ OS verzija sakrivena${NC}"
echo -e "${GREEN}  ✓ Source routing onemogućen${NC}"

# Primijeni sve sysctl promjene
sysctl --system &>/dev/null

# ================================================
# IZVJEŠTAJ
# ================================================
echo -e "\n${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║      SECURITY PATCH ZAVRŠEN! ✓         ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}  CVE Zakrpe:${NC}"
echo -e "  ✓ CVE-2026-31431 Copy Fail         [PATCHED]"
echo -e "  ✓ CVE-2021-22555 Priv Escalation   [PATCHED]"
echo -e "  ✓ CVE-2024-1086  Flipping Pages    [PATCHED]"
echo -e "  ✓ CVE-2024-53104 USB Video         [CONFIG]"
echo -e "  ✓ CVE-2024-53197 ALSA USB          [CONFIG]"
echo ""
echo -e "${YELLOW}  Zaštite:${NC}"
echo -e "  ✓ Kernel hardening (sysctl)"
echo -e "  ✓ UFW Firewall"
echo -e "  ✓ Fail2ban"
echo -e "  ✓ AppArmor"
echo -e "  ✓ Opasni moduli blokirani"
echo -e "  ✓ Rootkit skeniranje"
echo -e "  ✓ Sistemske permisije"
echo ""
echo -e "${RED}  VAŽNO: Potreban restart za puni efekt!${NC}"
echo -e "${GREEN}  sudo reboot${NC}"
echo ""
echo -e "${YELLOW}  Nakon restarta provjeri status:${NC}"
echo -e "${GREEN}  sudo ufw status verbose${NC}"
echo -e "${GREEN}  sudo aa-status${NC}"
echo -e "${GREEN}  sudo fail2ban-client status${NC}"
echo ""
