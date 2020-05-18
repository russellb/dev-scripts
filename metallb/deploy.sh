#!/bin/bash

# References:
#   https://metallb.universe.tf/installation/
#   https://metallb.universe.tf/installation/clouds/#metallb-on-openshift-ocp
#   https://www.underkube.com/posts/metallb-on-ocp4-baremetal/

oc apply -f namespace.yaml
oc adm policy add-scc-to-user privileged -n metallb-system -z speaker
oc apply -f metallb.yaml
oc create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
oc apply -f config.yaml

oc new-project my-test-app
oc new-app openshift/hello-openshift
oc apply -f lb.yaml
