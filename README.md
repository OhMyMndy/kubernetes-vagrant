# Kubernetes CKA, CKAD and CKS playground

This is an up-to-date configuration for practicing the performance based Kubernetes exams.

The setup contains multiple Vagrant virtual machines (Virtualbox and libvirt are tested) which are part of the Kubernetes cluster.


## Components:
- Kubernetes 1.32.4, set up with Kubeadm through Ansible playbook
- Cilium as CNI and for networking policies and Kubeproxy replacement


## Features

- Setup and configuration through Ansible
- Automatic upgrading of Kubernetes version when changing Kubernetes version in Ansible config
- Adding new nodes with `vagrant up --provision` after adding node in `config.rb`


## Getting started:

Copy `config-example.rb` to `config.rb`

Run `vagrant up --provision`


# Applications

### N8n

https://n8n.192.168.56.190.sslip.io/

username: `admin`

password `Password123!`

### Gitea

https://gitea.192.168.56.190.sslip.io/

username: `gitea_admin`

password `r8sA8CPHD9!bt6d`

## To do

- Graceful upgrades of Kubernetes nodes (cordon and drain before upgrading)
