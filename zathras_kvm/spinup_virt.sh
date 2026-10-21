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
# Configure and spin up a virtual machine
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
	echo "--guest_cpus: Number of virtual CPUs configured on the guest"
	echo "	Defaults to host's total CPU count - 8, minimum of 2"
	echo "--guest_mem: Virtual memory (in MB) configured on the guest"
	echo "	Defaults to host's total memory - 8GB, minimum of 4GB"
	echo "--guest_name: The guest's name from the host's POV, will likely differ from guest hostname"
	echo "	Defaults to <short-hostname>-guest"
	echo "--guest_ostype: The guest's os_type"
	echo "	Defaults to rhel-unknown"
        echo "--iso_to_use: Installation ISO to stage (required)"
}

#
# Basic error checking for the settings we get from the command line
#
validate_options()
{
	# Were we actually fed an ISO?
	if [[ ${iso_to_use} = "" ]]; then
	        exit_out "Error: An ISO from which to install must be provided." $E_GENERAL
	fi

	# Is the ISO we were fed actually present and an ISO?
	if [[ ! -f ${iso_to_use} ]]; then
        	exit_out "Error: The selected ISO is not present." $E_GENERAL
	fi
	# Dereference symlinks just in case someone's doing something funny with symlinks
	value=`file -L ${iso_to_use}`
	echo $value | grep "ISO 9660" > /dev/null
	if [[ $? -ne 0 ]]; then
        	exit_out "Error: The selected ISO isn't really an ISO." $E_GENERAL
	fi

	# Is the number of CPUs requested actually a number?
	if [[ ! "${guestcpus}" =~ ^[1-9][0-9]*$ ]]; then
		exit_out "Error: Number of vCPUs requested is not a positive integer." $E_GENERAL
	fi

	# Is the amount of memory requested actually a number?
	if [[ ! "${guestmem}" =~ ^[1-9][0-9]*$ ]]; then
		exit_out "Error: Amount of memory requested is not a positive integer." $E_GENERAL
	fi

	# Valid ostype?
	value=`virt-install --osinfo list | grep ${guest_ostype}`
	if [[ $? -ne 0 ]]; then
        	exit_out "Error: The selected OS type is invalid." $E_GENERAL
	fi
}

# Set default values
guestname=`hostname -s`-guest
guest_ostype="rhel-unknown"
rundir=`pwd`

# Set aside 8 CPUs, default to whatever's left with a minimum of 2
procs=`nproc`
usable_procs=`expr ${procs} - 8`
guestcpus=$(( ${usable_procs} > 2 ? ${usable_procs} : 2 ))

# Set aside 8GB of memory, 4GB minimum
totalmem=`free -m | awk '/^Mem:/ {print $2}'`
usable_mem=`expr ${totalmem} - 8192`
guestmem=$(( ${usable_mem} > 4096 ? ${usable_mem} : 4096 ))

# Process arguments

ARGUMENT_LIST=(
	"guest_cpus"
	"guest_mem"
	"guest_name"
	"guest_ostype"
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
		--guest_cpus)
			guestcpus=$2
			shift 2
		;;
		--guest_mem)
                        guestmem=$2
                        shift 2
                ;;
		--guest_name)
                        guestname=$2
                        shift 2
                ;;
		--guest_ostype)
                        guest_ostype=$2
                        shift 2
                ;;
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

echo "ISO to use: ${iso_to_use}"
echo "Guest name: ${guestname}"
echo "Guest vCPUs: ${guestcpus}"
echo "Guest mem: ${guestmem}"
echo "Guest OS Type: ${guest_ostype}"

# Check the optios we were fed for obvious issues
validate_options

# Get the IP of the bridge interface and the SSH keys we're using
HOSTIP=`ip a | grep -w br0 | grep inet | awk '{print $2}' | cut -f 1 -d "/"`
SSHKEY=`cat /root/.ssh/authorized_keys`

# Put them into the kickstart file
sed "s|changeme_hostip|${HOSTIP}|g" ${rundir}/kickstart_template.ks > ${rundir}/kickstart.ks
sed -i "s|changeme_sshkey|`echo ${SSHKEY}`|g" ${rundir}/kickstart.ks

# The assembled virt-install command
virt_install_cmd="virt-install --name ${guestname} --memory ${guestmem} --vcpus ${guestcpus} --disk size=30 --osinfo ${guest_ostype} --location ${iso_to_use} --graphics none --initrd-inject ${rundir}/kickstart.ks --extra-args="inst.ks=file:/kickstart.ks console=tty0 console=ttyS0,115200n8" --wait -1 --noautoconsole"

# Useful information
echo "Host IP: ${HOSTIP}"
echo "Guest name: ${guestname}"
echo "Guest CPUs: ${guestcpus}"
echo "Guest memory: ${guestmem}"
echo "Guest OS type: ${guest_ostype}"
echo "virt-install command: ${virt_install_cmd}"

#Spin it up
#${virt_install_cmd}
#The quotes are really messing things up
virt-install --name ${guestname} --memory ${guestmem} --vcpus ${guestcpus} --disk size=30 --osinfo ${guest_ostype} --location ${iso_to_use} --graphics none --initrd-inject ${rundir}/kickstart.ks --extra-args="inst.ks=file:/kickstart.ks console=tty0 console=ttyS0,115200n8" --wait -1 --noautoconsole

# We want the VM's MAC and IP addresses
# The former is needed to get the latter
# The latter is needed to target Zathras/burden
guest_mac=`virsh dumpxml ${guestname} | grep "mac address"|sed "s/.*'\(.*\)'.*/\1/g"`
# Does the agent need a little time?
sleep 60
guest_ip=`virsh domifaddr ${guestname} --source agent | grep ${guest_mac} | awk '{print $4}' | cut -f 1 -d "/"`
echo "Guest MAC: ${guest_mac}"
echo "Guest IP: ${guest_ip}"
