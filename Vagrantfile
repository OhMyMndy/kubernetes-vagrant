# -*- mode: ruby -*-
# vi: set ft=ruby :

node_count = 1


ip_prefix="192.168.0"
ip_start=100

master_ip = "#{ip_prefix}.#{ip_start}" # .100
proxy_ip = "#{ip_prefix}.2"

# add service and pod cidr
# add cni provider
provision_env = {
  "MASTER_IP": master_ip,
  "PROXY_IP": proxy_ip,
  "WORKER_NODES": node_count,
  "IP_PREFIX": ip_prefix,
  "GATEWAY_IP": "#{ip_prefix}.1"
}

Vagrant.configure(2) do |config|

  # Change to add more workers
  Provider = config.vm.box = ENV['VAGRANT_PROVIDER'] || ENV['VAGRANT_DEFAULT_PROVIDER'] || "libvirt" # change if needed
  config.vm.synced_folder "./", "/vagrant", type: "nfs", nfs_udp: false
  
  # global requirements
  config.vm.provision "shell", path: "requirements.sh", env: provision_env
  config.vm.box = "bento/ubuntu-24.04"



  config.vm.define "caching-proxy" do |vm|
    vm.vm.hostname = "caching-proxy"
    vm.vm.network "private_network", ip: proxy_ip
    vm.vm.provider Provider do |v|
      v.memory = 1024
      v.cpus = 1
    end
    vm.vm.provision "shell", path: "caching-proxy.sh" , env: provision_env
  end
  # Kubernetes Master
  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: master_ip
    master.vm.provider Provider do |v|
      v.memory = 4096
      v.cpus = 2
    end
    master.vm.provision "shell", path: "master.sh", env: provision_env

  end

  (1..node_count).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: "#{ip_prefix}.#{i+9}"
      worker.vm.provider Provider do |v|
        v.memory = 4096
        v.cpus = 2
      end
      worker.vm.provision "shell", path: "worker.sh", env: provision_env
      worker.trigger.before :destroy, on_error: :continue do |trigger|
        trigger.warn = "Draining node..."
        trigger.run = {inline: "vagrant ssh master -c \"kubectl cordon worker-#{i} || true\""}
        trigger.run = {inline: "vagrant ssh master -c \"kubectl drain worker-#{i} || true\""}
        trigger.run = {inline: "vagrant ssh master -c \"kubectl delete node worker-#{i} || true\"" }
      end

    end
  end
end
