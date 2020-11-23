#!/bin/bash -e

sudo apt install dnsmasq -y

fake_mac_address="12:34:56:65:43:21"
usb_ip_base="10.8.0"
static_usb_ip="${usb_ip_base}.1"
usb_interface_name="usb0"

boot_mount_point="/boot"
rootfs_mount_point="/"

echo "-- Enabling SSH"
touch "${boot_mount_point}/ssh"

echo "-- Configuring ethernet gadget"
if ! grep -q "^dtoverlay=dwc2" "${boot_mount_point}/config.txt"; then
    echo "dtoverlay=dwc2" | tee -a "${boot_mount_point}/config.txt"
fi

if ! grep -q "modules-load=dwc2" "${boot_mount_point}/cmdline.txt"; then
    sed -i "s/rootwait/rootwait modules-load=dwc2/" "${boot_mount_point}/cmdline.txt"
fi

if ! grep -q "^libcomposite" "${rootfs_mount_point}/etc/modules"; then
    echo "libcomposite" | tee -a "${rootfs_mount_point}/etc/modules"
fi

echo "-- Setting static IP to USB interface (${static_usb_ip})"

if ! grep -q "^denyinterfaces ${usb_interface_name}" "${rootfs_mount_point}/etc/dhcpcd.conf"; then
    echo "denyinterfaces ${usb_interface_name}" | tee -a "${rootfs_mount_point}/etc/dhcpcd.conf"
fi

echo """interface=usb0
dhcp-range=${usb_ip_base}.2,${usb_ip_base}.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro""" | tee -a "/etc/dnsmasq/usb"

echo  """auto ${usb_interface_name}
allow-hotplug ${usb_interface_name}
iface ${usb_interface_name} inet static
  address ${static_usb_ip}
  netmask 255.255.255.248""" | tee -a "${rootfs_mount_point}/etc/network/interfaces.d/${usb_interface_name}"

echo "-- Writing /root/usb.sh script"

echo '
#!/bin/bash
# taken from https://sausheong.github.io/posts/pi4-dev-ipadpro/

# create a directory to represent the gadget
cd /sys/kernel/config/usb_gadget/ # must be in this dir
mkdir -p pi4
cd pi4

# the USB vendor and product IDs are issued by the USB-IF
# each USB gadget must be identified by a vendor and
# product ID
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

mkdir -p strings/0x409 # set it up as English
# The configuration below is arbitrary
echo "1234567890abcdef" > strings/0x409/serialnumber
echo "Chang Sau Sheong" > strings/0x409/manufacturer
echo "Pi4 USB Desktop" > strings/0x409/product

# create a configuration
mkdir -p configs/c.1
# create a function
# ECM is the function name, and ${usb_interface_name} is arbitrary string
# that represents the instance name
mkdir -p functions/ecm.${usb_interface_name} 

# associate function to configuration
ln -s functions/ecm.${usb_interface_name} configs/c.1/ 

# bind the gadget to UDC
ls /sys/class/udc > UDC 

# start up ${usb_interface_name}
ifup ${usb_interface_name} 
# start dnsmasq
service dnsmasq restart 
' | tee -a "/root/usb.sh"

chmod +x "/root/usb.sh"

echo "-- Run /root/usb.sh ..."
echo "-- Bye!"


