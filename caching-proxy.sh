#!/usr/bin/env bash

set -euo pipefail
trap 'echo "ERROR: $BASH_SOURCE:$LINENO $BASH_COMMAND" >&2' ERR

if [[ ! -d /etc/squid ]]; then
	echo "[Caching proxy] installing squid"
	apt-get install squid -y -q
	systemctl enable --now squid
fi

cat <<EOF | sudo tee /etc/squid/squid.conf >/dev/null
acl localnet src 0.0.0.1-0.255.255.255  # RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8             # RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10          # RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16         # RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12          # RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16         # RFC 1918 local private network (LAN)
acl localnet src fc00::/7               # RFC 4193 local private network range
acl localnet src fe80::/10              # RFC 4291 link-local (directly plugged) machines
acl localnet src 127.0.0.1 # this is not in the default Ubuntu config

acl Safe_ports port 80
acl Safe_ports port 443 563 6443

http_access deny !Safe_ports
#http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager


http_access allow localhost
http_access deny to_localhost
http_access deny to_linklocal


include /etc/squid/conf.d/*.conf

http_access deny all

http_port 3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .               0       20%     4320
EOF

cat <<EOF | sudo tee /etc/squid/conf.d/mirror-dstdomain.acl >/dev/null
# mirror-dstdomain.conf
# 
# network destinations that are allowed by this cache

# default ubuntu and ubuntu country archive mirrors
.archive.ubuntu.com 
esm.ubuntu.com
ports.ubuntu.com 
security.ubuntu.com
ddebs.ubuntu.com
mirrors.ubuntu.com

#official third party repositories
.archive.canonical.com
.extras.ubuntu.com

# default changelogs location, this includes changelogs and the meta-release
# file that has information about new ubuntu versions
changelogs.ubuntu.com

# additional destinations can be added to the directory:
#  /etc/squid-deb-proxy/mirror-dstdomain.acl.d
#
#
#
.github.com
.k8s.io
.kubernetes.io
.docker.io
.ghcr.io
.gcr.io
.quay.io
EOF
cat <<EOF | sudo tee /etc/squid/conf.d/caching.conf >/dev/null


http_access allow localnet
acl to_archive_mirrors dstdomain "/etc/squid/conf.d/mirror-dstdomain.acl"
#http_access deny !to_archive_mirrors
cache deny !to_archive_mirrors
#cache deny !localnet

cache_mem 256 MB
maximum_object_size_in_memory 10240 KB

maximum_object_size 2048 MB


cache_dir   ufs     /var/spool/squid/cache    8000   16    256
refresh_pattern deb$   129600 100% 129600
refresh_pattern udeb$   129600 100% 129600
refresh_pattern tar.gz$  129600 100% 129600
refresh_pattern tar.xz$  129600 100% 129600
refresh_pattern tar.bz2$  129600 100% 129600

# refresh_pattern -i github\.com/.*$ 10080 90% 999999 
# refresh_pattern -i kubernetes\.io/.*$ 10080 90% 999999 
# refresh_pattern -i k8s\.io/.*$ 10080 90% 999999 
# refresh_pattern -i ubuntu\.com/.*$ 10080 90% 999999 
refresh_pattern -i docker\.io/.*$ 10080 90% 999999 
refresh_pattern -i ghcr\.io/.*$ 10080 90% 999999 
refresh_pattern -i gcr\.io/.*$ 10080 90% 999999 
refresh_pattern -i quay\.io/.*$ 10080 90% 999999 

EOF

if squid -k parse >/dev/null; then
	squid -k reconfigure
	if [[ ! -d /var/spool/squid/cache ]]; then
		# Just restart, it goes haywire when reconfiguring with a new non existing directory
		systemctl restart squid
	fi
fi

touch /vagrant/.init-caching-proxy

echo "[Caching proxy] done"
