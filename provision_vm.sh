#!/bin/bash
# Mike's Proxmox provision script v1.1

### Don't touch these
############################

FILEPATH=$1
FILENAME=`basename $1`
UNIXTIME=`date +%s`
VMNAME=$2
DISKCOUNT=0

### Modify these variables to suit
############################

STORAGE="storage"
HOST="proxmox"
USER="username"
VLAN_TAG=6000



###
### Script start
############################

if [[ ! $1 ]]; then echo -e "ERROR: No filename specified. Example: $0 filename.kvm.zip <VM name (no spaces)>\n\n" && exit; fi 
if [[ ! $2 ]]; then echo -e "\nERROR: Specify VM name. Example: $0 filename.zip <VM name (no spaces)>\n" && exit; fi 
if [ `echo $2 | grep '[-_ ]'` ]; then echo -e "\nERROR: Only alphanumeric chars permitted in VM name\n" && exit; fi 

NEXT_ID=`ssh $HOST pvesh get /cluster/nextid`
echo "--- Transferring firmware to proxmox..."
scp $1 $USER@$HOST:/tmp/

echo "--- Unzipping firmware..."
ssh $HOST "cd /tmp && mkdir _tmp_$UNIXTIME && unzip -qq /tmp/$FILENAME -d /tmp/_tmp_$UNIXTIME"

# Create VM
echo "--- Creating $VMNAME ($NEXT_ID) with 4C/8GB..."
ssh $HOST "echo $VMNAME >/tmp/vmname"
ssh $HOST "qm create $NEXT_ID --memory 8192 --balloon 4096 --cores 4 --scsihw=virtio-scsi-pci --pool 'Provisioned_VMs' --name '$VMNAME'  --net0 model=virtio,bridge=vmbr0,tag=$VLAN_TAG --ostype l26 --autostart 0"

# Create file list, import & link disk to VM
items=`unzip -l $1 | grep qcow | awk '{print $4}' | sort`
for item in $items; do {
	
	echo "--- Importing disk image $item.."
	ssh $HOST "qm disk import $NEXT_ID /tmp/_tmp_$UNIXTIME/$item $STORAGE >/dev/null" >/dev/null
	ssh $HOST "qm set $NEXT_ID -scsi$DISKCOUNT file=$STORAGE:vm-$NEXT_ID-disk-$DISKCOUNT" >/dev/null
	DISKCOUNT=$((DISKCOUNT+1))
}; done

# Correct boot order
ssh $HOST "qm set $NEXT_ID -boot order=scsi0 >/dev/null"


# Cleanup
ssh $HOST rm /tmp/$FILENAME
ssh $HOST rm /tmp/vmname
ssh $HOST rm -fr /tmp/_tmp_$UNIXTIME
