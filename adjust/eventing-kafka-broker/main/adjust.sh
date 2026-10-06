#!/bin/bash
#Export USER before test starts
sed -i "/^source.*/a export USER=$\(whoami\)" test/e2e-tests.sh
#Increase e2e timeout to 60m
sed -i "s/\(go_test_e2e.*\)timeout=20m\(.*\).*/\1timeout=40m\2/g" test/e2e-tests.sh
# ppc64le.patch is already copied to tmp during setup-environment.sh run
sed -i "s|K8S_VER_MAJOR|$(echo "$K8S_BUILD_VERSION" | sed -E 's/^v([0-9]+)\.([0-9]+)\..*/\1/')|" /tmp/ppc64le.patch
sed -i "s|K8S_VER_MINOR|$(echo "$K8S_BUILD_VERSION" | sed -E 's/^v([0-9]+)\.([0-9]+)\..*/\2/')|" /tmp/ppc64le.patch

# Remove unsupported --zap-log-level flag for keda-adapter v2.11.2
sed -i '/--zap-log-level=error/d' third_party/keda/keda.yaml

# Use Maven archive mirror to avoid rate limiting
sed -i "s|https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.zip|https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip|" data-plane/.mvn/wrapper/maven-wrapper.properties

# Add retry handling to data-plane Maven builds to survive transient Maven Central rate limiting (HTTP 429) during dependency resolution
sed -i 's#\./mvnw clean install -DskipTests || fail_test "failed to install data plane"#./mvnw clean install -DskipTests -Dmaven.wagon.http.retryHandler.count=6 --no-transfer-progress || fail_test "failed to install data plane"#g' hack/data-plane.sh

# Route Maven Central resolution through Google's GCS mirror to avoid Sonatype's consumption-based rate limiting (HTTP 429) from shared Prow-cluster egress.
# See: https://central.sonatype.org/faq/429-error/
mkdir -p "${HOME}/.m2"
cat > "${HOME}/.m2/settings.xml" << 'MVNSETTINGS'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>google-maven-central</id>
      <name>Google Cloud Storage Maven Central mirror</name>
      <url>https://maven-central.storage-download.googleapis.com/maven2/</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
MVNSETTINGS
echo "Installed Maven settings.xml with Google GCS Central mirror at ${HOME}/.m2/settings.xml"

# ko's default base (cgr.dev/chainguard/static) has no ppc64le manifest.
# distroless/static-debian12 publishes ppc64le, arm64, amd64, arm, s390x.
export KO_DEFAULTBASEIMAGE="gcr.io/distroless/static-debian12:nonroot"

#Build eventshub image
export PLATFORM="${PLATFORM:-linux/ppc64le}"
EVENTSHUB_IMG="$(CGO_ENABLED=0 ko publish --platform="${PLATFORM}" -B knative.dev/reconciler-test/cmd/eventshub)"
echo "Eventshub image: ${EVENTSHUB_IMG}"

git apply /tmp/ppc64le.patch
echo "Source code patched successfully"
