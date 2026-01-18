#!/bin/bash
# RK3128 Printer Server 镜像自定义脚本

# 设置时区（根据需要修改）
chroot "${SDCARD}" /bin/bash -c "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"

# 配置CUPS访问权限
cat > "${SDCARD}/etc/cups/cupsd.conf" << 'EOF'
LogLevel warn
PageLogFormat
MaxLogSize 0
Listen 0.0.0.0:631
Listen /run/cups/cups.sock
Browsing On
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes
<Location />
  Order allow,deny
  Allow @LOCAL
  Allow 192.168.0.0/16
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
</Location>
<Location /admin>
  Order allow,deny
  Allow @LOCAL
  Allow 192.168.0.0/16
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
</Location>
<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow @LOCAL
  Allow 192.168.0.0/16
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
</Location>
<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default
  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
  </Limit>
  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Get-Document>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>
  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>
  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>
  <Limit Cancel-Job CUPS-Authenticate-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>
  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
EOF

# 配置Avahi（mDNS/DNS-SD）
cat > "${SDCARD}/etc/avahi/avahi-daemon.conf" << 'EOF'
[server]
host-name=rk3128-printer-server
domain-name=local
use-ipv4=yes
use-ipv6=no
allow-interfaces=eth0,wlan0
[wide-area]
enable-wide-area=yes
[publish]
publish-hinfo=no
publish-workstation=no
[reflector]
enable-reflector=no
[rlimits]
EOF

# 创建打印机服务器状态检查脚本
cat > "${SDCARD}/usr/local/bin/check-printer-server.sh" << 'EOF'
#!/bin/bash
echo "=== RK3128 Printer Server Status ==="
echo ""
echo "1. CUPS Service:"
systemctl status cups --no-pager
echo ""
echo "2. Avahi Service:"
systemctl status avahi-daemon --no-pager
echo ""
echo "3. Network Interfaces:"
ip addr show
echo ""
echo "4. USB Printers:"
lsusb | grep -i printer
echo ""
echo "5. CUPS Printers:"
lpstat -p 2>/dev/null || echo "No printers configured"
echo ""
echo "6. Web Interface: http://$(hostname -I | awk '{print $1}'):631"
echo ""
EOF
chmod +x "${SDCARD}/usr/local/bin/check-printer-server.sh"

# 创建服务启动优化
cat > "${SDCARD}/etc/systemd/system/cups-boot-delay.service" << 'EOF'
[Unit]
Description=Delay CUPS startup for network
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sleep 10
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 修改CUPS服务依赖
mkdir -p "${SDCARD}/etc/systemd/system/cups.service.d"
cat > "${SDCARD}/etc/systemd/system/cups.service.d/override.conf" << 'EOF'
[Unit]
After=cups-boot-delay.service
EOF

# 启用服务
chroot "${SDCARD}" /bin/bash -c "systemctl enable cups-boot-delay"
chroot "${SDCARD}" /bin/bash -c "systemctl enable cups"
chroot "${SDCARD}" /bin/bash -c "systemctl enable avahi-daemon"
chroot "${SDCARD}" /bin/bash -c "systemctl enable ippusbxd"

# 添加lp用户到必要的组
chroot "${SDCARD}" /bin/bash -c "usermod -a -G lpadmin root"

# 设置主机名
echo "rk3128-printer" > "${SDCARD}/etc/hostname"
sed -i 's/127.0.1.1.*/127.0.1.1\trk3128-printer/' "${SDCARD}/etc/hosts"

# 创建首次运行配置脚本
cat > "${SDCARD}/root/first-boot-setup.sh" << 'EOF'
#!/bin/bash
echo "Running first boot setup for RK3128 Printer Server..."
echo "1. Setting root password..."
passwd root
echo "2. Configuring network..."
nmtui
echo "3. Printer server setup complete!"
echo "Access CUPS web interface: http://[YOUR_IP]:631"
echo "Check status: check-printer-server.sh"
EOF
chmod +x "${SDCARD}/root/first-boot-setup.sh"

# 优化内存使用
cat > "${SDCARD}/etc/sysctl.d/99-printer-server.conf" << 'EOF'
# 打印机服务器优化
vm.swappiness=10
vm.vfs_cache_pressure=50
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_tw_reuse=1
EOF

# 禁用不必要的服务以节省资源
chroot "${SDCARD}" /bin/bash -c "systemctl disable bluetooth 2>/dev/null || true"
chroot "${SDCARD}" /bin/bash -c "systemctl disable ModemManager 2>/dev/null || true"
chroot "${SDCARD}" /bin/bash -c "systemctl disable wpa_supplicant 2>/dev/null || true"
