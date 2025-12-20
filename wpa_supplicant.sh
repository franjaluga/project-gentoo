ln -s /etc/init.d/net.lo /etc/init.d/net.wlo1

echo 'modules_wlo1="wpa_supplicant"' >> /etc/conf.d/net
echo 'config_wlo1="dhcp"' >> /etc/conf.d/net

mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
update_config=1
EOF

rc-update add net.wlo1 default
rc-service net.wlo1 start

dhcpcd wlo1

## para iniciar
wpa_cli -i wlo1


##====================================================
## Una vez dentro de wpa_cli, recuerda los pasos:
##====================================================

## scan

## scan_results
 
## add_network (te dará un ID, probablemente el 0)

## set_network 0 ssid "TU_WIFI"

## set_network 0 psk "TU_PASSWORD"

## enable_network 0

## save_config