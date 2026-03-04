#!/bin/bash

cmd_line="./kn service create svc1 --no-wait --image \$img -e TARGET=Knative -n \$ns || fail_test\n  ./kn service create svc1 --no-wait --image \$img -e TARGET=Knative -n \$ns1 || fail_test\n  sleep 16\n  kubectl delete ns \$ns \$ns1\n  kubectl create ns \$ns || fail_test\n  kubectl create ns \$ns1 || fail_test\n  sleep 16"

go build -o kn cmd/kn/main.go
sed -i "/^source.*/a export USER=$\(whoami\)" test/e2e-tests.sh

echo "Increase e2e timeout to 90m"
sed -i "s/\(go_test_e2e.*\)timeout=45m\(.*\).*/\1timeout=90m\2/g" test/e2e-tests.sh

sed -i "/sleep.*/a\  ${cmd_line}" test/e2e-tests.sh

# patch serving deployment for accessing private registry
# https://knative.dev/docs/serving/tag-resolution/#custom-certificates
cmd="kubectl set env deployment/controller -n knative-serving DOCKER_CONFIG=/.docker && kubectl patch cm config-deployment -n knative-serving --type json --patch '[{ \"op\": \"add\", \"path\": \"/data/registriesSkippingTagResolving\", \"value\": \"icr.io\" }]'"
sed -i "/.*Installing Knative Eventing.*/i\  ${cmd}\n  kubectl wait --for=condition=available --timeout=600s deployment/controller -n knative-serving" test/common.sh
cmd="kubectl set env deployment/controller -n knative-serving SSL_CERT_FILE=/opt/certs/ssl.crt"
sed -i "/.*Installing Knative Eventing.*/i\  ${cmd}\n  kubectl wait --for=condition=available --timeout=600s deployment/controller -n knative-serving" test/common.sh
# volume-mount.json is already copied to tmp during setup-environment.sh run
cmd="kubectl patch deploy controller -n knative-serving --patch \"\$(cat /tmp/volume-mount.yaml)\""
sed -i "/.*Installing Knative Eventing.*/i\  ${cmd}\n  kubectl wait --for=condition=available --timeout=600s deployment/net-contour-controller -n knative-serving" test/common.sh
