#!/bin/sh
wpa_dir="/var/run/wpa_supplicant"
#root check
if [ $(id -u) -gt 0 ];then
        echo "This script requires ROOT or SUDO privileges"
        exit
fi


if [ ! -d "$wpa_dir" ]; then
#	echo "$wpa_dir does not exist, creating $wpa_dir for wireless control..."
	sleep 3
	mkdir -p "$wpa_dir"
	# Set permissions so the 'wheel' group (admins) can use it
	chmod 750 "$wpa_dir"
	chown root:wheel "$wpa_dir"
fi


#logo
f_logo(){
clear
echo " "
echo " █████╗ ███████╗████████╗██╗  ██╗███████╗██████╗  "
echo "██╔══██╗██╔════╝╚══██╔══╝██║  ██║██╔════╝██╔══██╗ "
echo "███████║█████╗     ██║   ███████║█████╗  ██████╔╝ "
echo "██╔══██║██╔══╝     ██║   ██╔══██║██╔══╝  ██╔══██╗ "
echo "██║  ██║███████╗   ██║   ██║  ██║███████╗██║  ██║ "
echo "╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ "
echo "        FreeBSD Wifi Manager By Ishikawa          "
}

#wireless interface check and select
f_wlans(){
echo "--------------------------------------------------"
printf "%-18s | %-15s\n" "PARENT HARDWARE   " "WIRELESS INTERFACE"
echo "--------------------------------------------------"

# Extract mapping from ifconfig
ifconfig -v | awk '
/^[a-z0-9]+:/ {
    iface=$1; sub(":", "", iface)
}
/parent/ {
    printf "%-18s | %-15s\n", $NF, iface
}'
echo "--------------------------------------------------"
}

#Scan for wifi networks and choose network
f_scan(){
echo "------------------------------------------------------------"
printf "%-32s %-4s %-10s\n" "SSID" "CHN" "SECURITY"
echo "------------------------------------------------------------"
ifconfig $device scan | head -30 | awk 'NR > 1 {
    # 1. Find the BSSID (MAC Address) as our anchor point
    if (match($0, /([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/)) {
        
        # SSID is everything before the BSSID
        ssid = substr($0, 1, RSTART-1);
        gsub(/[[:space:]]+$/, "", ssid);
        if (ssid == "") ssid = "[Hidden]";

        # Everything after the BSSID
        after_bssid = substr($0, RSTART + RLENGTH);
        
        # Split the remaining part into fields to get the Channel
        # The channel is the first number after the BSSID
        split(after_bssid, parts);
        chan = parts[1];

        # 2. Security: Check for flags anywhere in the whole line
        sec = "Open";
        if ($0 ~ /RSN/)      sec = "WPA2/3";
        else if ($0 ~ /WPA/) sec = "WPA";
        else if ($0 ~ /EP/)  sec = "Encrypted";
        printf "%-32s %-4s %-10s\n", ssid, chan, sec
    }
}'
#read -p "Enter Wifi Network To Connect To: " ssid
#read -p "Enter Networks Password/Passphrase: " password
}

f_connect(){
echo "Connecting $device to $ssid"
echo "ctrl_interface=/var/run/wpa_supplicant" > ".wpa_$ssid"
echo "ctrl_interface_group=wheel" >> ".wpa_$ssid"
wpa_passphrase $ssid $password >> .wpa_$ssid
wpa_supplicant -B -i$device -c .wpa_$ssid -Dbsd -P "/var/run/wpa_supplicant/$device.pid" &
#sleep 5
dhclient -b $device &
#sleep 3
ip=`ifconfig wlan1 | awk '/inet / {print $2}'`
echo "Connected $ip"
}

f_disconnect(){
echo "Disconnecting $device"
parent_dev=`ifconfig | grep -A 10 $device | grep parent | awk '{print $3}'`
ifconfig $device destroy
ifconfig $device create wlandev $parent_dev
ifconfig $device up
}


f_reset(){
	service netif restart
}

case $1 in
  -connect)
    f_logo
    f_wlans
    read -p "Choose Wifi Interface: " device
    f_scan
    read -p "Enter Wifi Network To Connect To: " ssid
    read -p "Enter Networks Password/Passphrase: " password
    f_connect
    ;;
  -disconnect)
    f_logo
    f_wlans
    read -p "Choose Wifi Interface: " device
    f_disconnect
    ;;
  -manual_connect)
    f_logo
    device=$2
    ssid=$3
    password=$4
    echo "$device $ssid $password"
    f_connect
    ;;
  -manual_disconnect)
    f_logo
    device=$2
    f_disconnect
    ;;
  -scan)
    f_logo
    f_wlans
    read -p "Choose Wifi Interface: " device
    f_scan
    ;;
  -reset)
    f_logo
    f_reset
    ;;
  -interfaces)
    f_logo
    f_wlans
    ;;
  -logo)
    f_logo
    ;;
  *)
    f_logo
    cat <<EOF
Options:
-connect           - Connects to network  
-disconnect        - Disconnects from network
-manual_connect    - Allows for manual connect
-manual_disconnect - Manually disconnects from network
-scan              - Scans available wifi networks 
-interfaces        - Displays available wifi interfaces
-reset             - Runs "service netif restart"
-----------------------------------------------------------
Usage
$0 -connect
$0 -disconnect
$0 -manual_connect [interface] [ssid] [passphrase]
$0 -manual_disconnect [interface]
$0 -scan
$0 -interfaces
$0 -reset
EOF
    exit 0
    ;;
esac
