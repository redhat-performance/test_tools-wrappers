FIFO="/tmp/pcpFIFO"

#Sets up and starts the PCP service
setup_pcp() {
	working_dir="/usr/local/src/PCPrecord"

	mkdir -p "${working_dir}"
	chmod 755 ${TOOLS_BIN}/pcp/*.sh
	cp ${TOOLS_BIN}/pcp/PCPrecord.service /etc/systemd/system/.
	cp ${TOOLS_BIN}/pcp/PCPrecord_actions.sh "${working_dir}/."
	cp ${TOOLS_BIN}/pcp/pcp_functions.inc "${working_dir}/."

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
#Resets openmetrics
#Sends "Start" command to PCPrecord_actions
#Takes three args:
#1: Directory for PCP data, should be with the workload's own data
#2: Test name
#3: PMLogger config file to use
start_pcp() {
        printf "Reset\n" > $FIFO
        echo "PCP metrics reset"
	#Without the sleep the "Start" will be missed
	sleep 2
	echo "Start ${1} ${2} ${3}\n" 
	printf "Start ${1} ${2} ${3}\n" > $FIFO
}

#Sends value to PCP archive as "throughput"
#Uses openmetrics
result2pcp() {
        printf "throughput ${1}\n" > $FIFO

#Stops PCP
#Sends "Stop" command to PCPrecord_actions
stop_pcp() {
	printf "Stop\n" > $FIFO
}

#Shut the services down
shutdown_pcp() {
	systemctl stop PCPrecord.service
	systemctl stop pmcd
}

#Reset the openmetrics file
reset_pcp_om () {
        printf "Reset\n" > $FIFO
        echo "PCP metrics reset"
        sleep 2
}
