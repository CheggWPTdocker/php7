#!/bin/sh
# ----------------------------------------------------------------------------
# entrypoint for container
# ----------------------------------------------------------------------------
set -e
HOST_IP=`/bin/grep $HOSTNAME /etc/hosts | /usr/bin/cut -f1`
echo "started with ip: ${HOST_IP}..."

if [ "$1" == "supervisor" ]; then
	echo "starting services...."
	/usr/bin/supervisord -n -c /etc/supervisord.conf
elif [ "$1" == "bash" ] || [ "$1" == "shell" ]; then
	echo "starting /bin/bash with...."
	/bin/bash --rcfile /etc/profile
else
	echo "Running something else"
	exec "$@"
fi
