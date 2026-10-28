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
# Clean up KVM droppings after the automated runs are done
# Part of the Zathras family of workload automation tools
#

# cleanup networking
nmcli con delete br0
nmcli con delete bridge-slave-eth0 

# unmount the ISO
umount /iso_install_host

# Stop the services we started in the staging script
for drv in qemu network nodedev nwfilter secret storage interface; do systemctl stop virt${drv}d{,-ro,-admin}.socket; done
