#!/bin/bash
#
# Copyright (C) 2025  John Harrigan <jharriga@redhat.com> & Matt Lucius <malucius@redhat.com>
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


# Collection of utility Functions for working with Perf Co-Pilot
# - pcp_verify($cfg_file)
# - pcp_start($cfg_file, $sample_rate, $archive_dir, $archive_name)
# - pcp_stop()
#
# NOTE: use of these Functions require that PCP is already installed on the system 
##################################################################################

# Global VARs
primary_pmlogger="false"          # used to manage stop/restart
pmlogger_killed="success"         # flags if private pmlogger was killed
#---------------------------------------------------------------

pcp_verify()
{
    local cfg_file="$1"          # PMLOGGER Configuration File
# Verify user provided pmlogger.conf file exists. If not abort.
    if [ ! -f "$cfg_file" ]; then
        echo "File $cfg_file not found!"; echo
        exit 20
    fi

# TBD: use 'pmlogger -c $PWD/$cfg_file -C' to Verify syntax

# Verify PMCD is running (pcp-zeroconf is installed)
    systemctl is-active --quiet pmcd
    if [ $? != 0 ]; then
        echo "PCP pmcd is not running. Is PCP installed?"
        echo "Suggested syntax: sudo dnf install pcp-zeroconf"; echo
        exit 21
    fi

# Manage primary pmlogger. STOP if it is running.
# Check if primary pmlogger is running
    systemctl is-active --quiet pmlogger
    if [ $? == 0 ]; then
        echo "Primary PCP pmlogger is running. Being stopped to run script"
        systemctl stop pmlogger
        # Flag indicates primary pmlogger should be restarted by 'pcp_stop'
        primary_pmlogger="true"
    fi
}

pcp_start()
{
    echo "PCP Starting private pmlogger"

    local cfg_file="$1"
    local sample_rate="$2"
    local archive_dir="$3"
    local archive_basename="$4"
    local archive_loc="${archive_dir}/${archive_basename}"
    local pmlogger_log="${archive_loc}.log"

    mkdir -p "${archive_dir}"

# Run PCP pmlogger
# VERIFY success, ensure pmlogger starts
    pmlogger -c "${cfg_file}" -t "$sample_rate" -l "${pmlogger_log}"\
      "${archive_loc}" &

# First check that the pmlogger process is running
    timeout 5 bash -c \
      "until pgrep pmlogger>/dev/null; do sleep 0.5; done"
    # Trap timeout condition
    if [ $? -eq 124 ]; then
        echo "Timed out waiting for PMLOGGER to Start1"
        exit 30
    fi
}

pcp_stop()
{
    echo "PCP Stop. Stopping private pmlogger, creating archive"

# Stop PCP logger and pause for pmlogger to write archive
    pkill -USR1 pmlogger
# Now check that PMLOGGER has stopped logging
# 5 seconds seems okay for now. We may increase or change the method after some soak time
    timeout 5 bash -c \
      "until ! pgrep pmlogger>/dev/null; do sleep 0.5; done"
    # Trap timeout condition
    if [ $? -eq 124 ]; then
        echo "Timed out waiting for PMLOGGER to Stop"
        pmlogger_killed="failed"        # Not used -yet
        exit 40
    fi
    pmlogger_killed="success"

# Restore primary pmlogger, if it was previously running
    if [ "$primary_pmlogger" == "true" ]; then
        if [ "$pmlogger_killed" == "success" ]; then
#DEBUG      echo "Primary PCP pmlogger being restored to original run state"
            systemctl start pmlogger
#DEBUG  else
#DEBUG      echo "Primary PCP pmlogger NOT restored to original run state"
        fi
    fi
}

mark_ms()
{
    read up rest </proc/uptime; marker="${up%.*}${up#*.}"
    echo "$marker"                 # return value
}

#-------------------------------------------------------
