# -*- mode: ruby -*-
# vi: set ft=ruby :

require_relative 'config.rb'
host_groups = {}
host_vars = {}
hosts = config


Vagrant.configure(2) do |config|
  Provider = config.vm.box = ENV['VAGRANT_PROVIDER'] || ENV['VAGRANT_DEFAULT_PROVIDER'] || "virtualbox" # change if needed

  # TODO: append -arm64 when on aarch64
  config.vm.box = "bento/ubuntu-24.04"

  hosts.each_with_index do |(host, host_config), i|
    groups = host_config[:groups]
    ip = host_config[:ip]
    memory = host_config[:memory] || 4096
    cpus = host_config[:cpus] || 2
    node_labels = host_config[:node_labels] || {}

    config.vm.define host do |vm|
      vm.vm.hostname = host


      vm.vm.network :private_network,
        :ip => ip,
        :virtualbox__intnet => "k8s-vagrant"


      vm.vm.provider Provider do |v|
        v.memory = memory
        v.cpus = cpus
      end

      groups.each do |group|
        unless host_groups.key?(group)
          host_groups[group] = []
        end
        host_groups[group].append(host)
        host_vars[host] = {
          "node_ip_address": ip,
          "node_labels": node_labels
        }

        # TODO: only works for one haproxy instance
        if group == "haproxy"
          # # TODO, make them configurable
          vm.vm.network "forwarded_port", guest: 80, host: 80
          vm.vm.network "forwarded_port", guest: 443, host: 443

        end

      end

      if i == hosts.size - 1
        vm.vm.provision "ansible" do |ansible|
          ansible.limit = "all"
          ansible.groups = host_groups
          ansible.host_vars = host_vars
          ansible.playbook = "ansible/main.yml"
        end
      end


      vm.trigger.after :destroy, on_error: :continue do |trigger|
        trigger.warn = "Draining node..."
        # TODO: make control-plane-1 dynamic
        trigger.run = { inline: "vagrant ssh control-plane-1 -c \"kubectl cordon #{host}; kubectl drain --ignore-daemonsets #{host}; kubectl delete node #{host}\"" }
      end
    end
  end

end
