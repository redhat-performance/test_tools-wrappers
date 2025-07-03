#!/bin/bash
# Updates PCPrecord.service related files and restarts the service
# To monitor the service
#   $ watch -n 1 'systemctl status PCPrecord.service'
###################################################################
working_dir="/usr/local/src/PCPrecord"

mkdir -p "${working_dir}"
chmod 755 *.sh
cp PCPrecord.service /etc/systemd/system/.
cp PCPrecord_actions.sh "${working_dir}/."
cp pcp_functions.inc "${working_dir}/."
cp sbcpu.cfg "${working_dir}/."

# Stop and then Restart the service
systemctl stop PCPrecord.service
sleep 1
systemctl daemon-reload
sleep 1
# WHY is this issuing warning to run 'systemctl daemon-reload'?
systemctl start PCPrecord.service
sleep 1

