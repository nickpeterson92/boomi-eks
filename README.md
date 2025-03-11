# AWS EKS with FSx CSI Driver Setup

This guide provides step-by-step instructions to set up and configure an AWS EKS cluster with FSx Lustre storage, including installing the necessary drivers, configuring persistent volumes, and deploying services.

This guide assumes you have successfully run the following terraform commands from within the infra/tf directory:
```sh
terraform init
terraform apply
```

## Prerequisites
- AWS CLI installed and configured
- kubectl installed and configured
- Helm installed
- Terraform installed

---

## 1. Check Cluster and Node Status

### Update kubeconfig to connect to the EKS cluster
```sh
aws eks --region us-west-2 update-kubeconfig --name boomi-eks-cluster
```

### Verify node status
```sh
kubectl get nodes
```

---

## 2. Install FSx CSI Driver

### Add the Helm repository and update
```sh
helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver/
helm repo update
```

### Install the FSx CSI driver
```sh
helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver \
  --namespace kube-system \
  --set node.serviceAccount.create=false \
  --set node.serviceAccount.name=aws-node
```

### Confirm installation
```sh
kubectl get pods -n kube-system | grep fsx
```

---

## 3. Update Terraform Configuration with FSx Details

### Retrieve FSx Lustre details (ID, DNS name, mount points)
```sh
terraform state show module.fsx.aws_fsx_lustre_file_system.this
```

---

## 4. Apply Storage Configurations

### Apply StorageClass
```sh
kubectl apply -f fsx_storage_class.yaml
```

### Apply Persistent Volume (PV)
```sh
kubectl apply -f boomi_pv.yaml
```

### Apply Persistent Volume Claim (PVC)
```sh
kubectl apply -f boomi_pvc.yaml
```

---

## 5. Deploy Configuration and Services

### Deploy JMX exporter configuration
```sh
kubectl apply -f jmx_exporter_config.yaml
```

### Deploy Boomi services and Horizontal Pod Autoscaler (HPA)
```sh
kubectl apply -f boomi_svc.yaml
kubectl apply -f boomi_hpa.yaml
```

---

## 6. Deploy Lustre Client Daemon

```sh
kubectl apply -f lustre-client-installer.yaml
```

### Confirm Deployment
```sh
kubectl get pv
kubectl get pvc
kubectl get configmap
kubectl get svc
kubectl get hpa
```

---

## 7. Connect to EC2 Instances and Install Lustre Client

### SSH or use AWS Session Manager to connect to EC2 instances

### Install Lustre Client
```sh
sudo dnf install -y lustre-client
```

### Validate Installation
```sh
rpm -qa | grep lustre
```

---

## 8. Deploy Boomi StatefulSet
Before deploying the StatefulSet, ensure you generate an install token for your account from Atom Management -> New -> Molecule -> Linux 64 bit -> Generate Token.

Update the INSTALL_TOKEN environment var in the boomi_statefulset.yaml within infra/kube to contain the token value.
```sh
kubectl apply -f boomi_statefulset.yaml
```

---

## 9. Deploy Prometheus Kube Resources
```sh
kubectl apply -f prometheus.yaml
```

### Validate the install
```sh
kubectl get pods -n monitoring
```
---

## Conclusion
You have now successfully set up FSx Lustre storage on an AWS EKS cluster, deployed necessary services, and configured persistent storage for Boomi workloads.

