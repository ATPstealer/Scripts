#!/bin/bash

# https://losst.ru/nastrojka-openvpn-v-ubuntu
ip=$1
port=$2
server_name=$3

##########################
ssh -t root@$ip '

### Install openvpn server ###
apt update
apt install openvpn easy-rsa -y
mkdir /etc/openvpn/easy-rsa
cp -R /usr/share/easy-rsa /etc/openvpn/
cd /etc/openvpn/easy-rsa/

### Make certs ###
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-dh
openvpn --genkey --secret /etc/openvpn/easy-rsa/pki/ta.key
./easyrsa gen-crl
./easyrsa build-server-full server nopass
cp ./pki/ca.crt /etc/openvpn/ca.crt
cp ./pki/dh.pem /etc/openvpn/dh.pem
cp ./pki/crl.pem /etc/openvpn/crl.pem
cp ./pki/ta.key /etc/openvpn/ta.key
cp ./pki/issued/server.crt /etc/openvpn/server.crt
cp ./pki/private/server.key /etc/openvpn/server.key

### Make server conf ###
cat > /etc/openvpn/server.conf << EOF
port '$port'
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "redirect-gateway"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
mssfix 0
explicit-exit-notify 1
EOF
### Runs server ###
systemctl start openvpn
systemctl enable openvpn
sysctl -w net.ipv4.ip_forward=1
sleep 1
systemctl restart openvpn
systemctl status openvpn

### Make route ###
int=`ip -br a | grep '$ip' | cut -d " " -f 1`
iptables -I FORWARD -i tun0 -o $int -j ACCEPT
iptables -I FORWARD -i $int -o tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o $int -j MASQUERADE


### Client config ###
./easyrsa build-client-full vpn_client nopass
mkdir -p /etc/openvpn/clients/vpn_client
cd /etc/openvpn/clients/vpn_client
cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/clients/vpn_client/
cp /etc/openvpn/easy-rsa/pki/ta.key /etc/openvpn/clients/vpn_client/
cp /etc/openvpn/easy-rsa/pki/issued/vpn_client.crt /etc/openvpn/clients/vpn_client/
cp /etc/openvpn/easy-rsa/pki/private/vpn_client.key /etc/openvpn/clients/vpn_client/
cat > vpn_client.conf << EOF
client
dev tun
proto udp
remote '$ip' '$port'
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert losst.crt
key losst.key
remote-cert-tls server
tls-auth ta.key 1
cipher AES-256-CBC
verb 3
mssfix 0
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf

<cert>
EOF
cat vpn_client.crt >> vpn_client.conf
cat >> vpn_client.conf << EOF
</cert>
<ca>
EOF
cat ca.crt >> vpn_client.conf
cat >> vpn_client.conf << EOF
</ca>
<key>
EOF
cat vpn_client.key >> vpn_client.conf
cat >> vpn_client.conf << EOF
</key>
<tls-auth>
EOF
cat ta.key >> vpn_client.conf
cat >> vpn_client.conf << EOF
</tls-auth>
EOF

### systemd unit on start OS ###
cat > /root/onboot << EOF
#!/bin/bash
int=`ip -br a | grep '$ip' | cut -d " " -f 1`
iptables -I FORWARD -i tun0 -o $int -j ACCEPT
iptables -I FORWARD -i $int -o tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o $int -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all
iptables -t filter -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -t filter -A INPUT -p udp --dport '$port' -j ACCEPT

EOF
chmod +x /root/onboot

cat > /etc/systemd/system/onboot.service << EOF
[Unit]
Description=Onboot
After=multi-user.target
[Service]
Type=idle
ExecStart=/root/onboot
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable onboot.service

apt install fail2ban -y

'
##########################

### Copy user conf ###
scp root@$ip:/etc/openvpn/clients/vpn_client/vpn_client.conf ./

### Check openVPN up after reboot
ssh -t root@$ip 'reboot'
