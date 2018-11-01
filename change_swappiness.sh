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
# Copyright Clairvoyant 2015

VAL=1

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

echo "Changing vm.swappiness running value to ${VAL}."
sysctl -w vm.swappiness=$VAL

echo "Setting vm.swappiness startup value to ${VAL}."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ "$OSREL" == 6 ]; then
    if grep -q vm.swappiness /etc/sysctl.conf; then
      sed -i -e "/^vm.swappiness/s|=.*|= $VAL|" /etc/sysctl.conf
    else
      echo "vm.swappiness = $VAL" >>/etc/sysctl.conf
    fi
  else
    if grep -q vm.swappiness /etc/sysctl.conf; then
      sed -i -e '/^vm.swappiness/d' /etc/sysctl.conf
    fi
    install -m 0644 -o root -g root /dev/null /etc/sysctl.d/cloudera.conf
    echo "# Tuning for Hadoop installation. CLAIRVOYANT" >/etc/sysctl.d/cloudera.conf
    echo "vm.swappiness = $VAL" >>/etc/sysctl.d/cloudera.conf
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  if grep -q vm.swappiness /etc/sysctl.conf; then
    sed -i -e '/^vm.swappiness/d' /etc/sysctl.conf
  fi
  install -m 0644 -o root -g root /dev/null /etc/sysctl.d/cloudera.conf
  echo "# Tuning for Hadoop installation. CLAIRVOYANT" >/etc/sysctl.d/cloudera.conf
  echo "vm.swappiness = $VAL" >>/etc/sysctl.d/cloudera.conf
fi

