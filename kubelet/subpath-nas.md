
## Issue Description:

If one volume use subpath as the mountPath option, the umount action could get failed sometimes.

```
Feb 20 14:45:34 iZwz99gunotzijxig3j052Z kubelet: E0220 14:45:34.717930    4175 nestedpendingoperations.go:267] 
Operation for "\"flexvolume-alicloud/nas/pv-nas-v4\" (\"cb7ceb74-34d8-11e9-b51c-00163e0cd246\")" failed.
No retries permitted until 2019-02-20 14:47:36.717900777 +0800 CST m=+6057600.314812412 (durationBeforeRetry 2m2s). 
Error: "error cleaning subPath mounts for volume \"pvc-nas\" (UniqueName: \"flexvolume-alicloud/nas/pv-nas-v4\") pod
\"cb7ceb74-34d8-11e9-b51c-00163e0cd246\" (UID: \"cb7ceb74-34d8-11e9-b51c-00163e0cd246\") :
error reading /var/lib/kubelet/pods/cb7ceb74-34d8-11e9-b51c-00163e0cd246/volume-subpaths/pv-nas-v4/nginx:
lstat /var/lib/kubelet/pods/cb7ceb74-34d8-11e9-b51c-00163e0cd246/volume-subpaths/pv-nas-v4/nginx/0: stale NFS file handle"
```

## Reason

If remove the subpath when pod is running, the mountpoint is useless. I code get error when clean the mountpoint.

```
		## related code in pkg/util/mount/mount_linux.go
		subPaths, err := ioutil.ReadDir(fullContainerDirPath)
		if err != nil {
			return fmt.Errorf("error reading %s: %s", fullContainerDirPath, err)
		}
```

This issue is fixed in 1.11.7 and 1.12 version.

PR Details: [https://github.com/kubernetes/kubernetes/pull/71804](https://github.com/kubernetes/kubernetes/pull/71804)

## How to Reproduce

NFS example:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nas
  labels:
    alicloud-pvname: pv-nas
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  flexVolume:
    driver: "alicloud/nas"
    options:
      server: "**-**.cn-shenzhen.nas.aliyuncs.com"
      path: "/"
      vers: "4.0"
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-nas
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      alicloud-pvname: pv-nas
---  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nas-static
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
          - name: pvc-nas
            mountPath: "/data"
            subPath: "hello"
      volumes:
        - name: pvc-nas
          persistentVolumeClaim:
            claimName: pvc-nas
```

### 1. Create pv, pvc, pod

	# kubectl create -f nas.yaml

	# kubectl get pod | grep nas
	nas-static-fdc9c8d65-bn4z7       1/1       Running   0          24s
	
	# kubectl get pvc | grep pvc-nas
	pvc-nas          Bound     pv-nas                   5Gi        RWX                                  58s
	
	# kubectl get pvc | grep pv-nas
	pvc-nas          Bound     pv-nas                   5Gi        RWX                                  1m

### 2. Login the node which Pod locate

	# kubectl describe pod nas-static-fdc9c8d65-bn4z7 | grep Node
	Node:               cn-shenzhen.i-wz99gunotzijxig3j052/192.168.0.1
	
	# ssh 192.168.0.1


### 3. Reproduce

On the Pod located node:

	# mount | grep nfs | grep -v container
	**-**.cn-shenzhen.nas.aliyuncs.com:/ on /var/lib/kubelet/pods/009381d9-3504-11e9-b51c-00163e0cd246/volumes/alicloud~nas/pv-nas type nfs4 (rw,relatime,vers=4.0,rsize=1048576,wsize=1048576,namlen=255,hard,noresvport,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.1,local_lock=none,addr=192.168.0.1)
	**-**.cn-shenzhen.nas.aliyuncs.com:/hello on /var/lib/kubelet/pods/009381d9-3504-11e9-b51c-00163e0cd246/volume-subpaths/pv-nas/nginx/0 type nfs4 (rw,relatime,vers=4.0,rsize=1048576,wsize=1048576,namlen=255,hard,noresvport,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.1,local_lock=none,addr=192.168.0.1)
	
	## remove the subpath when pod is running;
	# rm -rf /var/lib/kubelet/pods/009381d9-3504-11e9-b51c-00163e0cd246/volumes/alicloud~nas/pv-nas/hello

	## Delete running pod, the pod is hang in deleting;
	# kubectl delete pod nas-static-fdc9c8d65-bn4z7
	pod "nas-static-fdc9c8d65-bn4z7" deleted

	## check logs on pod locate node
	# tailf /var/log/messages | grep "stale NFS file handle"
	Feb 20 19:46:15 iZwz99gunotzijxig3j052Z kubelet: E0220 19:46:15.539730    4175 nestedpendingoperations.go:267] Operation for "\"flexvolume-alicloud/nas/pv-nas\" (\"009381d9-3504-11e9-b51c-00163e0cd246\")" failed. 
	No retries permitted until 2019-02-20 19:46:23.53968005 +0800 CST m=+6075527.136591731 (durationBeforeRetry 8s). 
	Error: "error cleaning subPath mounts for volume \"pvc-nas\" (UniqueName: \"flexvolume-alicloud/nas/pv-nas\") pod \"009381d9-3504-11e9-b51c-00163e0cd246\" (UID: \"009381d9-3504-11e9-b51c-00163e0cd246\") : 
	error reading /var/lib/kubelet/pods/009381d9-3504-11e9-b51c-00163e0cd246/volume-subpaths/pv-nas/nginx: 
	lstat /var/lib/kubelet/pods/009381d9-3504-11e9-b51c-00163e0cd246/volume-subpaths/pv-nas/nginx/0: stale NFS file handle"


## How to Fix

Run the script on error node:

	# sh kubelet.sh

Deploy daemonset to running script and monitor the issue all the time

    # kubectl create -f deploy/deploy.yaml

