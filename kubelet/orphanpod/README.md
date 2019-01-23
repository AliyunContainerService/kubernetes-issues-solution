

## Introduction
pod with volume sometimes attchs failed when pod starting, and logs show like:

```
Jan 21 03:07:10 abc_k8s_worker01 kubelet: E0121 03:07:10.910614    6507 kubelet_volumes.go:140] Orphaned pod "0401c09a-1b0c-11e9-94f8-00163e14dc48" found, but volume paths are still present on disk : There were a total of 4 errors similar to this. Turn up verbosity to see them.
```

This means kubelet cannot clean the pod data when pod terminating, and need clean pod by hands.

[https://github.com/kubernetes/kubernetes/issues/60987](https://github.com/kubernetes/kubernetes/issues/60987)


## Action

Download Script file and run it on the issue Node.

```
sh process_orphanpod.sh
```
