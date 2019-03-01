
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

Or using oss:

```
Mar  1 10:29:19 iZ2ze1fa4tkhgqper1l406Z kubelet: E0301 10:29:19.869173    8651 nestedpendingoperations.go:267] Operation for "\"flexvolume-alicloud/oss/oss1\"
(\"aa401a77-3bc9-11e9-b1a1-00163e03e854\")" failed. No retries permitted until 2019-03-01 10:29:51.869139106 +0800 CST m=+222096.349178930 (durationBeforeRetry 32s).
Error: "error cleaning subPath mounts for volume \"oss1\" (UniqueName: \"flexvolume-alicloud/oss/oss1\") pod \"aa401a77-3bc9-11e9-b1a1-00163e03e854\"
(UID: \"aa401a77-3bc9-11e9-b1a1-00163e03e854\") : error reading /var/lib/kubelet/pods/aa401a77-3bc9-11e9-b1a1-00163e03e854/volume-subpaths/oss1/nginx-flexvolume-oss:
lstat /var/lib/kubelet/pods/aa401a77-3bc9-11e9-b1a1-00163e03e854/volume-subpaths/oss1/nginx-flexvolume-oss/0: transport endpoint is not connected"
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

This issue is fixed in 1.11.7 and 1.12 version, but just for nas;

PR Details: [https://github.com/kubernetes/kubernetes/pull/71804](https://github.com/kubernetes/kubernetes/pull/71804)

## How to Reproduce - Nas

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


## How to Reproduce - Oss

NFS example:

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-oss-deploy
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx-flexvolume-oss
        image: nginx
        volumeMounts:
          - name: "oss1"
            mountPath: "/data"
            subPath: hello
      volumes:
        - name: "oss1"
          flexVolume:
            driver: "alicloud/oss"
            options:
              bucket: "aliyun-docker"
              url: "oss-cn-hangzhou.aliyuncs.com"
              otherOpts: "-o max_stat_cache_size=0 -o allow_other"
              akId: "**"
              akSecret: "**"
```

### 1. Create pod

	# kubectl create -f osss.yaml

	# kubectl get pod
    NAME                                READY     STATUS    RESTARTS   AGE
    nginx-oss-deploy-6bfd859cc4-7sb75   1/1       Running   0          19m

### 2. Login the node which Pod locate

	# kubectl describe pod nginx-oss-deploy-6bfd859cc4-7sb75 | grep Node
	Node:               cn-beijing.i-2ze1fa4tkhgqperal406/172.16.1.1

	# ssh 172.16.1.1


### 3. Reproduce

On the Pod located node:

	# mount | grep oss
    ossfs on /var/lib/kubelet/pods/44f0528b-3b06-11e9-b1a1-00163e03e854/volumes/alicloud~oss/oss1 type fuse.ossfs (rw,nosuid,nodev,relatime,user_id=0,group_id=0,allow_other)
    ossfs on /var/lib/kubelet/pods/44f0528b-3b06-11e9-b1a1-00163e03e854/volume-subpaths/oss1/nginx-flexvolume-oss/0 type fuse.ossfs (rw,relatime,user_id=0,group_id=0,allow_other)

	## kill the ossfs when pod is running;
	# ps -ef | grep ossfs
	# kill **

	## Delete running pod, the pod is hang in deleting;
	# kubectl delete pod nginx-oss-deploy-6bfd859cc4-7sb75
	pod "nginx-oss-deploy-6bfd859cc4-7sb75" deleted

	## check logs on pod locate node
	# tailf /var/log/messages | grep "transport endpoint is not connected"
    Mar  1 10:29:19 iZ2ze1fa4tkhgqper1l406Z kubelet: E0301 10:29:19.869173    8651 nestedpendingoperations.go:267] Operation for "\"flexvolume-alicloud/oss/oss1\"
    (\"aa401a77-3bc9-11e9-b1a1-00163e03e854\")" failed. No retries permitted until 2019-03-01 10:29:51.869139106 +0800 CST m=+222096.349178930 (durationBeforeRetry 32s).
    Error: "error cleaning subPath mounts for volume \"oss1\" (UniqueName: \"flexvolume-alicloud/oss/oss1\") pod \"aa401a77-3bc9-11e9-b1a1-00163e03e854\"
    (UID: \"aa401a77-3bc9-11e9-b1a1-00163e03e854\") : error reading /var/lib/kubelet/pods/aa401a77-3bc9-11e9-b1a1-00163e03e854/volume-subpaths/oss1/nginx-flexvolume-oss:
    lstat /var/lib/kubelet/pods/aa401a77-3bc9-11e9-b1a1-00163e03e854/volume-subpaths/oss1/nginx-flexvolume-oss/0: transport endpoint is not connected"


## How to Fix

Run the script on error node:

	# sh kubelet.sh

Deploy daemonset to running script and monitor the issue all the time

    # kubectl create -f deploy/deploy.yaml

