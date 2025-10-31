# Running New Prow Jobs Locally  

## Prerequisites  

- **x86 Fedora VM** with KinD installed.  
- **Required Secrets:**  
  - `knative-ssh`: SSH key to access Knative VSIs.  
  - `IBM Cloud API key`: Used to create/delete VSIs in IBM Cloud.  
  - `config.json`: Required for cluster access to IBM Container Registry.  

📌 **For the secrets manifest file, contact:**  
[Valen Mascarenhas](mailto:Valen.Mascarenhas@ibm.com) or [Kumar Abhishek](mailto:Kumar.Abhishek2@ibm.com).  

---

## 1. Create a KinD Cluster  

Run the following command to create a KinD cluster:  

```bash
kind create cluster --name=mkpod
```  

---

## 2. Apply Secrets to the Cluster  

Once you have the manifest file, apply the secrets:  

```bash
kubectl apply -f <secrets-manifest-file>
```  

---

## 3. Fork, Clone, and Configure the Prow Job  

### Fork & Clone the `test-infra` Repository  

```bash
git clone https://github.com/<your-org>/test-infra.git
cd test-infra
```

### Export Environment Variables  

You'll need to export 3 key variables:  

- `CONFIG_PATH`: Path to the main Prow configuration file.  
- `JOB_CONFIG_PATH`: Path to the job configuration file for the specific Knative component.  
- `JOB_NAME`: Name of the job to test. You can find this in the job config file (`name` field).  

Example for testing the **main release of the Knative Client component**:  

```bash
# Export the path to the main Prow configuration file
export CONFIG_PATH=$(pwd)/config/prow/config.yaml

# Export the path to the job configuration file for periodic Knative Client jobs
export JOB_CONFIG_PATH=$(pwd)/config/jobs/periodic/knative/client/main/client-main.gen.yaml

# Export the job name
export JOB_NAME="knative-client-main-periodic"
```

### Clone Prow and Run the Job Locally  

```bash
git clone https://github.com/kubernetes-sigs/prow.git
cd prow/pkg

# Run the Prow job locally
./pj-on-kind.sh $JOB_NAME
```

You'll be prompted to enter two secrets. You can leave them blank by pressing **ENTER**.  

If everything is set up correctly, the output should resemble:  

```bash
NAME                                   READY   STATUS     RESTARTS   AGE
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   0/2     Init:0/3   0          0s
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   0/2     Init:0/3   0          1s
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   0/2     Init:1/3   0          7s
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   0/2     Init:2/3   0          8s
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   0/2     PodInitializing   0          9s
cd423fb9-0dd7-4bf8-90da-b157ca2b85cb   2/2     Running           0          10s
```

---

## 4. Check Pod Logs  

Monitor the running Prow job logs using:  

```bash
kubectl logs -f <pod-name>
```

Example:
```bash
kubectl logs -f cd423fb9-0dd7-4bf8-90da-b157ca2b85cb
```

---

## 5. Commit and Raise a PR  

Once your changes have been tested successfully, commit them and create a PR to upstream the configurations.

