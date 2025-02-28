# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  Provider = config.vm.box = ENV['VAGRANT_PROVIDER'] || ENV['VAGRANT_DEFAULT_PROVIDER'] || "virtualbox" # change if needed

  if Provider == 'libvirt'
    config.vm.synced_folder "./", "/vagrant", type: "nfs", nfs_udp: false
  end

  config.vm.box = "bento/ubuntu-24.04"

  host_groups = {}
  host_vars = {}
  hosts = {
    "control-plane-1": {
      "ip": "10.1.1.11",
      "groups": ["control_plane"],
    },
    # "control-plane-2": {
    #   "ip": "10.1.1.12",
    #   "groups": ["control_plane"],
    # },
    "worker-1": {
      "ip": "10.1.1.21",
      "node_labels": {
        "size": "small"
      },
      "groups": ["worker"],
    },
    # "worker-2": {
    #   "ip": "10.1.1.22",
    #   "groups": ["worker"],
    #   "node_labels": {
    #     "size": "large"
    #   },
    #   "memory": 5000,
    #   "cpus": 2
    # },
  }

  hosts.each_with_index do |(host, host_config), i|
    groups = host_config[:groups]
    ip = host_config[:ip]
    memory = host_config[:memory] || 4096
    cpus = host_config[:cpus] || 2
    node_labels = host_config[:node_labels] || {}

    config.vm.define host do |vm|
      vm.vm.hostname = host


      if Provider == "virtualbox"
        vm.vm.network "private_network", ip: ip, virtualbox__intnet: "k8s-vagrant"
      else
        vm.vm.network "private_network", ip: ip
      end

      vm.vm.provider Provider do |v|
        v.memory = memory
        v.cpus = cpus
      end

      groups.each do |group|
        if not host_groups.key?(group)
          host_groups[group] = []
        end
        host_groups[group].append(host)
        host_vars[host] = {
          "node_ip_address": ip,
          "node_labels": node_labels
        }
      end

      if i == hosts.size - 1
        vm.vm.provision "ansible" do |ansible|
          ansible.limit = "all"
          ansible.groups = host_groups
          ansible.host_vars = host_vars
          ansible.playbook = "ansible/main.yml"
        end
      end

      if i == 0
        vm.trigger.before :destroy, on_error: :continue do |trigger|
          trigger.warn = "Draining node..."
          # TODO: get first master vm name and replace control-plane-1
          trigger.run = { inline: "vagrant ssh control-plane-1 -c \"kubectl cordon worker-#{i} || true\"" }
          trigger.run = { inline: "vagrant ssh control-plane-1 -c \"kubectl drain worker-#{i} || true\"" }
          trigger.run = { inline: "vagrant ssh control-plane-1 -c \"kubectl delete node worker-#{i} || true\"" }
        end
      end

    end

  end

end
