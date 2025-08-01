#!/bin/bash
#Export USER before test starts
sed -i "/^source.*/a export USER=$\(whoami\)" test/e2e-tests.sh
#Increase e2e timeout to 60m
sed -i "s/\(go_test_e2e.*\)timeout=20m\(.*\).*/\1timeout=40m\2/g" test/e2e-tests.sh
# ppc64le.patch is already copied to tmp during setup-environment.sh run
sed -i "s|K8S_VER_MAJOR|$(echo "$K8S_BUILD_VERSION" | sed -E 's/^v([0-9]+)\.([0-9]+)\..*/\1/')|" /tmp/ppc64le.patch
sed -i "s|K8S_VER_MINOR|$(echo "$K8S_BUILD_VERSION" | sed -E 's/^v([0-9]+)\.([0-9]+)\..*/\2/')|" /tmp/ppc64le.patch
git apply /tmp/ppc64le.patch
echo "Source code patched successfully"
