#!/bin/bash
# Mike's Proxmox provision script v1.1

### Don't touch these
############################

FILE=$1
UNIXTIME=`date +%s`
VMNAME=$2
diskcount=0

### Modify these variables to suit
############################

STORAGE="local-lvm"
HOST="proxm1"
USER="root"
VLAN_TAG=205



###
### Script start
############################

if [[ ! $1 ]]; then echo -e "ERROR: No -kvm.zip filename specified. Example usage: $0 FGT_VM64_KVM-v7.4.3.F.out.kvm.zip <VM name (no spaces)>\n\n" && exit; fi 
if [[ ! $2 ]]; then echo -e "ERROR: No -kvm.zip filename specified. Exanple usage: $0 FGT_VM64_KVM-v7.4.3.F.out.kvm.zip <VM name (no spaces)>\n\n" && exit; fi 


NEXT_ID=`ssh $HOST pvesh get /cluster/nextid`
echo "--- Transferring firmware to proxmox..."
scp -q $1 $USER@$HOST:/tmp/$1

echo "--- Unzipping firmware..."
ssh $HOST "cd /tmp && mkdir _tmp_$UNIXTIME && unzip -qq /tmp/$1 -d /tmp/_tmp_$UNIXTIME"

# Create VM
echo "--- Creating $VMNAME ($NEXT_ID) with 4C/8GB..."
ssh $HOST "echo $VMNAME >/tmp/vmname"
ssh $HOST qm create $NEXT_ID --memory 8192 --balloon 4096 --cores 4 --name '`cat /tmp/vmname`'  --net0 model=virtio,bridge=vmbr0,tag=$VLAN_TAG --ostype l26 --autostart 0

# Create file list, import & link disk to VM
unzip -l $1 | grep qcow | awk '{print $4}' | while read line; do {
	
	echo "--- Importing disk image $line.."
	ssh $HOST "qm disk import $NEXT_ID /tmp/_tmp_$UNIXTIME/$line $STORAGE"
	ssh $HOST "qm set $NEXT_ID -scsi$diskcount file=$STORAGE:vm-$NEXT_ID-disk-$diskcount >/dev/null"
	((diskcount++))
}; done

# Correct boot order
ssh $HOST "qm set $NEXT_ID -boot order=scsi0 >/dev/null"


# Cleanup
ssh $HOST rm /tmp/$1
ssh $HOST rm /tmp/vmname
ssh $HOST rm -fr /tmp/_tmp_$UNIXTIME
