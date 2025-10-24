# Automated Settings for Running and Debugging Knative Jobs Locally on ppc64le

This document helps set up a local (non-Prow) environment for testing or debugging Knative projects on a ppc64le VM. 

The following Knative projects are currently supported for local testing and debugging:

- operator
- client
- eventing

## Prerequisites  

- **`ppc64le` VM** with KinD and `docker/podman` installed.
- Python (3+) installed on the VM
- **Required Secrets:** 
  - `config.json`: Required for cluster access to IBM Container Registry.  

---

## Usage

### 1. Enter into the debug directory

```bash
cd debug
```

### 2. Build test image

Build testing image `quay.io/p_serverless/knative-prow-tests:debug` required for testing environment

```bash
docker buildx build --platform linux/ppc64le -t quay.io/p_serverless/knative-prow-tests:debug --load -f Dockerfile .
```

### 3. Add IBM container registry keys

Replace/Add creds of the IBM container registry in the config.json file

```bash
{
  "auths": {
    "na.artifactory.swg-devops.com": {
      "auth": "<add-auth-key-here>"
    },
    "quay.io": {
      "auth": "<add-auth-key-here>"
    },
    "icr.io": {
      "auth": "<add-auth-key-here>"
    }
  }
}
```

### 4. Edit `.env`. 

Update the Knative repo project name, branch and other environment variable required to run the test. To update the variable values refer `ppc64le` prow  Knative job configs: [knative-prow-jobs](https://github.com/kabhiibm/test-infra/tree/master/config/jobs/periodic) 

For example: `.env` file for `operator` testing

```bash
KIND_IMAGE=quay.io/powercloud/kind-node
K8S_VERSION=v1.34.1
USE_DOCKER=true
export DEBUG=true

# Test repo related variables
export KNATIVE_ORG=knative
export KNATIVE_REPO=operator
export KNATIVE_RELEASE=main

# Common test variables
export KO_FLAGS='--platform=linux/ppc64le'
export PLATFORM=linux/ppc64le
export KO_DOCKER_REPO=icr.io/upstream-k8s-registry/knative
export DOCKER_CONFIG=/root/.docker

# Test config variables
export INGRESS_CLASS=contour.ingress.networking.knative.dev
#export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
#export SYSTEM_NAMESPACE=knative-eventing
#export SCALE_CHAOSDUCK_TO_ZERO=1

# Eventing KAFKA Broker
#export EVENTING_KAFKA_BROKER_CHANNEL_AUTH_SCENARIO=SASL_SSL
#export EVENTING_NAMESPACE=knative-eventing
#export BROKER_CLASS=Kafka
```

### 5. Start testing/debugging

Run `debug-knative.py` program to setup the KinD (1 master, 1 worker nodes). It will automatically run the admustment scripts for debugging. It will also create and provide a container with testing/debugging environment.

```bash
$ ./debug-knative.py 
Creating Kind cluster...
Running: kind create cluster --config /home/ubuntu/kumar/abhcd/knative-tkn-upstream-ci/debug/kind-config.yaml --name mkpod
Creating cluster "mkpod" ...
 ✓ Ensuring node image (quay.io/powercloud/kind-node:v1.34.1) 🖼
 ✓ Preparing nodes 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-mkpod"
You can now use your cluster with:

kubectl cluster-info --context kind-mkpod

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
Starting container with shell access...
Running: docker run -it --rm --name dev-container --volume /home/ubuntu/kumar/abhcd/knative-tkn-upstream-ci:/mnt --network host --volume /home/ubuntu/.kube:/root/.kube --env KUBECONFIG=/root/.kube/config --volume /home/ubuntu/kumar/abhcd/knative-tkn-upstream-ci/debug/config.json:/root/.docker/config.json --cap-add SYS_PTRACE --security-opt seccomp=unconfined quay.io/p_serverless/knative-prow-tests:debug /bin/bash -c sysctl -w kernel.randomize_va_space=0 && source /mnt/debug/.env && pushd /mnt &&source /mnt/setup-environment.sh &&popd &&env && mkdir -p $GOPATH/src/github.com/$KNATIVE_ORG/$KNATIVE_REPO && git clone https://github.com/$KNATIVE_ORG/$KNATIVE_REPO.git $GOPATH/src/github.com/$KNATIVE_ORG/$KNATIVE_REPO && cd $GOPATH/src/github.com/$KNATIVE_ORG/$KNATIVE_REPO && git checkout $KNATIVE_RELEASE && . /tmp/debug-adjust.sh && . /tmp/adjust.sh && exec bash
sysctl: setting key "kernel.randomize_va_space", ignoring: Read-only file system
/mnt /
Cluster setup started for Knative
namespace/knative-serving created
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
Cluster setup successfully
/
PLATFORM=linux/ppc64le
HOSTNAME=kumar-argo
JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-ppc64el
KNATIVE_ORG=knative
PWD=/
KNATIVE_REPO=operator
HOME=/root
KO_FLAGS=--platform=linux/ppc64le
M2_HOME=/usr/local/maven
TERM=xterm
MAVEN_HOME=/usr/local/maven
SHLVL=1
GOTOOLCHAIN=auto
KUBECONFIG=/root/.kube/config
KO_DOCKER_REPO=icr.io/upstream-k8s-registry/knative
KNATIVE_RELEASE=main
PATH=/usr/local/maven/bin:/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin
DOCKER_CONFIG=/root/.docker
CGO_ENABLED=0
INGRESS_CLASS=contour.ingress.networking.knative.dev
DEBUG=true
DEBIAN_FRONTEND=noninteractive
OLDPWD=/mnt
GOPATH=/go
_=/usr/bin/env
Cloning into '/go/src/github.com/knative/operator'...
remote: Enumerating objects: 69602, done.
remote: Counting objects: 100% (915/915), done.
remote: Compressing objects: 100% (44/44), done.
remote: Total 69602 (delta 876), reused 871 (delta 871), pack-reused 68687 (from 2)
Receiving objects: 100% (69602/69602), 57.24 MiB | 20.28 MiB/s, done.
Resolving deltas: 100% (43386/43386), done.
Updating files: 100% (9033/9033), done.
Already on 'main'
Your branch is up to date with 'origin/main'.
Source code patched successfully for debugging
Source code patched successfully
```

### 6. Start e2e test or debugging

A container shell is automatically provided by the program where any test command can be executed.

Example:

```bash
root@kumar-argo:/go/src/github.com/knative/operator# ./test/e2e-tests.sh --run-tests
```

### 7. Exit test/debug enviroment

Exiting the container shell will automatically destroy the test/debug container and KinD cluster created by `debug-knative.py` program.

```bash
root@kumar-argo:/go/src/github.com/knative/operator# exit
exit
Cleaning up...
Running: kind delete cluster --name mkpod
Deleting cluster "mkpod" ...
Deleted nodes: ["mkpod-control-plane" "mkpod-worker"]
File '/home/ubuntu/kumar/abhcd/knative-tkn-upstream-ci/debug/kind-config.yaml' has been deleted successfully.
```

Note
-----
The `debug-adjust` directory currently contains debugging adjustment scripts for the `main` branch of the repository.

For other branches, create a directory named after the branch, and place the corresponding adjustment script and patch file inside it. Then, update the `KNATIVE_RELEASE` environment variable in the `.env` file with the branch name.

