Sometime, kubelet issue happens and cannot be self healing, and we have to resolve the issue by hands. This scripts may be helpful for you to auto resolve the issues.

Kubelet Logs is from /var/log/messages

## Issue List
### 1. Orphaned issue

[Orphaned-Pod](./orphaned.md)

    Like Below Logs:
    *   21207 kubelet_volumes.go:140] Orphaned pod "06fa705f-0821-11e9-8cd4-00163e1071ed" found,
    but volume paths are still present on disk : There were a total of 2 errors similar to this. Turn up verbosity to see them.

### 2. Subpath umount issue

[Subpath-Error-Reading](./subpath-error-reading.md)

    nas/oss mountpoint is umounted when pod running, pod cannot be delete normally.

    Like Below Logs:
    Operation for "\"flexvolume-alicloud/nas/pv-nas-v4\" (*)" failed.* Error: "error cleaning subPath mounts for volume \"pvc-nas\" (*)
    error reading /var/lib/kubelet/pods/*/volume-subpaths/pv-nas-v4/nginx:
    lstat /var/lib/kubelet/pods/*/volume-subpaths/pv-nas-v4/nginx/0: stale NFS file handle"

    or OSS:
    * Operation for "\"flexvolume-alicloud/oss/oss1\"*failed. *Error: "error cleaning subPath mounts for volume \"oss1\" *:
    error reading /var/lib/kubelet/pods/*/volume-subpaths/oss1/nginx-flexvolume-oss:
    lstat /var/lib/kubelet/pods/*/volume-subpaths/oss1/nginx-flexvolume-oss/0: transport endpoint is not connected"


### 3. Oss Subpath umount issue

[Subpath-Oss-Error-Delete](./subpath-oss-error-delete.md)

    oss using subpath, and the subpath is removed when pod running.

    Like Below Logs:
    * Operation for "\"flexvolume-alicloud/oss/oss1\"* failed.* Error: "error cleaning subPath mounts for volume \"oss1\" *
    error deleting /var/lib/kubelet/pods/*/volume-subpaths/oss1/nginx-flexvolume-oss:
	remove /var/lib/kubelet/pods/*/volume-subpaths/oss1/nginx-flexvolume-oss: directory not empty"

## How to Use

Different issue may have different resolution，refer to the issue Readme.

