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

# ARGV:
# 1 - LDAP BaseDN - required
# 2 - LDAP server hostname - required

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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing PAM LDAP..."
LDAPBASEDN=$1
if [ -z "$LDAPBASEDN" ]; then
  echo "ERROR: Missing LDAP Base DN."
  exit 1
fi
LDAPSERVER=$2
if [ -z "$LDAPSERVER" ]; then
  echo "ERROR: Missing LDAP server."
  exit 1
fi
#LDAPBASEDN="dc=clairvoyantsoft,dc=com"
#LDAPSERVER=server.clairvoyantsoft.com

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # http://blog.zwiegnet.com/linux-server/configure-centos-7-ldap-client/
  yum -y -e1 -d1 install nss-pam-ldapd
  #yum -y -e1 -d1 install openldap-clients
  authconfig --enableforcelegacy --update
  authconfig --enableldap --ldapserver="${LDAPSERVER}" --ldapbasedn="${LDAPBASEDN}" --update
  #authconfig --enableldapauth --enableldaptls --update
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

