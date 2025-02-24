#!/usr/bin/env bash

rm -rf kubeconfigs
rm -f joincluster.sh
rm -f .init*

vagrant up --provision
