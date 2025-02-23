# -*- mode: ruby -*-
# vi: set ft=ruby :

ip_prefix="192.168.0"
ip_start=100

# TODO: create map to pass to provisioner
master_hosts=""
worker_hosts=""
Vagrant.configure(2) do |config|

  # Change to add more workers
  NodeCount = 3
  Provider = config.vm.box = ENV['VAGRANT_PROVIDER'] || ENV['VAGRANT_DEFAULT_PROVIDER'] || "libvirt" # change if needed
  config.vm.synced_folder "./", "/vagrant", type: "nfs", nfs_udp: false
  
  # global requirements
  config.vm.provision "shell", path: "requirements.sh", :args => NodeCount
  config.vm.box = "bento/ubuntu-24.04"

  # Kubernetes Master
  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "#{ip_prefix}.#{ip_start}"
    master.vm.provider Provider do |v|
      v.memory = 4096
      v.cpus = 4
    end
    master.vm.provision "shell", path: "master.sh", :args => "\"#{ip_prefix}.#{ip_start}\" #{NodeCount}"

  end

  (1..NodeCount).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: "#{ip_prefix}.#{i+1}"
      worker.vm.provider Provider do |v|
        v.memory = 4096
        v.cpus = 2
      end
      worker.vm.provision "shell", path: "worker.sh"
      worker.trigger.before :destroy do |trigger|
        trigger.warn = "Draining node..."
        trigger.run_remote = {inline: "kubectl cordon worker-#{i} || true"}
        trigger.run_remote = {inline: "kubectl drain worker-#{i} || true"}
        trigger.run_remote = {inline: "kubectl delete node worker-#{i} || true"}
      end

    end
  end
end
