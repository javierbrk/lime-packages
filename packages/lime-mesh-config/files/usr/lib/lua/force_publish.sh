#!/bin/sh
# Check if the correct number of arguments is provided

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <data_type> <host> <key>"
    exit 1
fi
logger -p daemon.info -t "async: mesh_config" "publishinggggggggggggggggggggggggggggggg"
# Assign the argument to a variable
mesh_config="$1"
host="$2"
key="$3"

# Concatenate to form the command
command="/usr/share/shared-state/publishers/shared-state-publish_$mesh_config"

# Function to get the transaction_state for "LiMe-abc002"
get_transaction_state() {
    # Get the mesh_config JSON
    mesh_config_json=$(shared-state-async get $mesh_config)

    # Load the JSON and extract the transaction_state for "LiMe-abc002"
    . /usr/share/libubox/jshn.sh
    json_load "$(echo "$mesh_config_json")"
    json_select "$host"
    json_get_var transaction_state "$key"
    json_select ..  # Go back to the root
}

# Function to get the transaction_state from ubus
get_ubus_transaction_state() {
    # Get the node status from ubus
    node_status_json=$(ubus -v call lime-mesh-config get_node_status)

    json_load "$(echo "$node_status_json")"
    json_get_var ubus_transaction_state "$key"
}

# Main loop - execute up to 10 times
for i in $(seq 1 10); do
    # Execute the command
	logger -p daemon.info -t "async: mesh_config" "publishinggggggggggggggggggggggggggggggg$command"

	$command


    # Get the current transaction states
    get_transaction_state
    get_ubus_transaction_state

    # Check if the transaction_state values are equal
    if [ "$transaction_state" = "$ubus_transaction_state" ]; then
        echo "Transaction states match: $transaction_state. Exiting."
		logger -p daemon.info -t "async: mesh_config" "Transaction states match: $transaction_state. Exiting."
		shared-state-async sync $mesh_config
        exit 0
    else
        echo "Transaction states do not match: mesh_config=$transaction_state, ubus=$ubus_transaction_state."
		logger -p daemon.info -t "async: mesh_config" "Transaction states do not match: mesh_config=$transaction_state, ubus=$ubus_transaction_state."
        echo "Executing shared_state_publish..."
        # Execute the shared_state_publish command here
    fi

    # Wait for 10 seconds before the next check
    sleep 10
done

echo "Reached maximum attempts (10). Exiting."
exit 1
