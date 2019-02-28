#!/bin/sh

cd ${GOPATH}/src/github.com/AliyunContainerService/kubernetes-issues-solution/kubelet/build
GIT_SHA=`git rev-parse --short HEAD || echo "HEAD"`

rm -rf ./kubelet.sh
cp ../kubelet.sh ./

version="v1.12"
version=$version-$GIT_SHA-aliyun

docker build -t=registry.cn-hangzhou.aliyuncs.com/plugins/acs-cluster-recover:$version .
docker push registry.cn-hangzhou.aliyuncs.com/plugins/acs-cluster-recover:$version
