Below is a list of commands to run on the cluster and EC2 instances....

// check cluster status
aws eks --region us-west-2 update-kubeconfig --name boomi-eks-cluster

// check node status
kubectl get nodes

// install fsx csi driver
helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver/
helm repo update
helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver \
  --namespace kube-system \
  --set node.serviceAccount.create=false \
  --set node.serviceAccount.name=aws-node

// confirm install
kubectl get pods -n kube-system | grep fsx

// update kube yaml with new fs fields
// you need id, dnsname and mount
// used in boomi_pv and fsx_storage_class
terraform state show module.fsx.aws_fsx_lustre_file_system.this

// apply storage class
kubectl apply -f fsx-storage-class.yaml

// apply persistent volume
kubectl apply -f boomi_pv.yaml

// apply persistent volume claim
kubectl apply -f boomi_pvc.yaml

// deploy config and svcs
kubectl apply -f jmx_exporter_config.yaml
kubectl apply -f boomi_svc.yaml
kubectl apply -f boomi_hpa.yaml

// deploy lustre client daemon
kubectl apply -f lustre-client-installer.yaml

// confirm
kubectl get pv
kubectl get pvc
kubectl get configmap
kubectl get svc
kubectl get hpa

// ssh or session manager into ec2 instances
sudo dnf install -y lustre-client

// validate install
rpm -qa | grep lustre

// deploy stateful set
kubectl apply -f boomi_statefulset.yaml
