# Knative Upstream CI

### Introduction
Knative is an open-source platform for serverless workloads on Kubernetes, streamlining the deployment and management of serverless applications by handling infrastructure details, letting developers concentrate on code, and include features like auto-scaling and event-driven capabilities, which uses [Prow](https://docs.prow.k8s.io/) a Kubernetes-native CI/CD system to automate and manage their CI workflows.

### Enabling CI for a New Knative Release
When a new Knative release is available, we need to enable CI for ppc64le. Follow this [document](./new-release.md) to configure and validate CI for the new releases.

### Running Knative E2E tests locally
When encountering test failures in any Knative component, you may need to debug and verify your fixes before raising a PR. To run specific tests locally and validate your changes:
- Using Prow setup, refer to this [documentation](./testing-local-using-prow-setup.md).
- Using KinD setup, refer to this [documentation](./testing-local-using-kind.md).

### Knative infra
This [document](./kn-infra.md) provides insights into the infrastructure setup for Knative in IBM Cloud, detailing resource creation, image usage, and registry configurations.

### PPC64le-specific Knative images
Few Knative images are not multi-arch. To support testing on ppc64le, we have manually built these images locally and pushed them to IBM Cloud Registry (ICR).
For a complete list of images used for testing on ppc64le, refer this [image manifest](./images/README.md).

### Knative component enablement status & Job schedule
Refer this [doc](./job-schedule-status.md) to find the job schedule & enablement status of each Knative component.
