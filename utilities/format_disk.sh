#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2016

# ARGV:
# 1 - Name of disk (ie sda) - required
# 2 - Mountpoint number (ie 2 for /data/2) - required

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}.%{RELEASE}\n')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

DISK=$1
NUM=$2

if [ -z "$DISK" ]; then
  echo "ERROR: Missing disk argument (ie sdb)."
  exit 1
fi
if [ -z "$NUM" ]; then
  echo "ERROR: Missing mountpoint argument (ie 1)."
  exit 1
fi
if [ ! -b "/dev/${DISK}" ]; then
  echo "ERROR: Disk device /dev/${DISK} does not exist."
  exit 2
fi

SIZE=$(lsblk --all --bytes --list --output NAME,SIZE,TYPE "/dev/${DISK}" | awk '/disk$/{print $2}')
if [ "$SIZE" -ge 2199023255552 ]; then
  LABEL=gpt
else
  LABEL=msdos
fi

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  FS=xfs
  if ! rpm -q parted; then echo "Installing parted. Please wait...";yum -y -d1 -e1 install parted; fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  FS=ext4
  export DEBIAN_FRONTEND=noninteractive
  if ! dpkg -l parted >/dev/null; then echo "Installing parted. Please wait...";apt-get -y -q install parted; fi
fi

if [ ! -b "/dev/${DISK}1" ] && [ ! -b "/dev/${DISK}p1" ]; then
  if blkid "/dev/${DISK}" | grep -q '^.*'; then
    echo "WARNING: Data detected on bare disk.  Exiting."
    exit 4
  fi
  echo "Formatting disk /dev/${DISK} as ${FS} ..."
  parted -s "/dev/${DISK}" mklabel "$LABEL" mkpart primary "$FS" 1 100%
  sleep 2
  if [ -b "/dev/${DISK}1" ]; then
    PART="1"
  elif [ -b "/dev/${DISK}p1" ]; then
    PART="p1"
  else
    echo "WARNING: Cannot find partition for /dev/${DISK} .  Exiting."
    exit 5
  fi
  mkfs -t "$FS" "/dev/${DISK}${PART}" && \
  sed -i -e "/^\\/dev\\/${DISK}${PART}/d" /etc/fstab && \
  echo "/dev/${DISK}${PART} /data/${NUM} $FS defaults,noatime 1 2" >>/etc/fstab && \
  mkdir -p "/data/${NUM}" && \
  chattr +i "/data/${NUM}" && \
  mount "/data/${NUM}"
  echo "Disk /dev/${DISK}${PART} mounted at /data/${NUM}"
  if [ "$FS" == ext4 ]; then
    tune2fs -m 0 "/dev/${DISK}${PART}"
  fi
else
  echo "WARNING: Existing partition detected on disk.  Exiting."
  exit 6
fi

