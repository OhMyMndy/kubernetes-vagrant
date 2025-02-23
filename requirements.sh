#!/bin/bash

set -e

KUBERNETES_MAJOR_VERSION="1.31"
KUBERNETS_MINOR_VERSION="6"
KUBERNETES_VERSION="${KUBERNETES_MAJOR_VERSION}.${KUBERNETS_MINOR_VERSION}"
KUBERNETES_PACKAGE_VERSION="$KUBERNETES_VERSION-1.1"
echo "$KUBERNETES_VERSION" >/root/.kubernetes-version
echo "[TASK 1] update hosts"
echo '192.168.10.100 master master' | tee -a /etc/hosts

init=2
stop=$1+1

for ((c = $init; c <= $stop; c++)); do
	worker="$(($c - 1))"
	ip="192.168.10.$c"
	if ! grep -q "$ip" /etc/hosts; then
		echo "$ip worker$worker worker$worker" | tee -a /etc/hosts
	fi
done

echo "[TASK 2] Install containerd"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

apt-get install containerd -y
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Disable swap
echo "[TASK 4] Disable SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

# Installing Kubernetes
echo "[TASK 5] Kubernetes"

if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
	mkdir -p /etc/apt/keyrings
	chmod 755 /etc/apt/keyrings
	curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MAJOR_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MAJOR_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet="$KUBERNETES_PACKAGE_VERSION" kubeadm="$KUBERNETES_PACKAGE_VERSION" kubectl="$KUBERNETES_PACKAGE_VERSION"
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

# Containerd configuration
echo "[TASK 6] containerd configuration"
apt-get install -y conntrack

# Restarting services
echo "[TASK 7] restarting services"
systemctl restart containerd
systemctl restart kubelet

if ! command -v arkade &>/dev/null; then
	curl -sLS https://get.arkade.dev | sudo sh
fi

cat <<"EOF" | su - vagrant bash -c -
if ! grep -q .arkade/bin ~/.profile; then
  echo 'export PATH=$PATH:$HOME/.arkade/bin/' >> ~/.profile
fi
if ! grep -q 'KREW_ROOT:' ~/.profile; then
  echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.profile
fi

pkgs="kubectl krew helm cilium hubble trivy jq yq talosctl kubectx kubens k9s kustomize helmfile"
for pkg in $pkgs; do
	if [[ ! -f ~/.arkade/bin/"$pkg" ]]; then
		arkade get $pkg --quiet
	fi
done
if ! ~/.arkade/bin/helm plugin list | tail -n +2 | cut -f1 | grep -q helm-git; then
	~/.arkade/bin/helm plugin install https://github.com/aslafy-z/helm-git --version 1.3.0
fi
pkgs="envsubst cert-manager graph kubescape kyverno"
for pkg in $pkgs; do
	~/.arkade/bin/krew install "$pkg" >/dev/null
done

EOF

cat <<"EOF" | su - vagrant bash -c -
if ! grep -q "alias k=kubectl"; then
  echo 'alias k=kubectl' >> ~/.profile
fi
EOF
