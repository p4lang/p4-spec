#! /bin/bash

# Copyright 2024 Andy Fingerhut

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

linux_version_warning() {
    1>&2 echo "Found ID ${ID} and VERSION_ID ${VERSION_ID} in /etc/os-release"
    1>&2 echo "This script only supports these:"
    1>&2 echo "    ID ubuntu, VERSION_ID in 20.04 22.04 24.04"
    #1>&2 echo "    ID fedora, VERSION_ID in 36 37 38"
    1>&2 echo ""
    1>&2 echo "Proceed installing manually at your own risk of"
    1>&2 echo "significant time spent figuring out how to make it all"
    1>&2 echo "work, or consider getting VirtualBox and creating a"
    1>&2 echo "virtual machine with one of the tested versions."
}

get_used_disk_space_in_mbytes() {
    echo $(df --output=used --block-size=1M . | tail -n 1)
}

abort_script=0

if [ ! -r /etc/os-release ]
then
    1>&2 echo "No file /etc/os-release.  Cannot determine what OS this is."
    linux_version_warning
    exit 1
fi
source /etc/os-release
PROCESSOR=`uname --machine`

supported_distribution=0
tried_but_got_build_errors=0
if [ "${ID}" = "ubuntu" ]
then
    case "${VERSION_ID}" in
	20.04)
	    supported_distribution=1
	    OS_SPECIFIC_PACKAGES="libgdk-pixbuf2.0-dev"
	    ;;
	22.04)
	    supported_distribution=1
	    OS_SPECIFIC_PACKAGES="libgdk-pixbuf-2.0-dev"
	    ;;
	24.04)
	    supported_distribution=1
	    OS_SPECIFIC_PACKAGES="libgdk-pixbuf-2.0-dev"
	    ;;
    esac
elif [ "${ID}" = "fedora" ]
then
    case "${VERSION_ID}" in
	38)
	    supported_distribution=0
	    ;;
	39)
	    supported_distribution=0
	    ;;
	40)
	    supported_distribution=0
	    ;;
    esac
fi

if [ ${supported_distribution} -eq 1 ]
then
    echo "Found supported ID ${ID} and VERSION_ID ${VERSION_ID} in /etc/os-release"
else
    linux_version_warning
    if [ ${tried_but_got_build_errors} -eq 1 ]
    then
	1>&2 echo ""
	1>&2 echo "This OS has been tried at least onc before, but"
	1>&2 echo "there were errors during a compilation or build"
	1>&2 echo "step that have not yet been fixed.  If you have"
	1>&2 echo "experience in fixing such matters, your help is"
	1>&2 echo "appreciated."
    fi
    exit 1
fi

min_free_disk_MBytes=`expr 1 \* 1024`
free_disk_MBytes=`df --output=avail --block-size=1M . | tail -n 1`

if [ "${free_disk_MBytes}" -lt "${min_free_disk_MBytes}" ]
then
    free_disk_comment="too low"
    abort_script=1
else
    free_disk_comment="enough"
fi

echo "Minimum free disk space to run this script:    ${min_free_disk_MBytes} MBytes"
echo "Free disk space on this system from df output: ${free_disk_MBytes} MBytes -> $free_disk_comment"

if [ "${abort_script}" == 1 ]
then
    echo ""
    echo "Aborting script because system has too little free disk space"
    exit 1
fi

echo "Passed all sanity checks"

DISK_USED_START=`get_used_disk_space_in_mbytes`

set -e
set -x

echo "------------------------------------------------------------"
echo "Time and disk space used before installation begins:"
set -x
date
df -h .
df -BM .
TIME_START=$(date +%s)

# On new systems if you have never checked repos you should do that first

# Install a few packages (vim is not strictly necessary -- installed for
# my own convenience):
if [ "${ID}" = "ubuntu" ]
then
    sudo apt-get --yes install gnupg2 curl
elif [ "${ID}" = "fedora" ]
then
    sudo dnf -y update
    sudo dnf -y install git vim
fi

gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash
if [[ $UID == 0 ]]; then
    source /usr/local/rvm/scripts/rvm
else
    source $HOME/.rvm/scripts/rvm
fi
rvm install ruby-3.3.1
rvm use 3.3.1
gem install asciidoctor
gem install asciidoctor-pdf
gem install asciidoctor-bibtex
# Additional installations to enable installing
# asciidoctor-mathematical and prawn-gmagick
# libreoffice is required for the P4Runtime API specification Makefile,
# to generate png and svg format figure files from the .odg files.
sudo apt-get --yes install cmake flex libglib2.0-dev libcairo2-dev libpango1.0-dev libxml2-dev libwebp-dev libzstd-dev libgraphicsmagick1-dev libmagickwand-dev libreoffice ${OS_SPECIFIC_PACKAGES}
gem install asciidoctor-mathematical
gem install prawn-gmagick
gem install rouge
gem install asciidoctor-bibtex
gem install asciidoctor-lists
gem install prawn-gmagick

which ruby
ruby --version
which gem
gem --version
which asciidoctor
asciidoctor --version
which asciidoctor-pdf
asciidoctor-pdf --version

set +e

set +x
echo "------------------------------------------------------------"
echo "Time and disk space used when installation was complete:"
set -x
date
df -h .
df -BM .
TIME_END=$(date +%s)
set +x
echo ""
echo "Elapsed time for various install steps:"
echo "Total time             : $(($TIME_END-$TIME_START)) sec"
set -x

DISK_USED_END=`get_used_disk_space_in_mbytes`

set +x
echo "All disk space utilizations below are in MBytes:"
echo ""
echo  "DISK_USED_START                ${DISK_USED_START}"
echo  "DISK_USED_END                  ${DISK_USED_END}"
echo  "DISK_USED_END - DISK_USED_START : $((${DISK_USED_END}-${DISK_USED_START})) MBytes"

echo "----------------------------------------------------------------------"
echo "CONSIDER READING WHAT IS BELOW"
echo "----------------------------------------------------------------------"
echo ""
echo "You should add this command in a shell startup script, e.g."
echo "$HOME/.bashrc if you use the Bash shell:"
echo ""
echo "    source \$HOME/.rvm/scripts/rvm"
echo ""
echo "----------------------------------------------------------------------"
echo "CONSIDER READING WHAT IS ABOVE"
echo "----------------------------------------------------------------------"
