#!/bin/bash

# Check if storageClassName is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <storageClassName>"
    echo "Example: $0 local-openebs-hostpath-sftp"
    exit 1
fi

storageClassName="$1"

# Get the list of PV names
pv_names=$(kubectl get pv --template="{{range .items}}{{if and (eq .status.phase \"Released\") (eq .spec.storageClassName \"$storageClassName\")}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}")

# Check if the list is empty
if [ -z "$pv_names" ]; then
    echo "No matching PVs found for storageClassName: $storageClassName"
    exit 0
fi

# Function to release claimRef
release_claim_ref() {
    local pv_name=$1
    echo "Releasing claimRef for PV: $pv_name"
    
    # Patch the PV to remove claimRef
    kubectl patch pv $pv_name --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]'
    
    if [ $? -eq 0 ]; then
        echo "Successfully released claimRef for PV: $pv_name"
    else
        echo "Failed to release claimRef for PV: $pv_name"
    fi
}

# Iterate through PV names and release claimRef
echo "Found the following PVs to process:"
echo "$pv_names"
echo "------------------------"

echo "$pv_names" | while read pv_name; do
    if [ ! -z "$pv_name" ]; then
        release_claim_ref "$pv_name"
        echo "------------------------"
    fi
done

echo "Process completed. Output of 'kubectl get pv':"
kubectl get pv