#!/bin/bash

#
#                         License
#
# Copyright (C) 2026  Matt Lucius malucius@redhat.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Stage a system for KVM
# Part of the Zathras family of workload automation tools
#


E_GENERAL=101

exit_out()
{
	echo $1
	exit $2
}

#
# Help message
#
usage()
{
	echo "Script specific options"
	echo "======================================================================"
	echo "--iso_to_use: ISO to stage for installation (required)"
}

# Process arguments

ARGUMENT_LIST=(
	"iso_to_use"
)

NO_ARGUMENTS=(
)

opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --longoptions "$(printf "%s," "${NO_ARGUMENTS[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

if [ $? -ne 0 ]; then
	usage $0
fi

eval set --$opts

while [[ $# -gt 0 ]]; do
	case "$1" in
		--iso_to_use)
			iso_to_use=$2
			shift 2
		;;
		h)
			usage $0
		;;
		--)
			break
		;;
		*)
			echo "not found $1"
			usage $0
		;;
	esac
done

# Were we actually fed an ISO?
if [[ ${iso_to_use} = "" ]]; then
	exit_out "Error: An ISO to stage must be provided." $E_GENERAL
fi

# Is the ISO we were fed actually present and an ISO?
if [[ ! -f ${iso_to_use} ]]; then
	exit_out "Error: The selected ISO is not present." $E_GENERAL
fi
# Dereference symlinks just in case someone's doing something funny with symlinks
value=`file -L ${iso_to_use}` 	
echo $value | grep "ISO 9660" > /dev/null
if [ $? -ne 0 ]; then
	exit_out "Error: The selected ISO isn't really an ISO." $E_GENERAL
fi

# install repos
dnf install -y qemu-kvm libvirt virt-install virt-viewer nfs-utils

# turn everything on
for drv in qemu network nodedev nwfilter secret storage interface; do systemctl start virt${drv}d{,-ro,-admin}.socket; done

# KVM good to go?
virt-host-validate

# ISO mount point setup
mkdir /iso_install_host
mount -t iso9660 ${iso_to_use} /iso_install_host/
echo "/iso_install_host *(ro,sync,no_subtree_check,no_root_squash)" > /etc/exports
systemctl restart nfs-server
systemctl stop firewalld

# network bridge setup
labnet_iface=`route | grep default | awk '{print $8}'`
labnet_iface_mac=`ip link show ${labnet_iface} | grep ether | awk '{print $2}'`

nmcli connection add type bridge autoconnect yes con-name br0 ifname br0
nmcli connection modify br0 bridge.stp no
nmcli connection modify br0 ipv4.method auto
nmcli connection add type bridge-slave autoconnect yes con-name bridge-slave-eth0 ifname ${labnet_iface} master br0
nmcli connection modify br0 bridge.mac-address ${labnet_iface_mac}
nmcli connection down br0 && nmcli connection up br0
nmcli conn modify br0 connection.autoconnect-slaves 1
nmcli connection down br0 && nmcli connection up br0

