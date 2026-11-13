#!/bin/bash

# Ett skript som utför en grundläggande CIS Ubuntu Level 1 audit.
# Prompt var "I am currently trying to harden my Ubuntu server and have changes some settings according to CIS Benchmarks. Can you create an audit script to check my current hardening according to CIS Benchmark level 1?"

echo "========================================="
echo " CIS Ubuntu Level 1 Audit"
echo "========================================="
echo

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"

    if [ "$result" = true ]; then
        echo "[PASS] $name"
        ((PASS++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

#########################################
# Filesystem Checks
#########################################

check "/tmp mounted" \
$(mount | grep -q " /tmp " && echo true || echo false)

check "Sticky bit on /tmp" \
$(stat -c %a /tmp | grep -q "^1" && echo true || echo false)

#########################################
# User Account Checks
#########################################

check "No UID 0 accounts except root" \
$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v "^root$" | wc -l | grep -q "^0$" && echo true || echo false)

check "No empty password accounts" \
$(awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null | wc -l | grep -q "^0$" && echo true || echo false)

#########################################
# Password Policies
#########################################

MINLEN=$(grep -i "^minlen" /etc/security/pwquality.conf 2>/dev/null | awk '{print $3}')

check "Password minimum length >= 14" \
$([ "${MINLEN:-0}" -ge 14 ] && echo true || echo false)

PASS_MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')

check "Password max age <= 365" \
$([ "${PASS_MAX_DAYS:-9999}" -le 365 ] && echo true || echo false)

#########################################
# SSH Hardening
#########################################

SSHD="/etc/ssh/sshd_config"

check "PermitRootLogin disabled" \
$(grep -Ei "^\s*PermitRootLogin\s+no" $SSHD >/dev/null && echo true || echo false)

check "PasswordAuthentication disabled" \
$(grep -Ei "^\s*PasswordAuthentication\s+no" $SSHD >/dev/null && echo true || echo false)

check "X11Forwarding disabled" \
$(grep -Ei "^\s*X11Forwarding\s+no" $SSHD >/dev/null && echo true || echo false)

check "MaxAuthTries <= 4" \
$(grep -Ei "^\s*MaxAuthTries\s+[1-4]" $SSHD >/dev/null && echo true || echo false)

#########################################
# Sudo
#########################################

check "sudo installed" \
$(command -v sudo >/dev/null && echo true || echo false)

check "UsePTY enabled" \
$(grep -R "use_pty" /etc/sudoers* >/dev/null 2>&1 && echo true || echo false)

check "sudo log file configured" \
$(grep -R "logfile" /etc/sudoers* >/dev/null 2>&1 && echo true || echo false)

#########################################
# Firewall
#########################################

check "UFW installed" \
$(dpkg -l ufw >/dev/null 2>&1 && echo true || echo false)

check "UFW active" \
$(ufw status 2>/dev/null | grep -q "Status: active" && echo true || echo false)

#########################################
# Services
#########################################

check "rsyslog enabled" \
$(systemctl is-enabled rsyslog >/dev/null 2>&1 && echo true || echo false)

check "auditd installed" \
$(dpkg -l auditd >/dev/null 2>&1 && echo true || echo false)

check "auditd running" \
$(systemctl is-active auditd >/dev/null 2>&1 && echo true || echo false)

#########################################
# Time Synchronization
#########################################

check "chrony installed" \
$(dpkg -l chrony >/dev/null 2>&1 && echo true || echo false)

#########################################
# Kernel Parameters
#########################################

IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)

check "IP forwarding disabled" \
$([ "$IP_FORWARD" = "0" ] && echo true || echo false)

ICMP_REDIRECTS=$(sysctl -n net.ipv4.conf.all.accept_redirects)

check "ICMP redirects disabled" \
$([ "$ICMP_REDIRECTS" = "0" ] && echo true || echo false)

#########################################
# World Writable Files
#########################################

WWFILES=$(find / -xdev -type f -perm -0002 2>/dev/null | wc -l)

check "No world writable files" \
$([ "$WWFILES" -eq 0 ] && echo true || echo false)

#########################################
# Final Report
#########################################

echo
echo "========================================="
echo " Audit Summary"
echo "========================================="
echo "Passed : $PASS"
echo "Failed : $FAIL"
echo

if [ "$FAIL" -eq 0 ]; then
    echo "System appears compliant with checked controls."
else
    echo "Review failed controls."
fi