#!/bin/sh

rm -rf /host/etc/kubernetes/acs-kubelet-recover/kubelet.sh
cp /acs/kubelet.sh /host/etc/kubernetes/acs-kubelet-recover/kubelet.sh

/acs/nsenter --mount=/proc/1/ns/mnt sh /etc/kubernetes/acs-kubelet-recover/kubelet.sh
