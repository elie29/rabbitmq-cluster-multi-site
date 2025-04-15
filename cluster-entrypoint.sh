#!/bin/bash

set -e

# Create the same cookie in all nodes
echo "$RABBITMQ_SHARED_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
# Change .erlang.cookie permission
chmod 400 /var/lib/rabbitmq/.erlang.cookie

# Get hostname from environment variable
HOSTNAME=$(hostname)
echo "Starting RabbitMQ Server For host: $HOSTNAME"

/usr/local/bin/docker-entrypoint.sh rabbitmq-server -detached
sleep 5
rabbitmqctl wait "/var/lib/rabbitmq/mnesia/rabbit@$HOSTNAME.pid"

if [[ "$HOSTNAME" != "rabbitmq1" ]]; then
    rabbitmqctl stop_app
    rabbitmqctl reset
    rabbitmqctl join_cluster rabbit@rabbitmq1
    rabbitmqctl start_app
fi

# Keep foreground process active ...
tail -f /dev/null
