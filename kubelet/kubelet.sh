#!/bin/sh

date_echo() {
    echo `date "+%H:%M:%S-%Y-%m-%d"` $1
}

date_echo "Starting to fix the possible issue..."
## umount subpath if mntpoint is corrupted
## both OSS, NAS may meet this issue;
fix_Subpath_ErrorReading(){
    lineStr=$1
    tmpStr=`echo $lineStr | awk -F"lstat" '{print $2}'`
    if [ "$tmpStr" != "" ]; then
        mntPoint=`echo $tmpStr | awk -F":" '{print $1}'`
        mntPoint=`echo $mntPoint | xargs`
        if [ "$mntPoint" != "" ]; then
            num=`mount | grep $mntPoint | wc -l`
            if [ "$num" != "0" ]; then
                umount $mntPoint
                date_echo "Fix subpath Error Reading Issue:: Umount $mntPoint ...."
                idleTimes=0
            fi
        fi
    fi
}

## OSS issue, when remove the subpath;
## umount subpath if mntpoint is corrupted
## Reproduce:
# 1. use subpath create pod;
# 2. login host of pod, remove subpath with root mountpoint;
# 3. kubectl delete pod **
# 4. check /var/log/message
fix_Oss_Subpath_NotEmpty(){
    lineStr=$1
    tmpStr=`echo $lineStr | awk -F"error deleting " '{print $2}'`
    if [ "$tmpStr" != "" ]; then
        mntPoint=`echo $tmpStr | awk -F": remove" '{print $1}'`
        mntPoint=`echo $mntPoint | xargs`
        if [ "$mntPoint" != "" ]; then
            num=`mount | grep $mntPoint | wc -l`
            if [ "$num" != "0" ]; then
                mntPoint=`mount | grep $mntPoint | awk '{print $3}'`
                umount $mntPoint
                date_echo "Fix Subpath Not empty Issue:: Umount $mntPoint ...."
                idleTimes=0
            fi
        fi
    fi
}

# fix orphaned pod, umount the mntpoint;
fix_orphanedPod(){
    secondPart=`echo $item | awk -F"Orphaned pod" '{print $2}'`
    podid=`echo $secondPart | awk -F"\"" '{print $2}'`

    # not process if the volume directory is not exist.
    if [ ! -d /var/lib/kubelet/pods/$podid/volumes/ ]; then
        continue
    fi
    # umount subpath if exist
    if [ -d /var/lib/kubelet/pods/$podid/volume-subpaths/ ]; then
        mountpath=`mount | grep /var/lib/kubelet/pods/$podid/volume-subpaths/ | awk '{print $3}'`
        for mntPath in $mountpath;
        do
             date_echo "Fix subpath Issue:: umount subpath $mntPath"
             umount $mntPath
             idleTimes=0
        done
    fi

    volumeTypes=`ls /var/lib/kubelet/pods/$podid/volumes/`
    for volumeType in $volumeTypes;
    do
         subVolumes=`ls -A /var/lib/kubelet/pods/$podid/volumes/$volumeType`
         if [ "$subVolumes" != "" ]; then
             date_echo "/var/lib/kubelet/pods/$podid/volumes/$volumeType contents volume: $subVolumes"
             for subVolume in $subVolumes;
             do
                 if [ "$volumeType" == "kubernetes.io~csi" ]; then
                     # check subvolume path is mounted or not
                     findmnt /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount
                     if [ "$?" != "0" ]; then
                         date_echo "/var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount is not mounted, just need to remove"
                         content=`ls -A /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount`
                         # if path is empty, just remove the directory.
                         if [ "$content" = "" ]; then
                             rmdir /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount
                             rm -f /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/vol_data.json
                             rmdir /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                         # if path is not empty, do nothing.
                         else
                             date_echo "/var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount is not mounted, but not empty"
                             idleTimes=0
                         fi
                     # is mounted, umounted it first.
                     else
                         date_echo "Fix Orphaned Issue:: /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount is mounted, umount it"
                         umount /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume/mount
                     fi
                 else
                     # check subvolume path is mounted or not
                     findmnt /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                     if [ "$?" != "0" ]; then
                         date_echo "/var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume is not mounted, just need to remove"
                         content=`ls -A /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume`
                         # if path is empty, just remove the directory.
                         if [ "$content" = "" ]; then
                             rmdir /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                         # if path is not empty, do nothing.
                         else
                             date_echo "/var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume is not mounted, but not empty"
                             idleTimes=0
                         fi
                     # is mounted, umounted it first.
                     else
                         date_echo "Fix Orphaned Issue:: /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume is mounted, umount it"
                         umount /var/lib/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                     fi
                 fi
             done
         fi
    done
}


idleTimes=0
IFS=$'\r\n'
while :
do
    for item in `tail /var/log/messages`;
    do
        ## orphaned pod process
        if [[ $item == *"Orphaned pod"* ]] && [[ $item == *"but volume paths are still present on disk"* ]]; then
            fix_orphanedPod $item
        ## subpath cannot umount error proccess
        elif [[ $item == *"error cleaning subPath mounts for volume"* ]] && [[ $item == *"error reading"* ]]; then
        	fix_Subpath_ErrorReading $item
        ## oss subpath removed issue.
        elif [[ $item == *"error cleaning subPath mounts for volume"* ]] && [[ $item == *"error deleting"* ]] && [[ $item == *"directory not empty"* ]]; then
        	fix_Oss_Subpath_NotEmpty $item
        fi
    done

    idleTimes=`expr $idleTimes + 1`
    if [ "$idleTimes" = "10" ] && [ "$LONGRUNNING" != "True" ]; then
        break
    fi
    sleep 5
done

date_echo "Finish Process......"
