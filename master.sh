#!/bin/bash

set -euo pipefail
trap 'echo "ERROR: $BASH_SOURCE:$LINENO $BASH_COMMAND" >&2' ERR

# Initialize Kubernetes
echo "[Control plane] setting up control plane"
if [[ ! -d /var/lib/etcd ]]; then
	kubeadm config images pull

	# TODO: add service cidr
	kubeadm init --kubernetes-version="$(cat /root/.kubernetes-version)" --pod-network-cidr=10.244.0.0/16 \
		--control-plane-endpoint="${MASTER_IP}" --apiserver-advertise-address="${MASTER_IP}" \
		--skip-phases=addon/kube-proxy

	rm -rf /vagrant/kubeconfigs
fi

# Copy Kube admin config and restart kubelet service
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "[Control plane] waiting for Kubernetes to be ready"
while true; do
	if timeout 4 su - vagrant -c "kubectl get pod" 2>/dev/null; then
		break
	fi
	sleep 5
	echo "[Control plane] waiting for Kubernetes to be ready..."
done

# Allow scheduling on control-plane for now
su - vagrant -c "kubectl taint node master node-role.kubernetes.io/control-plane-" || true

CNI=cilium

echo "[Control plane] set up CNI '$CNI'"

if [[ "$CNI" == "flannel" ]]; then
	echo "[Control plane] installing flannel"
	su - vagrant -c "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
elif [[ "$CNI" == "cilium" ]]; then
	echo "[Control plane] installing cilium"
	cat <<EOF | su - vagrant bash -c -
	set -ex
	helm repo add cilium https://helm.cilium.io/
	helm upgrade --install cilium cilium/cilium --version 1.17.1 \
     --namespace kube-system \
     --reuse-values \
     --set egressGateway.enabled=true \
     --set bpf.masquerade=true \
     --set kubeProxyReplacement=true \
     --set k8sServiceHost="$MASTER_IP" \
     --set k8sServicePort=6443 --wait \
     --set operator.replicas=1
EOF
fi

mkdir -p /vagrant/kubeconfigs

init=1
# Argument 2 is the nodeCount
stop=$WORKER_NODES

echo "[Control plane] create kubeconfig files for worker nodes"

for ((c = $init; c <= $stop; c++)); do
	user="worker-$c"
	kubeconfig_file="/vagrant/kubeconfigs/$user"
	if [[ ! -f "$kubeconfig_file" ]]; then
		kubeadm kubeconfig user --client-name="$user" >"$kubeconfig_file"
		su - vagrant bash -c "kubectl delete clusterrolebinding \"$user-edit\" --force >/dev/null || true"
		su - vagrant bash -c "kubectl create clusterrolebinding \"$user-edit\" --clusterrole=edit --user=\"$user\""
	fi
done

# Generate Cluster join command
echo "[Control plane] create join command"
kubeadm token create --print-join-command >/vagrant/joincluster.sh

INGRESS="nginx"
echo "[Control plane] deploying ingress '$INGRESS'"

if [[ "$INGRESS" == "nginx" ]]; then
	cat <<"EOF" | su - vagrant bash -c -
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	timeout 60 helm upgrade --install ingress-nginx ingress-nginx \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      --set controller.hostNetwork=true \
      --set controller.hostPort.enabled=true \
      --set controller.kind=DaemonSet \
      --set rbac.create=true \
      --set controller.service.type=ClusterIP --wait >/dev/null
EOF
fi

echo "[Control plane] done"
