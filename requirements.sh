#!/bin/bash

set -euo pipefail
trap 'echo "ERROR: $BASH_SOURCE:$LINENO $BASH_COMMAND" >&2' ERR

KUBERNETES_MAJOR_VERSION="1.31"
KUBERNETES_MINOR_VERSION="6"
KUBERNETES_VERSION="${KUBERNETES_MAJOR_VERSION}.${KUBERNETES_MINOR_VERSION}"
KUBERNETES_PACKAGE_VERSION="$KUBERNETES_VERSION-1.1"

export KUBERNETES_MAJOR_VERSION
export KUBERNETES_MINOR_VERSION
export KUBERNETES_VERSION
echo "$KUBERNETES_VERSION" >/root/.kubernetes-version

# Workers need to be able to resolve hostname of the master
if ! grep -q "$MASTER_IP master" /etc/hosts; then
	echo "[Requirements] add master to hosts file"
	echo "$MASTER_IP master master" | tee -a /etc/hosts
fi

echo "[Requirements] disabling swap"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[Requirements] set default network interface"
# Set primary IP
# TODO: fix this
sudo ip route del default dev eth0
sudo ip route add default via "$GATEWAY_IP" dev eth1


if [[ ! -f /usr/local/bin/wtfutil ]]; then
  echo "[Requirements] installing wtfutil"
  cd /tmp
  curl -SsL https://github.com/wtfutil/wtf/releases/download/v0.43.0/wtf_0.43.0_linux_amd64.tar.gz -o wtf.tgz
  tar xzvf wtf.tgz
  install -m 775 wtf_*/wtfutil /usr/local/bin/wtfutil
  rm -rf wtf_* wtf.tgz
fi

apt-get install bash-completion -y
if [[ "$HOSTNAME" == "caching-proxy" ]]; then
	rm -f /etc/apt/apt.conf.d/99-proxy
	exit 0
fi

echo "[Requirements] waiting for proxy to be configured"
while true; do
	if [[ -f /vagrant/.init-caching-proxy ]]; then
		break
	fi
	sleep 5
	echo "[Requirements] waiting for proxy to be configured..."
done

echo "[Requirements] set up proxy"
# if timeout 2 nc -z $PROXY_IP 3128 &>/dev/null; then
# Configure proxy
export HTTP_PROXY="http://${PROXY_IP}:3128"
export HTTPS_PROXY="$HTTP_PROXY"
export NO_PROXY=10.0.0.0/8,172.0.0.0/8,127.0.0.1,192.168.0.0/16

if ! grep -q "export HTTP_PROXY" ~/.profile; then
	echo "export HTTP_PROXY=\"http://${PROXY_IP}:3128\"" | tee -a ~/.profile ~vagrant/.profile
fi
if ! grep -q "export HTTPS_PROXY" ~/.profile; then
	echo "export HTTPS_PROXY=\"$HTTP_PROXY\"" | tee -a ~/.profile ~vagrant/.profile
fi
if ! grep -q "export NO_PROXY" ~/.profile; then
	echo "export NO_PROXY=10.0.0.0/8,172.0.0.0/8,127.0.0.1,192.0.0.0/8" | tee -a ~/.profile ~vagrant/.profile
fi
chown vagrant:vagrant ~vagrant/.profile
echo "Acquire::http::Proxy \"http://${PROXY_IP}:3128\";" | sudo tee /etc/apt/apt.conf.d/99-proxy >/dev/null
echo "Acquire::https::Proxy \"http://${PROXY_IP}:3128\";" | sudo tee -a /etc/apt/apt.conf.d/99-proxy >/dev/null
# fi

init=2
stop=$WORKER_NODES

echo "[Requirements] configure workers in hostfile"
for ((c = $init; c <= $stop; c++)); do
	worker="$(($c - 1))"
	ip="${IP_PREFIX}.$c"
	if ! grep -q "$ip" /etc/hosts; then
		echo "$ip worker-$worker worker-$worker" | tee -a /etc/hosts
	fi
done

if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
	echo "[Requirements] set up Kubernetes keyring"
	rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	mkdir -p /etc/apt/keyrings
	chmod 755 /etc/apt/keyrings
	curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MAJOR_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

if [[ ! -d /var/lib/containerd ]]; then
	echo "[Requirements] install Containerd"

	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y

	apt-get install containerd -y -q
	sudo mkdir -p /etc/containerd
	containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
	sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
	apt-get install -y conntrack
	systemctl restart containerd
fi

echo "[Requirements] configuring sysctl"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

# Installing Kubernetes
if [[ ! -d /var/lib/kubelet ]]; then
	echo "[Requirements] install Kubernetes components"

	echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MAJOR_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	apt-get update -y
	apt-get install -y kubelet="$KUBERNETES_PACKAGE_VERSION" kubeadm="$KUBERNETES_PACKAGE_VERSION" kubectl="$KUBERNETES_PACKAGE_VERSION"
	apt-mark hold kubelet kubeadm kubectl
	systemctl enable --now kubelet
fi

if ! command -v arkade &>/dev/null; then
	echo "[Requirements] install Arkade"
	curl -sLS https://get.arkade.dev | sudo sh >/dev/null
fi

echo "[Requirements] setting up Kubernetes tools"
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
	if [[ ! -f ~/.krew/bin/kubectl-"$pkg" ]]; then
		~/.arkade/bin/krew install "$pkg" >/dev/null
	fi
done

EOF

cat <<"EOF" | su - vagrant bash -c -
if ! grep -q "alias k=kubectl" ~/.profile; then
  echo 'alias k=kubectl' >> ~/.profile
fi
EOF

cat <<"EOF" | su - vagrant bash -c -
if ! grep -q "helm completion" ~/.profile; then
  echo 'source <(helm completion bash)' >> ~/.profile
fi
EOF

cat <<"EOF" | su - vagrant bash -c -
if ! grep -q "kubectl completion" ~/.profile; then
  echo 'source <(kubectl completion bash)' >> ~/.profile
fi
EOF
cat <<"EOF" | su - vagrant bash -c -
if ! grep -q "complete -F __start_kubectl" ~/.profile; then
  echo 'complete -F __start_kubectl k' >> ~/.profile
fi
EOF
echo "[Requirements] done"
