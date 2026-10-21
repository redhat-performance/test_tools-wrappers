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
# Shut down and undefine a virtual machine
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
        echo "--guest_name: The name of the guest to shut down and undefine (required)"
}

# Process arguments

ARGUMENT_LIST=(
        "guest_name"
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
                --guest_name)
                        guestname=$2
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

# Were we actually fed a guest name?
if [[ ${guestname} = "" ]]; then
	exit_out "Error: A guest name must be provided." $E_GENERAL
fi

# Do we have a guest by that name?
value=`virsh list --all | grep -w ${guestname}`
if [[ $? -ne 0 ]]; then
	exit_out "Error: There is no guest by the name provided." $E_GENERAL
fi

# shutdown guest, give it time to stop, and delete it
virsh shutdown ${guestname}
sleep 30
virsh undefine ${guestname} --nvram 
