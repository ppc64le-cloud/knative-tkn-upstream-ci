# Knative Infrastructure Overview

This document provides an overview of the infrastructure setup for Knative testing in IBM Cloud, covering virtual server instance (VSI) creation, resource management, and IBM Container Registry (ICR) usage.

## VSI Creation and Resource Management

- Resources are provisioned in the **IBM Cloud account: `2553032 - PCLOUD Upstream CI`**.
- The workspace used for managing infrastructure is **`rdr-knative-prow-testbed-lon06`**.
- **`kubetest2-tf`** (Terraform-based plugin) is utilized for:
  - Automating VSI creation and destruction.
- **CentOS 9** virtual machines (VMs) are deployed as the primary test environment.

## IBM Container Registry (ICR) Usage

- The **`upstream-k8s-registry`** namespace in IBM Container Registry (ICR) is used for storing container images required for Knative testing.
- Authentication to the ICR requires a valid **`config.json`** file.
- For steps to retrieve the **`config.json`** file and correctly configure access to ICR, refer to this [RTC task](https://jazz06.rchland.ibm.com:12443/jazz/web/projects/Power%20Ecosystem#action=com.ibm.team.workitem.viewWorkItem&id=165376).
