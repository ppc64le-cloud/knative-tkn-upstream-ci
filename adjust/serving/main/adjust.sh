#!/bin/bash

# Export USER before test starts, otherwise a test stops
sed -i "/^source.*/a export USER=$\(whoami\)" test/e2e-tests.sh
sed -i "/^initialize.*/a export SHORT=1" test/e2e-tests.sh

# Slow down an interval of kapp checking a status of k8s cluster otherewise will face 'connection refused' frequently
sed -i 's/\(.*run_kapp deploy\)\(.*\)/\1 --wait-check-interval=45s --wait-concurrency=1 --wait-timeout=30m\2/' test/e2e-common.sh

# Decrease a level of parallelism to 1 (the same as the number of worker nodes in KinD)
sed -i "s/^\(parallelism=\).*/\1\"-parallel 1\"/" test/e2e-tests.sh

# Set the number of replicas to 1 for stable test results
sed -i 's/\(.*replicas: \).*/\11/' test/config/ytt/ingress/kourier/kourier-replicas.yaml

#Place overlay
cp /tmp/overlay-ppc64le.yaml test/config/ytt/core/overlay-ppc64le.yaml
