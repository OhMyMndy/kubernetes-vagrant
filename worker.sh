#!/bin/bash

set -e
# Join worker nodes to the Kubernetes cluster
echo "[TASK 1] Join node to Kubernetes Cluster"
if [[ ! -f /etc/kubernetes/kubelet.conf ]]; then
	bash /vagrant/joincluster.sh
fi

mkdir -p ~vagrant/.kube
rm -f ~vagrant/.kube/config

cp "/vagrant/kubeconfigs/$HOSTNAME" ~vagrant/.kube/config
chown vagrant:vagrant ~vagrant/.kube
