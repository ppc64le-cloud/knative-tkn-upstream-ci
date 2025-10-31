#!/bin/bash

# Check if the Hosts file is provided as an argument
if [ -z "$1" ]; then
    echo "create/delete input not set."
    exit 1
fi

DEBUG=false
PVS_REGION='syd'
PVS_ZONE='syd04'
PVS_SVC_ID='e04ebc6a-3b99-4b0f-9dcc-f6352033f44b'

if [[ "$1" == "create" ]]
then
    echo "Cluster creation started"
    kubetest2 tf --powervs-image-name centos9-stream \
      --powervs-region $PVS_REGION --powervs-zone $PVS_ZONE \
      --powervs-service-id $PVS_SVC_ID \
      --powervs-ssh-key knative-ssh-key \
      --ssh-private-key ~/.ssh/ssh-key \
      --directory release \
      --build-version $K8S_BUILD_VERSION \
      --release-marker release/$K8S_BUILD_VERSION \
      --cluster-name knative-$TIMESTAMP \
      --workers-count 2 \
      --playbook install-k8s-kn-tkn.yml \
      --up --auto-approve --retry-on-tf-failure 5 \
      --break-kubetest-on-upfail true \
      --powervs-memory 32
    
    export KUBECONFIG="$(pwd)/knative-$TIMESTAMP/kubeconfig"
    grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' $(pwd)/knative-$TIMESTAMP/hosts > HOSTS_IP
    source setup-environment.sh HOSTS_IP

elif [[ "$1" == "delete" ]]
then
    echo "Resources deletion started "
    kubetest2 tf --powervs-region $PVS_REGION --powervs-zone $PVS_ZONE \
      --powervs-service-id $PVS_SVC_ID \
      --ignore-cluster-dir true \
      --cluster-name knative-$TIMESTAMP \
      --down --auto-approve --ignore-destroy-errors
fi
