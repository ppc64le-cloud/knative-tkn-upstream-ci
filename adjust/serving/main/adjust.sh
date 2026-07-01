#!/bin/bash

# Export USER before test starts
sed -i "/^source.*/a export USER=\$(whoami)" test/e2e-tests.sh
sed -i "/^initialize.*/a export SHORT=1" test/e2e-tests.sh

# Slow down kapp checks
sed -i 's/\(.*run_kapp deploy\)\(.*\)/\1 --wait-check-interval=45s --wait-concurrency=1 --wait-timeout=30m\2/' test/e2e-common.sh

# Reduce parallelism
sed -i "s/^\(parallelism=\).*/\1\"-parallel 1\"/" test/e2e-tests.sh

# Reduce replicas
sed -i 's/\(.*replicas: \).*/\11/' test/config/ytt/ingress/kourier/kourier-replicas.yaml

# Apply test patch (loopback fix)
echo "Applying loopback patch"
PATCH_FILE="/tmp/skip-loopback.patch"

if [ ! -f "$PATCH_FILE" ]; then
  echo "Patch file not found: $PATCH_FILE"
  exit 1
fi
git apply "$PATCH_FILE"

# Post-install script
cat << 'EOF' > /tmp/post-install-fix.sh
#!/bin/bash
set +e

echo "Starting post-install setup..."

# Wait for Kourier namespace and gateway deployment before starting tests.
until kubectl get ns kourier-system >/dev/null 2>&1; do
  sleep 2
done

kubectl wait --for=condition=available deploy/3scale-kourier-gateway -n kourier-system --timeout=180s || true

# Applying cluster fixes
kubectl delete deployment chaosduck -n knative-serving --ignore-not-found || true
kubectl delete hpa activator -n knative-serving --ignore-not-found || true
kubectl delete hpa webhook -n knative-serving --ignore-not-found || true
kubectl scale deployment activator --replicas=2 -n knative-serving || true

# Waiting for Knative core components
kubectl rollout status deployment/controller -n knative-serving --timeout=300s || true
kubectl rollout status deployment/autoscaler -n knative-serving --timeout=300s || true
kubectl rollout status deployment/activator -n knative-serving --timeout=300s || true

echo "Giving system time to stabilize..."
sleep 30

# Cleanup old forwards before starting a new one
echo ">>> Cleaning up old Kourier port-forwards..."
if [[ -f /tmp/kourier-portforward.pid ]]; then
  OLD_PID=$(cat /tmp/kourier-portforward.pid)
  kill "${OLD_PID}" 2>/dev/null || true
  sleep 2
  kill -9 "${OLD_PID}" 2>/dev/null || true
  rm -f /tmp/kourier-portforward.pid
fi

pkill -f "port-forward.*kourier" 2>/dev/null || true
sleep 2

# Start persistent port-forward supervisor
echo ">>> Starting Kourier port-forward supervisor..."
(
  trap 'exit 0' TERM INT

  while true; do
    kubectl get svc kourier \
      -n kourier-system >/dev/null 2>&1 || {
      sleep 5
      continue
    }

    echo ">>> $(date) starting port-forward" >> /tmp/kourier-pf.log

    kubectl port-forward \
      -n kourier-system \
      service/kourier \
      31470:80 \
      31475:443 \
      >> /tmp/kourier-pf.log 2>&1

    echo ">>> $(date) port-forward exited" >> /tmp/kourier-pf.log
    sleep 2
  done
) &

PF_PID=$!
echo "${PF_PID}" > /tmp/kourier-portforward.pid
echo ">>> Port-forward supervisor PID=${PF_PID}"
EOF

chmod +x /tmp/post-install-fix.sh

# Run post-install fixes after ingress environment variables are configured
sed -i '/setup_ingress_env_vars/a\echo ">>> Running post-install fixes..." ; /tmp/post-install-fix.sh' test/e2e-common.sh

# Cleanup script
cat <<'EOF' > /tmp/kourier-cleanup.sh
#!/bin/bash
set +e
if [[ -f /tmp/kourier-portforward.pid ]]; then
  PID=$(cat /tmp/kourier-portforward.pid)
  kill "${PID}" 2>/dev/null || true
  sleep 2
  kill -9 "${PID}" 2>/dev/null || true
  rm -f /tmp/kourier-portforward.pid
fi

pkill -f "port-forward.*kourier" 2>/dev/null || true
sleep 2
EOF

chmod +x /tmp/kourier-cleanup.sh

# Cleanup on failure and success
sed -i '/(( failed )) && fail_test/i\source /tmp/kourier-cleanup.sh' test/e2e-tests.sh
sed -i '/^success$/i\source /tmp/kourier-cleanup.sh' test/e2e-tests.sh

# Place overlay
cp /tmp/overlay-ppc64le.yaml test/config/ytt/core/overlay-ppc64le.yaml
