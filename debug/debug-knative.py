#!/usr/bin/env python3

import subprocess
import os
import signal
import yaml

import argparse
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up argument parser
parser = argparse.ArgumentParser(description="Read config from CLI or .env")

# Define arguments
parser.add_argument("--kind_image", type=str, help="kind node image")
parser.add_argument("--k8s_version", type=str, help="kubernetes version")
parser.add_argument("--use_docker", type=str, help="flag to use docker when true or podman when false")

# Parse arguments
args = parser.parse_args()

# Fallback to environment variables if arguments are not provided
kind_image = args.kind_image or os.getenv("KIND_IMAGE")
k8s_version = args.k8s_version or os.getenv("K8S_VERSION")
use_docker = args.use_docker or os.getenv("USE_DOCKER", "True").lower() == "true"
knative_org = os.getenv("KNATIVE_ORG")
knative_repo = os.getenv("KNATIVE_REPO")
knative_release = os.getenv("KNATIVE_RELEASE")
#use_docker = True  # Set to False to use Podman
#repo_url = f"https://github.com/{knative_org}/{knative_repo}.git"  # Replace with actual repo
repo_url = "https://github.com/$KNATIVE_ORG/$KNATIVE_REPO.git"  # Replace with actual repo

# Extract repo name from URL
repo_name = repo_url.rstrip("/").split("/")[-1]
#clone_path = f"/go/src/github.com/{knative_org}/{knative_repo}"
clone_path = "$GOPATH/src/github.com/$KNATIVE_ORG/$KNATIVE_REPO"


# Configuration
container_name = "dev-container"
#image_name = "quay.io/powercloud/knative-prow-tests:latest"
image_name = "quay.io/p_serverless/knative-prow-tests:debug"
mount_dir = os.path.abspath("./..")
kind_cluster_name = "mkpod"
kubeconfig_dir = os.path.expanduser("~/.kube")

def run_cmd(cmd, check=True, capture_output=False):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture_output, text=True)
'''
def create_kind_cluster():
    run_cmd(["kind", "create", "cluster", "--image", f"{kind_image}:{k8s_version}", "--name", kind_cluster_name])
'''
def create_kind_cluster():
    # Define the config    
    kind_config = {
        "kind": "Cluster",
        "apiVersion": "kind.x-k8s.io/v1alpha4",
        "nodes": [
            {
                "role": "control-plane",
                "extraMounts": [
                    {
                        "hostPath": f"{mount_dir}/debug/config.json",
                        "containerPath": "/var/lib/kubelet/config.json"
                    }
                ]
            }
        ]
    }

    # Save to YAML
    with open(f"{mount_dir}/debug/kind-config.yaml", "w") as f:
        yaml.dump(kind_config, f)

    run_cmd(["kind", "create", "cluster", "--image", f"{kind_image}:{k8s_version}", "--config", f"{mount_dir}/debug/kind-config.yaml", "--name", kind_cluster_name])

def delete_kind_cluster():
    run_cmd(["kind", "delete", "cluster", "--name", kind_cluster_name])
    try:
        file_path = f"{mount_dir}/debug/kind-config.yaml"
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"File '{file_path}' has been deleted successfully.")
        else:
            print(f"File '{file_path}' does not exist.")
    except Exception as e:
        print(f"An error occurred while deleting the file: {e}")

def start_container():
    runtime = "docker" if use_docker else "podman"
    run_cmd([
        runtime, "run", "-it", "--rm",
        "--name", container_name,
        "--volume", f"{mount_dir}:/mnt",
        "--network", "host",  # Allows access to Kind cluster
        "--volume", f"{kubeconfig_dir}:/root/.kube",
        "--env", "KUBECONFIG=/root/.kube/config",
        "--volume", f"{mount_dir}/debug/config.json:/root/.docker/config.json",
        "--cap-add", "SYS_PTRACE",
        "--security-opt", "seccomp=unconfined",
        image_name,
        "/bin/bash", "-c",
        # Disable ASLR only inside the container
        "sysctl -w kernel.randomize_va_space=0 && "
        "source /mnt/debug/.env && "
        "pushd /mnt &&"
        "source /mnt/setup-environment.sh &&"
        "popd &&"
        "env && "
        f"mkdir -p {clone_path} && "
        f"git clone {repo_url} {clone_path} && "
        f"cd {clone_path} && "
        "git checkout $KNATIVE_RELEASE && "
        ". /tmp/debug-adjust.sh && "
        ". /tmp/adjust.sh && "
        f"exec bash"
    ])

def main():
    try:
        os.makedirs(mount_dir, exist_ok=True)
        print("Creating Kind cluster...")
        create_kind_cluster()

        print("Starting container with shell access...")
        start_container()

    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
    finally:
        print("Cleaning up...")
        delete_kind_cluster()

if __name__ == "__main__":
    main()
