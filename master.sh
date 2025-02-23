#!/bin/bash

set -e

# Initialize Kubernetes
echo "[TASK 1] Initialize Kubernetes Cluster"
if [[ ! -d /var/lib/etcd ]]; then
	kubeadm config images pull

	# TODO: add service cidr
	kubeadm init --kubernetes-version="$(cat /root/.kubernetes-version)" --pod-network-cidr=10.244.0.0/16 \
		--control-plane-endpoint="$1" --apiserver-advertise-address="$1"

	rm -rf /vagrant/kubeconfigs
fi

# Copy Kube admin config and restart kubelet service
echo "[TASK 2] Copy kube admin config to Vagrant user .kube directory"
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

CNI=cilium
echo "[TASK 3] Deploy CNI '$CNI'"

if [[ "$CNI" == "flannel" ]]; then
	su - vagrant -c "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
elif [[ "$CNI" == "cilium" ]]; then
	su - vagrant -c "cilium install --version 1.17.1 --wait || true" #; cilium hubble enable; cilium status --wait"
	# su - vagrant -c "cilium upgrade --reuse-values --wait"
fi

INGRESS="nginx"
echo "[TASK 4] Deploy Ingress '$INGRESS'"

if [[ "$INGRESS" == "nginx" ]]; then
	cat <<"EOF" | su - vagrant bash -c -
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	# Do not wait, there is no worker at this point, so it will get deployed when the worker gets added
	helm upgrade -n ingress-nginx --create-namespace --install ingress-nginx ingress-nginx/ingress-nginx --set controller.hostPorts.enabled=true \
		--set controller.hostPort.networkPolicy=false --wait=false
EOF
fi

mkdir -p /vagrant/kubeconfigs

init=1
# Argument 2 is the nodeCount
stop=$2

for ((c = $init; c <= $stop; c++)); do
	kubeconfig_file="/vagrant/kubeconfigs/worker-$c"
	if [[ ! -f "$kubeconfig_file" ]]; then
		kubeadm kubeconfig user --client-name=worker-"$c" >"$kubeconfig_file"
	fi
done

rm -f /vagrant/joincluster.sh
# Generate Cluster join command
echo "[TASK 5] Generate and save cluster join command to /vagrant/joincluster.sh"
kubeadm token create --print-join-command >/vagrant/joincluster.sh
