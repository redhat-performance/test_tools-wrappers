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
# Executed by systemd service 'PCPrecord.service'
# See: /etc/systemd/system/PCPrecord.service
################################################################

# GLOBALS ###################
# Include the PCP Functions file
source $PWD/pcp_functions.inc

FIFO="/tmp/pcpFIFO"                 # get from cmdline
sample_rate=5                       # hardcode DEFAULT for now
pmlogger_running="false"            # Initialize service as OFF
om_workload_file="/tmp/openmetrics_workload.txt"
om_workload_file_reset="/tmp/openmetrics_workload_reset.txt"

#############################
# Functions #################

reset_om_metrics()
{
    echo "Reset OpenMetrics values"
    cp ${om_workload_file_reset} ${om_workload_file}
}

error_exit()
{
    if [[ "$?" != "0" ]]; then
        systemd-notify --status="ERROR: $1"
        # Additional error handling logic can be added here
        rm -f "$FIFO"
        # Reset openmetric.workload metric values prior to leaving
        reset_om_metrics
## if pmlogger_running = True then attempt forcible STOP?
        exit 1
    fi
}
# END Functions #################

# Main #################
# Initialize openmetric.workload metric values
reset_om_metrics

# Verify required files and Packages are available
#----------------------------------
test -f "${om_workload_file}"
error_exit "Initialization: ${om_workload_file} not found!"

# Remove and recreate FIFO on every service 'start'
rm -f "$FIFO"
mkfifo "$FIFO"
error_exit "Initialization: mkfifo $FIFO failed"

## DEBUG - measure processing interval: $postaction-$preaction
action='NONE'
interval=0.0

# Infinite Loop  #################
# Read FIFO and perform requested ACTION (start, stop, ...)
# Access each word in $action string for parsing 'actions' & 'metric'
# NOTE: 'Start, Stop, Reset' actions have no metrics
while : ; do
    # Required or we get TIMEOUT on 'read action < "$FIFO" '
    # Signal readiness for next $action. SYNC point w/client Workload
    # Report timing interval for most recent ACTION
    systemd-notify --ready --status="READY: last-action - $action = ${interval}ms"
    # Read the Request/'$action' and then process it
    read action < "$FIFO"       # Blocks until data is available
    # Signal busy Processing this $action
    systemd-notify --status="$action PMLOGGER Request"
    action_arr=($action)        # Array of 'words' in Request read from FIFO
## DEBUG - measure processing interval for ACTION: $postaction-$preaction
    preaction=$(mark_ms)
    case "${action_arr[0]}" in
        Start)     # 'Start $archive_dir $test_name $conf_file' 
            archive_dir="${action_arr[1]}"
            archive_name="${action_arr[2]}"
            conf_file="${action_arr[3]}"
            # Start PMLOGGER to create ARCHIVE
            if [[ "$pmlogger_running" = "false" ]]; then
                # Signal Processing this $action
                systemd-notify --status="DEBUG: $action PMLOGGER Request"
                # These functions attempt to catch errors and verify success
                pcp_verify $conf_file
                error_exit "pcp_verify: Unable to start PMLOGGER"
                pcp_start $conf_file $sample_rate $archive_dir $archive_name
                error_exit "pcp_start: Unable to start PMLOGGER"
                pmlogger_running="true"       # Record this STATE info
            fi
            ;;
        Stop)      # artifacts_dir="${action_arr[1]}"
            # Terminate PMLOGGER 
            if [[ "$pmlogger_running" = "true" ]]; then
                # Will ZATHRAS Store PCP Archive related artifacts ?
                #  - Currently Missing from PCPSTOP logic
                ##pcp_stop "${artifacts_dir}"
                pcp_stop
                error_exit "pcp_stop: Unable to stop PMLOGGER"
                pmlogger_running="false"
            fi
            ;;
        Reset)   # om_workload_file="${action_arr[1]}"
            # RESET the Workload Metrics
            # the only Request that doesn't require $pmlogger_running
            reset_om_metrics
            error_exit "reset_om_metrics: Unable to RESET Workload Metrics"
            ;;
        throughput|latency|numthreads|runtime)      # Workload Metrics
            # metric="${action_arr[1]}"  om_workload_file=$2
            if [[ "$pmlogger_running" = "true" ]]; then
                # Forward workload metric to openmetrics_workload.txt
                # Change only one metric line at a time
                # Replaces the entire line using sed
                # Should I only print 'action_arr[0] & action_arr[1]'
                sed -i "s/^${action_arr[0]} .*$/${action}/" "$om_workload_file"
            fi
            ;;
        running|iteration)                          # Workload States
            # state="${action_arr[1]}"  om_workload_file=$2
            if [[ "$pmlogger_running" = "true" ]]; then
                sed -i "s/^${action_arr[0]} .*$/${action}/" "$om_workload_file"
            fi
            ;;
        *)
            systemd-notify --status="Unrecognized action - IGNORED"
            ;;
    esac
## DEBUG - measure time interval for processing ACTION
    postaction=$(mark_ms)
    interval=$(( 10*(postaction - preaction) ))
done

# Cleanup
echo "Cleaning up"

# Reset openmetric.workload metric values prior to leaving
reset_om_metrics

exit 0
