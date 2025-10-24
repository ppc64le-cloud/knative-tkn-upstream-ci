# syntax=docker/dockerfile:1.4
# docker buildx build --platform linux/ppc64le -t quay.io/p_serverless/knative-prow-tests:debug   --load -f Dockerfile .
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS base

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    vim \
    curl \
    wget \
    git \
    bash \
    unzip \
    gnupg \
    ansible \
    build-essential \
    file \
    gcc \
    make \
    mercurial \
    pkg-config \
    rsync \
    xz-utils \
    zlib1g-dev \
    gcc \
    python3-dev \
    python3-pip \
    apt-transport-https \
    lsb-release \
    openssh-client \
    ca-certificates \
    software-properties-common \
    bison \
    uuid-runtime \
    shellcheck \
    zip \
    jq \
    procps \
    net-tools \
    gnuplot \
    bsdextrautils \
    gettext-base \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ARG GO_VERSION=1.24.7
RUN curl -LO https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Install ko
RUN curl -LO https://github.com/ko-build/ko/releases/latest/download/ko_Linux_${TARGETARCH}.tar.gz && \
    tar -xzf ko_Linux_${TARGETARCH}.tar.gz -C /usr/local/bin && \
    rm ko_Linux_${TARGETARCH}.tar.gz

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install gcloud CLI
RUN if [ "$TARGETARCH" != "ppc64le" ] && [ "$TARGETARCH" != "s390x" ]; then \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-sdk \
    else echo "Skipping gcloud CLI for unsupported arch: $TARGETARCH"; \
    fi

# Install yq
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_$TARGETARCH -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Extra tools through go install
# These run using the golang image version of Go, not any defined by `gvm`
ARG KO_VERSION=v0.15.2
ARG KAIL_VERSION=v0.17.4
ARG GOTESTSUM_VERSION=v1.11.0
ARG PROTOC_GEN_GO_VERSION=v1.28.0
ARG GO_LICENSES_VERSION=v1.6.0
ARG JSONNET_VERSION=v0.18.0
ARG COSIGN_VERSION=v1.13.6
ARG TOOLBOX_VERSION=cdf9cf656d1402c5c8ca558ef7f7b7ef2ff9093b

# Disable CGO libs to avoid error with too old version in base image
ENV CGO_ENABLED=0
# Disable Go' toolchain operation, and stick to the version installed
ENV GOTOOLCHAIN=auto

RUN go install rsc.io/goversion@v1.2.0

RUN go install github.com/google/ko@${KO_VERSION}
RUN go install github.com/boz/kail/cmd/kail@${KAIL_VERSION}
RUN go install gotest.tools/gotestsum@${GOTESTSUM_VERSION}
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}
RUN go install github.com/google/go-licenses@${GO_LICENSES_VERSION}
RUN go install github.com/google/go-jsonnet/cmd/jsonnet@${JSONNET_VERSION}
RUN go install github.com/sigstore/cosign/cmd/cosign@${COSIGN_VERSION}
RUN go install knative.dev/toolbox/provenance-generator@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/flaky-test-reporter@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/pkg/clustermanager/perf-tests@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/kntest/cmd/kntest@${TOOLBOX_VERSION}

#
# BEGIN: JAVA SETUP (This is for eventing-kafka-broker and kn-func)
#
ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.8.4

RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo \
    "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/adoptium.list
RUN apt-get update -qqy && \
    apt-get install -qqy temurin-${JAVA_VERSION}-jdk && \
    rm -rf /var/lib/apt/lists/*

# TODO: add options for multi-arch build
ENV JAVA_HOME=/usr/lib/jvm/temurin-${JAVA_VERSION}-jdk-ppc64el

ENV MAVEN_HOME=/usr/local/maven
ENV M2_HOME=$MAVEN_HOME
ENV PATH=${M2_HOME}/bin:${PATH}

RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz -o /tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar xf /tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /tmp && \
    mv /tmp/apache-maven-${MAVEN_VERSION} $MAVEN_HOME

RUN java -version && \
    mvn -v

#
# END: JAVA SETUP
#

# Final image
FROM base AS final
CMD ["/bin/bash"]
