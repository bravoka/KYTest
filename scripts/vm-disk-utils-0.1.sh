#!/bin/bash
# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Script Name: vm-disk-utils.sh
# Author: Trent Swanson - Full Scale 180 Inc github:(trentmswanson)
# Version: 0.1
# Last Modified By: Roy Arsan github:(rarsan)
# Description:
#  This script automates the partitioning and formatting of data disks
#  Data disks can be partitioned and formatted as seperate disks or in a RAID0 configuration
#  The script will scan for unpartitioned and unformatted data disks and partition, format, and add fstab entries
# Parameters :
#  1 - b: The base directory for mount points (default: /datadisks)
#  2 - s  Create a striped RAID0 Array (No redundancy)
#  3 - h  Help 
# Note : 
# This script has only been tested on Ubuntu 12.04 LTS and must be root

cat >> ~/diskutilsdebug.txt <<end
checkpoint1
uid = ${UID}
end


help()
{
    echo "Usage: $(basename $0) [-b data_base | -p data_path] [-h] [-s]"
    echo ""
    echo "Options:"
    echo "   -b         base directory for mount points of separate disks (default: /datadisks). Non-applicable with -s option"
    echo "   -p         path for mount point of RAID0 drive (default: /datadrive). Applicable with -s option"
    echo "   -s         create a striped RAID array (no redundancy)"
    echo "   -h         this help message"
}

log()
{
    # Un-comment the following if you would like to enable logging to a service
    #curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/<key>/tag/es-extension,${HOSTNAME}
    echo "$1"
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint2
end

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi


#A set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

# Base path for data disk mount points
DATA_BASE="/datadisks"
# Full path for data drive in case of RAID configuration
DATA_PATH="/datadrive"

cat >> ~/diskutilsdebug.txt <<end
checkpoint3
blacklist = ${BLACKLIST}
end


while getopts b:p:sh optname; do
    log "Option $optname set with value ${OPTARG}"
  case ${optname} in
    b)  #set base path for data disks mount points
      DATA_BASE=${OPTARG}
      ;;
    p)  #set path for data drive single point point
      DATA_PATH=${OPTARG}
      ;;
    s) #Partition and format data disks as raid set
      RAID_CONFIGURATION=1
      ;;
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

cat >> ~/diskutilsdebug.txt <<end
checkpoint4
raidconfiguration = ${RAID_CONFIGURATION}
end

get_next_md_device() {
    shopt -s extglob
    LAST_DEVICE=$(ls -1 /dev/md+([0-9]) 2>/dev/null|sort -n|tail -n1)
	
	cat >> ~/diskutilsdebug.txt <<end
checkpoing function1
last device = ${LAST_DEVICE}
end
	
    if [ -z "${LAST_DEVICE}" ]; then
        NEXT=/dev/md0
    else
        NUMBER=$((${LAST_DEVICE/\/dev\/md/}))
        NEXT=/dev/md${NUMBER}
    fi
    echo ${NEXT}
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint5
end

is_partitioned() {
    OUTPUT=$(partx -s ${1} 2>&1)
	cat >> ~/diskutilsdebug.txt <<end
checkpoint function2
out put = ${OUTPUT}
end

    egrep "partition table does not contains usable partitions|failed to read partition table" <<< "${OUTPUT}" >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
        return 1
    else
        return 0
    fi    
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint6
end

has_filesystem() {
    DEVICE=${1}

cat >> ~/diskutilsdebug.txt <<end
checkpoint functino3
Device = ${DEVICE}
end

	
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # The disk will be considered a candidate for partitioning
        # and formatting if it does not have a sd?1 entry or
        # if it does have an sd?1 entry and does not contain a filesystem
        is_partitioned "${DEV}"
        if [ ${?} -eq 0 ];
        then
            has_filesystem "${DEV}1"
            if [ ${?} -ne 0 ];
            then
                RET+=" ${DEV}"
            fi
        else
            RET+=" ${DEV}"
        fi
    done
    echo "${RET}"
}

get_next_mountpoint() {
    DIRS=$(ls -1d ${DATA_BASE}/disk* 2>/dev/null| sort --version-sort)
    MAX=$(echo "${DIRS}"|tail -n 1 | tr -d "[a-zA-Z/]")
    if [ -z "${MAX}" ];
    then
        echo "${DATA_BASE}/disk1"
        return
    fi
    IDX=1
    while [ "${IDX}" -lt "${MAX}" ];
    do
        NEXT_DIR="${DATA_BASE}/disk${IDX}"
        if [ ! -d "${NEXT_DIR}" ];
        then
            echo "${NEXT_DIR}"
            return
        fi
        IDX=$(( ${IDX} + 1 ))
    done
    IDX=$(( ${MAX} + 1))
    echo "${DATA_BASE}/disk${IDX}"
}

add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
	
	cat >> ~/diskutilsdebug.txt <<end
checkpoint function4
Mountpoint = ${MOUNTPOINT}
end
	
	
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=\"${UUID}\"\t${MOUNTPOINT}\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    _disk=${1}
    _type=${2}
	
cat >> ~/diskutilsdebug.txt <<end
checkpoint function5
type = ${_type}
end

    if [ -z "${_type}" ]; then
        # default to Linux partition type (ie, ext3/ext4/xfs)
        _type=83
    fi
    echo "n
p
1
t
${_type}
w"| fdisk "${_disk}"

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${_disk}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}
#end do_partition

cat >> ~/diskutilsdebug.txt <<end
checkpoint7
end

scan_partition_format()
{
    log "Begin scanning and formatting data disks"

    DISKS=($(scan_for_new_disks))

    if [ "${#DISKS}" -eq 0 ];
    then
        log "No unpartitioned disks without filesystems detected"
        return
    fi
    echo "Disks are ${DISKS[@]}"
    for DISK in "${DISKS[@]}";
    do
        echo "Working on ${DISK}"
        is_partitioned ${DISK}
        if [ ${?} -ne 0 ];
        then
            echo "${DISK} is not partitioned, partitioning"
            do_partition ${DISK}
        fi
        PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')

cat >> ~/diskutilsdebug.txt <<end
checkpoint function 6
partition = ${PARTITION}
end

        has_filesystem ${PARTITION}
        if [ ${?} -ne 0 ];
        then
            echo "Creating filesystem on ${PARTITION}."
    #        echo "Press Ctrl-C if you don't want to destroy all data on ${PARTITION}"
    #        sleep 10
            mkfs -j -t ext4 ${PARTITION}
        fi
        MOUNTPOINT=$(get_next_mountpoint)
        echo "Next mount point appears to be ${MOUNTPOINT}"
        [ -d "${MOUNTPOINT}" ] || mkdir -p "${MOUNTPOINT}"
        read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
        add_to_fstab "${UUID}" "${MOUNTPOINT}"
        echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
        mount "${MOUNTPOINT}"
    done
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint8
end

create_striped_volume()
{
    DISKS=(${@})

    if [ "${#DISKS[@]}" -eq 0 ];
    then
        log "No unpartitioned disks without filesystems detected"
        return
    fi

    echo "Disks are ${DISKS[@]}"

    declare -a PARTITIONS

    for DISK in "${DISKS[@]}";
    do
        echo "Working on ${DISK}"
        is_partitioned ${DISK}
        if [ ${?} -ne 0 ];
        then
            echo "${DISK} is not partitioned, partitioning"
            do_partition ${DISK} fd
        fi

        PARTITION=$(fdisk -l ${DISK}|grep -A 2 Device|tail -n 1|awk '{print $1}')
        PARTITIONS+=("${PARTITION}")
    done

    MDDEVICE=$(get_next_md_device)

    udevadm control --stop-exec-queue
    mdadm --create ${MDDEVICE} --level 0 --raid-devices ${#PARTITIONS[@]} ${PARTITIONS[*]}
    udevadm control --start-exec-queue

    MOUNTPOINT="${DATA_PATH}"
    echo "Mount point appears to be ${MOUNTPOINT}"
    [ -d "${MOUNTPOINT}" ] || mkdir -p "${MOUNTPOINT}"

    #Make a file system on the new device
    STRIDE=128 #(512kB stripe size) / (4kB block size)
    PARTITIONSNUM=${#PARTITIONS[@]}
    STRIPEWIDTH=$((${STRIDE} * ${PARTITIONSNUM}))

    mkfs -t ext4 -b 4096 -E lazy_itable_init=1,stride=${STRIDE},stripe-width=${STRIPEWIDTH} "${MDDEVICE}"

    read UUID FS_TYPE < <(blkid -u filesystem ${MDDEVICE}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")

    add_to_fstab "${UUID}" "${MOUNTPOINT}"

    mount "${MOUNTPOINT}"
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint9
end

check_mdadm() {
    dpkg -s mdadm >/dev/null 2>&1
    if [ ${?} -ne 0 ]; then
        apt-get -y update
        DEBIAN_FRONTEND=noninteractive apt-get -y install mdadm --fix-missing
    fi
}

cat >> ~/diskutilsdebug.txt <<end
checkpoint10
end

# Create Partitions
DISKS=$(scan_for_new_disks)
cat >> ~/diskutilsdebug.txt <<end
checkpoint create...partitions
disks = ${DISKS[@]}
end

if [ "$RAID_CONFIGURATION" -eq 1 ]; then
    check_mdadm
    create_striped_volume "${DISKS[@]}"
else
    scan_partition_format
fi