#!/bin/bash

set -euo pipefail
trap 'echo "ERROR: $BASH_SOURCE:$LINENO $BASH_COMMAND" >&2' ERR

# Join worker nodes to the Kubernetes cluster
echo "[Worker] Join node to Kubernetes Cluster"
if [[ ! -f /etc/kubernetes/kubelet.conf ]]; then
	while true; do
		if [[ -f /vagrant/joincluster.sh ]]; then
			timeout 30 bash -x /vagrant/joincluster.sh
			break
		fi
		sleep 5
		echo "[Worker] Join node to Kubernetes Cluster..."
	done
fi

mkdir -p ~vagrant/.kube
rm -f ~vagrant/.kube/config

echo "[Worker] setting up kubeconfig"
kubeconfig="/vagrant/kubeconfigs/$HOSTNAME"
while true; do
	if [[ -f "$kubeconfig" ]]; then
		cp "$kubeconfig" ~vagrant/.kube/config
		chown vagrant:vagrant ~vagrant/.kube
		break
	fi
	sleep 5
	echo "[Worker] setting up kubeconfig..."
done
echo "[Worker] done"
