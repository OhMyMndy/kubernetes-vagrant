# Kubernetes CKA, CKAD and CKS playground

This is an up-to-date configuration for practicing the performance based Kubernetes exams.

The setup contains multiple Vagrant virtual machines (Virtualbox and libvirt are tested) which are part of the Kubernetes cluster.


## Components:
- Kubernetes 1.32.5, set up with Kubeadm through Ansible playbook
- Cilium as CNI and for networking policies and Kube Proxy replacement



## Getting started:

Copy `config-example.rb` to `config.rb`
Run `vagrant up`