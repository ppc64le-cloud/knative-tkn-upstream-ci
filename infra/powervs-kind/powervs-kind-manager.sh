#!/bin/bash
set -euo pipefail

# -------------------------------
# Display usage information
# -------------------------------
usage() {
    echo "Usage: $0 {create|delete}"
    echo ""
    echo "Commands:"
    echo "  create  - Create a new KinD cluster on IBM PowerVS"
    echo "  delete  - Delete the existing KinD cluster and associated resources"
    echo ""
    echo "Example:"
    echo "  $0 create"
    echo "  $0 delete"
    exit 1
}

# -------------------------------
# Environment setup (declare defaults and export)
# -------------------------------
setup_env() {
    # ----------------------------
    # Configuration variables
    # ----------------------------
    export PCLOUD_IBM_API_KEY=${TF_VAR_powervs_api_key} # Environment variable coming from prow
    export PCLOUD_IBM_REGION="${PCLOUD_IBM_REGION:-eu-de}"
    export IMAGE_NAME="${IMAGE_NAME:-centos9-stream}"
    export SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-~/.ssh/ssh-key}"
    export VSI_NAME="${VSI_NAME:-knative-testing}"
    export NETWORK_NAME="${VSI_NAME}-pub-net"
    export SUBNET_ID="${SUBNET_ID:-}"
    export POLL_INTERVAL=${POLL_INTERVAL:-10}
    export VSI_IP="${VSI_IP:-}"
    export VSI_ID="${VSI_ID:-}"
    export DOCKER_CONFIG='/root/.docker/config.json'
    export K8S_BUILD_VERSION="${K8S_BUILD_VERSION:-$(curl -L -s https://dl.k8s.io/release/stable.txt)}"
    echo "Environment initialized."
}

# -------------------------------
# Unset all script-specific variables to ensure clean state
# -------------------------------
reset_env() {
    unset PCLOUD_IBM_API_KEY PCLOUD_IBM_REGION IMAGE_NAME SSH_PRIVATE_KEY
    unset VSI_NAME NETWORK_NAME SUBNET_ID VSI_IP VSI_ID
    unset DOCKER_CONFIG POLL_INTERVAL K8S_BUILD_VERSION
    echo "Environment variables reset."
}

# -------------------------------
# Install ibmcloud tool and plugins
# -------------------------------
install_prereqs() {
    curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
    ibmcloud --version
    ibmcloud config --check-version=false
    ibmcloud plugin install is -f power-iaas
    ibmcloud plugin install -f vpc-infrastructure
}

# ----------------------------
# Login to IBM Cloud
# ----------------------------
login_ibmcloud() { 
    echo "Login to IBMCLOUD and login to workspace 'rdr-knative-prow-testbed-eu-de-2'"
    ibmcloud login --apikey "${PCLOUD_IBM_API_KEY}" -r "${PCLOUD_IBM_REGION}"
    crn=$(ibmcloud pi workspace list --json | jq  '.[] | .workspaces[] | select(.name == "rdr-knative-prow-testbed-eu-de-2") | "\(.details.crn)"' | tr -d '"')
    ibmcloud pi workspace target $crn
    echo $crn
}

# ----------------------------
# Create network
# ----------------------------
create_network() {
    echo "Create network ${NETWORK_NAME}"
    ibmcloud pi subnet create ${NETWORK_NAME} --net-type public --dns-servers "8.8.4.4,8.8.8.8"
    echo "Created subnet ${NETWORK_NAME}. Status: $?"
    SUBNET_ID=$(timeout 30 ibmcloud pi subnet ls | grep ${NETWORK_NAME} | awk '{print $1}' | head -n1)
    export SUBNET_ID
    
    if [[ -z "$SUBNET_ID" ]]; then
      echo "❌ Failed to retrieve SUBNET_ID"
      exit 1
    fi
    echo "SUBNET_ID: $SUBNET_ID"
}

# ----------------------------
# Wait for VSI to become ACTIVE
# ----------------------------
wait_for_vsi_active() {
    local rc
    local provision_start_time

    echo "Waiting for VSI to be provisioned..."

    provision_start_time=$(date +%s)
    timeout 900 bash -c '
      while true; do
        elapsed=$(( $(date +%s) - '"$provision_start_time"' ))
        status=$(
          ibmcloud pi instance get "$VSI_ID" --json 2>/dev/null \
            | jq -r ".status" 2>/dev/null \
            | tr -d "[:space:]" \
            | tr "[:lower:]" "[:upper:]"
        )

        if [[ "$status" == "ACTIVE" ]]; then
          VSI_IP=$(ibmcloud pi instance get "$VSI_ID" --json | jq -r ".networks[0].externalIP" | tr -d "[:space:]")
          echo "✅ Instance $VSI_NAME ($VSI_IP) is ACTIVE [$elapsed sec elapsed]"
          break
        fi

        echo "$VSI_NAME: Still creating... [$elapsed sec elapsed] Current status: ${status:-UNKNOWN}"
        sleep '"$POLL_INTERVAL"'
      done
    '
    rc=$?

    if [[ $rc -ne 0 ]]; then
      echo "⚠️ Command failed while waiting for $VSI_NAME to become ACTIVE. Exit code: $rc"
      exit "$rc"
    fi
}

# ----------------------------
# Wait for VSI health to become OK
# ----------------------------
wait_for_vsi_healthy() {
    local rc
    local health_start_time

    health_start_time=$(date +%s)
    timeout 900 bash -c '
      while true; do
        elapsed=$(( $(date +%s) - '"$health_start_time"' ))
        health=$(
          ibmcloud pi instance get "$VSI_ID" --json 2>/dev/null \
            | jq -r ".health.status" 2>/dev/null \
            | tr -d "[:space:]" \
            | tr "[:lower:]" "[:upper:]"
        )

        if [[ "$health" == "OK" ]]; then
          echo "✅ Instance $VSI_NAME is healthy [$elapsed sec elapsed]"
          break
        fi

        echo "$VSI_NAME: health check pending... [$elapsed sec elapsed] Current health: ${health:-UNKNOWN}"
        sleep '"$POLL_INTERVAL"'
      done
    '
    rc=$?

    if [[ $rc -ne 0 ]]; then
      echo "❌ Instance $VSI_NAME is not healthy. Exiting..."
      exit "$rc"
    fi
}

# ----------------------------
# Create VSI
# ----------------------------
create_vsi() {
    instance_output=$(ibmcloud pi instance create $VSI_NAME \
        --image $IMAGE_NAME \
        --sys-type s922 \
        --processors 1 \
        --processor-type shared \
        --key-name knative-ssh-key \
        --subnets "${SUBNET_ID}" \
        --memory 32 \
        --storage-pool-affinity \
        --storage-tier tier1 \
        --replicants 1 \
        --replicant-scheme suffix \
        --replicant-affinity-policy none \
        --json)

    VSI_ID=$(echo $instance_output | jq -r '.[0].pvmInstanceID')
    export VSI_ID

    if [[ -z "$VSI_ID" ]] || [[ "$VSI_ID" == "null" ]]; then
      echo "❌ Failed to retrieve VSI_ID"
      exit 1
    fi
    echo "VSI_ID: $VSI_ID"

    wait_for_vsi_active
    wait_for_vsi_healthy

    VSI_IP=$(ibmcloud pi instance get "$VSI_ID" --json | jq -r '.networks[0].externalIP' | tr -d '[:space:]')
    export VSI_IP
    echo "Done. VSI_IP: $VSI_IP"
}

# ----------------------------
# Setup VSI and create KinD cluster
# ----------------------------
create_kind_cluster() {
    # ----------------------------
    # Test SSH
    # ----------------------------

    ssh -o StrictHostKeyChecking=no -i "${SSH_PRIVATE_KEY}" root@"$VSI_IP" "echo 'SSH OK'"

    # ----------------------------
    # Install Docker & Kind inside VSI
    # ----------------------------
    echo "Installing Docker and Kind on VSI..."
    
    echo "Step 1. Copy $DOCKER_CONFIG to VSI_IP: $VSI_IP"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_PRIVATE_KEY" "$DOCKER_CONFIG" root@"$VSI_IP":/root/config.json

    echo "Step 2. Patch KinD build script with VSI_IP: $VSI_IP and K8S_BUILD_VERSION: $K8S_BUILD_VERSION"
    sed -e "s/\${VSI_IP}/${VSI_IP}/g" -e "s/\${K8S_BUILD_VERSION}/${K8S_BUILD_VERSION}/g" "$(dirname "${BASH_SOURCE[0]}")/build-kind.sh" > build-kind-patched.sh

    echo "Step 3. Add execute permission to patched script"
    chmod +x build-kind-patched.sh

    echo "Step 4. Copy patched script to VSI_IP: $VSI_IP"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_PRIVATE_KEY" build-kind-patched.sh root@"$VSI_IP":/root/build-kind-patched.sh

    echo "Step 5. Execute patched script to condifure and build KinD cluster on VSI_IP: $VSI_IP"
    ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" root@"$VSI_IP" 'export VSI_IP=$VSI_IP; bash -s' < ./build-kind-patched.sh
    # Another method (optional) to execute scrpt after copy to VSI
    # ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" root@"$VSI_IP" '/root/build-kind.sh'
    
    echo "Step 6. Copy the kubeconfig file from VSI_IP: $VSI_IP to local /root/.kube"
    mkdir -p /root/.kube
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_PRIVATE_KEY" root@"$VSI_IP":/root/.kube/config /root/.kube/config

    echo "Step 7. Replace internal IP with VSI_IP in kubeconfig"
    sed -i "s#server: https://.*:6443#server: https://${VSI_IP}:6443#g" /root/.kube/config

    echo "✅ VSI ready with Docker & KinD installed."
}

# ----------------------------
# Delete VSI and Subnet
# ----------------------------
delete_cluster() {
    echo "🗑️  Deleting cluster resources..."
    
    # Check if VSI_ID is set, if not try to retrieve it
    if [[ -z "$VSI_ID" ]]; then
        echo "VSI_ID not set. Attempting to retrieve from VSI_NAME: ${VSI_NAME}"
        VSI_ID=$(ibmcloud pi instance ls | grep $VSI_NAME | awk '{print $1}' | head -n1)
        
        if [[ -z "$VSI_ID" ]] || [[ "$VSI_ID" == "null" ]]; then
            echo "⚠️  Could not find VSI with name: ${VSI_NAME}"
        else
            echo "Found VSI_ID: $VSI_ID"
        fi
    fi
    
    # Delete VSI if VSI_ID is available
    if [[ -n "$VSI_ID" ]] && [[ "$VSI_ID" != "null" ]]; then
        echo "Deleting VSI: ${VSI_ID}"
        ibmcloud pi instance delete ${VSI_ID} --delete-data-volumes=True
        echo "✅ VSI deleted"
    fi
    
    # Wait for VSI deletion to complete
    sleep 120
    
    # Check if SUBNET_ID is set, if not try to retrieve it
    if [[ -z "$SUBNET_ID" ]]; then
        echo "SUBNET_ID not set. Attempting to retrieve from NETWORK_NAME: ${NETWORK_NAME}"
        SUBNET_ID=$(ibmcloud pi subnet ls --json | jq -r ".networks[] | select(.name == \"${NETWORK_NAME}\") | .networkID")
        
        if [[ -z "$SUBNET_ID" ]] || [[ "$SUBNET_ID" == "null" ]]; then
            echo "⚠️  Could not find subnet with name: ${NETWORK_NAME}"
        else
            echo "Found SUBNET_ID: $SUBNET_ID"
        fi
    fi
    
    # Delete subnet if SUBNET_ID is available
    if [[ -n "$SUBNET_ID" ]] && [[ "$SUBNET_ID" != "null" ]]; then
        echo "Deleting subnet: ${SUBNET_ID}"
        ibmcloud pi snet delete ${SUBNET_ID}
        echo "✅ Subnet deleted"
    fi
    
    echo "✅ Cluster deletion complete"
}

# -------------------------------
# Main function to handle command execution
# -------------------------------
main() {
    # Uncomment reset_env call while running multiple times only while debugging
    #reset_env
    
    # Check if argument is provided
    if [[ $# -eq 0 ]]; then
        echo "❌ Error: No command provided"
        usage
    fi

    # Parse command-line argument
    local COMMAND=$1

    case $COMMAND in
        create)
            echo "🚀 Starting cluster creation..."
            trap delete_cluster ERR EXIT
            setup_env
            install_prereqs
            login_ibmcloud
            create_network
            create_vsi
            create_kind_cluster
            trap - ERR EXIT  # Remove trap after successful creation
            echo "✅ Cluster created successfully!"
            ;;
        delete)
            echo "🗑️  Starting cluster deletion..."
            setup_env
            login_ibmcloud
            delete_cluster
            echo "✅ Cluster deleted successfully!"
            ;;
        *)
            echo "❌ Error: Invalid command '$COMMAND'"
            usage
            ;;
    esac
}

# -------------------------------
# Script entry point
# -------------------------------
# Only execute main if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

