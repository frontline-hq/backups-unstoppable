#!/bin/bash

# Get the list of non-control-plane node IPs
node_ips=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')

# Iterate over each IP and apply the patch
while IFS= read -r ip; do
    if [ -n "$ip" ]; then
        echo "Applying patch to node: $ip"
        talosctl -n $ip patch machineconfig -p @talos-storage-patch.yaml
        
        # Optional: Add a small delay between operations
        sleep 2
    fi
done <<< "$node_ips"

echo "Patch applied to all non-control-plane nodes."