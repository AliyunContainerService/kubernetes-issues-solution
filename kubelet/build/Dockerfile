FROM registry.aliyuncs.com/acs/alpine:3.3
RUN apk add --update curl && rm -rf /var/cache/apk/*
RUN apk --update add fuse curl libxml2 openssl libstdc++ libgcc && rm -rf /var/cache/apk/*

RUN mkdir -p /acs
COPY nsenter /acs/nsenter
COPY kubelet.sh /acs/kubelet.sh
COPY entrypoint.sh /acs/entrypoint.sh

RUN chmod 755 /acs/*

ENTRYPOINT ["/acs/entrypoint.sh"]
