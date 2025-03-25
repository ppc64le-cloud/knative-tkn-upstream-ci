#!/bin/bash

# This script sets up the k8s environment and updates the knative source for running the tests succesfully.

SSH_ARGS="-i /root/.ssh/ssh-key -o MACs=hmac-sha2-256 -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null"

# Check if the Hosts file is provided as an argument
if [ -z "$1" ]; then
    echo "Host file not provided"
    exit 1
fi

# exit if KNATIVE_REPO is not set
if [ -z ${KNATIVE_REPO} ]
then
    echo "Missing KNATIVE_REPO variable"
    exit 1
fi

# exit if KNATIVE_RELEASE is not set
if [ -z ${KNATIVE_RELEASE} ]
then
    echo "Missing KNATIVE_RELEASE variable"
    exit 1
fi

while IFS= read -r line; do
    # Copy the config file to the remote server
    scp ${SSH_ARGS} /root/.docker/config.json root@${line}:/var/lib/kubelet/config.json
    
    # Restart kubelet service and exit immediately after
    ssh -n ${SSH_ARGS} root@${line} "timeout 10 systemctl restart kubelet; exit" || {
        echo "Failed to restart kubelet on ${line}"
        continue
    }
done < "$1"

create_registry_secrets_in_serving(){
    kubectl -n knative-serving create secret generic registry-creds --from-file=config.json=/root/.docker/config.json
    kubectl -n knative-serving create secret generic registry-certs --from-file=ssl.crt=/etc/ssl/certs/ca-certificates.crt
}

install_go(){
    go install golang.org/dl/go1.22.7@latest
    go1.22.7 download
    alias go=/go/bin/go1.22.7
}

install_contour(){
    # TODO: remove yq dependency
    wget https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_amd64 -P /tmp
    chmod +x /tmp/yq_linux_amd64
    ISTIO_RELEASE=knative-v1.13.1
    echo "Contour is being installed..."
    local envoy_replacement="icr.io/upstream-k8s-registry/knative/maistra/envoy:v2.4"
    local contour_replacement="icr.io/upstream-k8s-registry/knative/contour:v1.29.1"
    # install istio-crds
    curl --connect-timeout 10 --retry 5 -sL https://github.com/knative-sandbox/net-istio/releases/download/${ISTIO_RELEASE}/istio.yaml | \
    /tmp/yq_linux_amd64 '. | select(.kind == "CustomResourceDefinition"), select(.kind == "Namespace")' | kubectl apply -f -
    # install contour
    curl --connect-timeout 10 --retry 5 -sL https://raw.githubusercontent.com/knative/serving/main/third_party/contour-latest/contour.yaml | \
    sed 's!\(image: \).*docker.io.*!\1'$envoy_replacement'!g' | sed 's!\(image: \).*ghcr.io.*!\1'$contour_replacement'!g' | kubectl apply -f -
    kubectl apply -f https://raw.githubusercontent.com/knative/serving/main/third_party/contour-latest/net-contour.yaml
    echo "Waiting until all pods under contour-external are ready..."
    kubectl wait --timeout=15m pod --for=condition=Ready -n contour-external -l '!job-name'
}

#------------------------

echo "Cluster setup started for Knative"

kubectl create ns knative-serving
curl --connect-timeout 10 --retry 5 -sL https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | sed '/.*--metric-resolution.*/a\        - --kubelet-insecure-tls' | kubectl apply -f -

if [[ ${KNATIVE_REPO} == client ]]
then
    create_registry_secrets_in_serving &> /dev/null
    install_contour &> /dev/null
elif [[ ${KNATIVE_REPO} == operator ]]
then
    install_contour &> /dev/null
elif [[ ${KNATIVE_REPO} == serving ]]
then
    create_registry_secrets_in_serving &> /dev/null
elif [[ ${KNATIVE_REPO} =~ kn-plugin-event ]]
then
    create_registry_secrets_in_serving &> /dev/null
    install_go &> /dev/null
fi

install_go &> /dev/null
echo "Cluster setup successfully"

# Copy adjustment scripts 
cp adjust/${KNATIVE_REPO}/${KNATIVE_RELEASE}/* /tmp/

chmod +x /tmp/adjust.sh
