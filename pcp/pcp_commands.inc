#
# Copyright (C) 2025  Matt Lucius <malucius@redhat.com> & John Harrigan <jharriga@redhat.com>
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

gl_metric_list=""
gl_metric_separ=""
FIFO="/tmp/pcpFIFO"
timeout_long=10             # wait-time for Start and Stop actions
timeout_short=2             # wait-time for other actions

fail_exit()
{
    if [[ "$?" != "0" ]]; then
        echo "ERROR: $1"
        # Additional error handling logic can be added here
        exit 1
    fi
}

# Wait for the PCPrecord.SVC to report Status='READY'
# This appears to be CPU time heavy
# Timing can be quite finicky
check_svc()
{
    wait_to=$1
    # Wait for the PCPrecord.SVC to report Status='READY'
    # This appears to be CPU time heavy
    timeout "$wait_to" bash -c \
      "until systemctl status PCPrecord.service | grep -q "READY:" \
      ; do sleep 0.1; done"
    # Trap timeout condition
    if [[ $? -eq 124 ]]; then
        echo "Timed out waiting $wait_to sec for systemd status=READY: \
          Request=$request_str"
        exit 2
    fi
}

#Sets up and starts the PCP service
setup_pcp()
{
	# If pmlogger isn't present, install the PCP bits
	pcp_present=$(which pmlogger)
	if [[ $? -ne 0 ]]; then 
		${TOOLS_BIN}/package_tool --no_packages $to_no_pkg_install --wrapper_config ${TOOLS_BIN}/pcp/pcp.json
	fi
	# Distro-specific magic required once the packages are installed
	running_os=`${TOOLS_BIN}/detect_os`
	case "$running_os" in
		"ubuntu")
			# Ubuntu drops the PMDAs in a known place when zeroconf is used, but doesn't make them usable.
			# Each has its own installer which has to be run from its own directory.
			pushd /var/lib/pcp/pmdas/openmetrics
			./Install
			popd
			pushd /var/lib/pcp/pmdas/denki
			./Install
			popd
		;;
			"sles")
			# SLES drops the PMDAs in a known place when zeroconf is used, but doesn't make them usable.
			# Each has its own installer which has to be run from its own directory.
			pushd /var/lib/pcp/pmdas/openmetrics
			./Install
			popd
			pushd /var/lib/pcp/pmdas/denki
			./Install
			popd
		;;
		*)
		# Nothing to do, the installation did everything for us
		;;
	esac
	
working_dir="/usr/local/src/PCPrecord"

	mkdir -p "${working_dir}"
	chmod 755 ${TOOLS_BIN}/pcp/*.sh
	cp ${TOOLS_BIN}/pcp/PCPrecord.service /etc/systemd/system/.
	cp ${TOOLS_BIN}/pcp/PCPrecord_actions.sh "${working_dir}/."
	cp ${TOOLS_BIN}/pcp/pcp_functions.inc "${working_dir}/."
	cp ${TOOLS_BIN}/pcp/workload.url /var/lib/pcp/pmdas/openmetrics/config.d/
	#If there's a workload specific OM file use it. Otherwise use a generic one
	if [[ -f ${run_dir}/openmetrics_${test_name}_reset.txt ]]; then
		cp ${run_dir}/openmetrics_${test_name}_reset.txt /tmp/openmetrics_workload_reset.txt
	else
		cp ${TOOLS_BIN}/pcp/openmetrics_default_reset.txt /tmp/openmetrics_workload_reset.txt
	fi
	# Stop and then Restart the service
	systemctl stop PCPrecord.service
	systemctl stop pmcd
	sleep 1
	systemctl daemon-reload
	sleep 1
	# WHY is this issuing warning to run 'systemctl daemon-reload'?
	systemctl start PCPrecord.service
	systemctl start pmcd
	sleep 1
}

#Starts PCP 
#Sends "Start" command to PCPrecord_actions
#Takes three args:
#$1: Directory for PCP data, should be with the workload's own data
#$2: Test name
#$3: PMLogger config file to use
start_pcp()
{
	printf "Reset\n" > $FIFO
	echo "PCP metrics reset"
	sleep 2
	printf "Start ${1} ${2} ${3}\n" > $FIFO
	echo "PCP Start Complete"
}

#Stops PCP
#Sends "Stop" command to PCPrecord_actions
stop_pcp()
{
	printf "Stop\n" > $FIFO
	sleep 2
}

#Sends value to OpenMetrics file to be added to PCP archive
#$1: metric
#$2: value
result2pcp()
{
	echo "Logging results ${1} ${2}"
	#Do we know about the metric?
	check_svc $timeout_short
	grep -w ${1} /tmp/openmetrics_workload.txt
	if [[ $? -eq 0 ]]; then
		#Just log it
		sed -i "s/^.*${1}.*$/${1} ${2}/" /tmp/openmetrics_workload.txt
	else
		#I don't see it. Typo? Experiment? Flag it and add it to the file
		echo "Unexpected metric logged. Check for a typo."
		echo "${1} ${2}" >> /tmp/openmetrics_workload.txt
	fi
	check_svc $timeout_short
	sleep 2
}

#Shut the services down
shutdown_pcp()
{
	systemctl stop PCPrecord.service
	systemctl stop pmcd
}

#Reset the openmetrics file
reset_pcp_om()
{
	check_svc $timeout_short
        printf "Reset\n" > $FIFO
        echo "PCP metrics reset"
	check_svc $timeout_short
	sleep 2
}

#Start a data subset if we're doing one big archive for the entire run
#Resets OpenMetrics and sets the "running" flag so graphs will show the times we care about
start_pcp_subset()
{
	reset_pcp_om
	echo "Starting PCP subset"
	printf "running 1" > $FIFO
	check_svc $timeout_short
	sleep 2
}

#Stop a data subset if we're doing one big archive for the entire run
stop_pcp_subset()
{
	echo "Stopping PCP subset"
	printf "running 0" > $FIFO
	check_svc $timeout_short
	sleep 2
}

#
# Takes a passed list of metrics and write it out to /tmp/openmetrics_workload.txt
#
# Argument:   <metric name 1>:<metric value>,<metric name 2>:<metric value>.......
#
results2pcp_multiple()
{
	check_svc $timeout_short

	#
	# Replace ',' with a space in the metric list.
	#
	metric_list=`echo "$1" | sed "s/,/ /g"`
	#
	# Make working copy
	#
	cp /tmp/openmetrics_workload.txt /tmp/openmetrics_workload_worker
	#
	# Walk each metric and make updates in the working copy.
	#
	for i in $metric_list; do
		metric=`echo $i | cut -d':' -f1`
		grep -wq ${metric} /tmp/openmetrics_workload.txt
		if [[ $? -ne 0 ]]; then
			echo "Warning: Unexpected metric, ${metric}, being logged. Check for a typo."
		fi
		value=`echo $i | cut -d':' -f2`
                sed -i "s/^${metric} .*$/${metric} ${value}/" /tmp/openmetrics_workload_worker
	done
	#
	# Now cat it to be recorded, do not copy it or move it file.
	#
	cat /tmp/openmetrics_workload_worker > /tmp/openmetrics_workload.txt
	rm /tmp/openmetrics_workload_worker
	check_svc $timeout_short
	sleep 2
}

#
# Places the metric into the $gl_metric_list.  To commit the metrics 
# in the list, use results2pcp_add_value_commit.
#
# Argument <metric_name>:<value>
#
results2pcp_add_value()
{
	gl_metric_list="${gl_metric_list}${gl_metric_separ}${1}"
	#
	# Set the field separator for next metric.
	#
	gl_metric_separ=","
}

#
# Writes out all metrics in $gl_metric_list to the 
# pcp log file /tmp/openmetrics_workload.txt.
#
results2pcp_add_value_commit()
{
	#
	# Use results2pcp_multiple to write the metrics out.
	#
	results2pcp_multiple "${gl_metric_list}"
	#
	# Reset the metric list and field separator.
	#
	gl_metric_list=""
	gl_metric_separ=""
}
