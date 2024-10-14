#! /bin/bash

print_supported_os_versions() {
    1>&2 echo "    Ubuntu 16.04"
    1>&2 echo "    Ubuntu 18.04"
    1>&2 echo "    Ubuntu 20.04"
    1>&2 echo "    Ubuntu 22.04"
}

echo "------------------------------------------------------------"
echo "Purpose of this script:"
echo ""
echo "On a supported operating system that has not had any additional"
echo "packages installed yet, install a set of packages that are"
echo "needed to successfully create the HTML and PDF versions of these"
echo "documents from their Madoko source files (files with names that"
echo "end with '.mdk'):"
echo ""
echo "+ The P4_16 language specification"
echo "+ The Portable Switch Architecture (PSA) specification"
echo ""
echo "While it would be nice if I could assure you that this script"
echo "will work on a system that already had many packages installed,"
echo "I do not know which packages might have conflicts with each"
echo "other."
echo "------------------------------------------------------------"

# This is where the application gnome-font-viewer copies font files
# when a user clicks the "Install" button.
FONT_INSTALL_DIR="${HOME}/.local/share/fonts"

warning() {
    1>&2 echo "This script has only been tested on these OS versions:"
    print_supported_os_versions
}

lsb_release >& /dev/null
if [ $? != 0 ]
then
    1>&2 echo "No 'lsb_release' found in your command path."
    warning
    exit 1
fi

DISTRIBUTOR_ID=`lsb_release -si`
UBUNTU_RELEASE=`lsb_release -sr`

if [ ${DISTRIBUTOR_ID} != "Ubuntu" -o \( ${UBUNTU_RELEASE} != "16.04" -a ${UBUNTU_RELEASE} != "18.04" -a ${UBUNTU_RELEASE} != "20.04" -a ${UBUNTU_RELEASE} != "22.04" \) ]
then
    warning
    1>&2 echo ""
    1>&2 echo "Here is what command 'lsb_release -a' shows this OS to be:"
    lsb_release -a
    exit 1
fi

set -ex

set +x
echo "------------------------------------------------------------"
echo "Time and disk space used before installation begins:"
set -x
date
df -BM .

# Common packages to install on all tested Ubuntu versions
sudo apt-get --yes install git curl make nodejs npm texlive-xetex dvipng

if [[ "${UBUNTU_RELEASE}" > "18" ]]
then
    # Only needed for Ubuntu 18.04 and later
    sudo apt-get --yes install texlive-science
else
    # Only needed for Ubuntu 16.04
    sudo apt-get --yes install nodejs-legacy texlive-generic-extra texlive-math-extra
fi

# Common packages to install on all tested Ubuntu versions
sudo npm install madoko -g

set +x
echo "------------------------------------------------------------"
echo "Time and disk space used just before 'apt clean':"
set -x
date
df -BM .

# After install of the packages above, this command often seems to
# help reduce the disk space used by a gigabyte or so.
sudo apt clean

# On a freshly installed Ubuntu 16.04 system, added about 1.3G to the
# used disk space, although temporarily went about 1 GB more than that
# before 'sudo apt clean'.

# On a freshly installed Ubuntu 18.04 system, added about 0.8G.

# Retrieve and install fonts
mkdir -p "${FONT_INSTALL_DIR}"
curl -fsSL --output "${FONT_INSTALL_DIR}/UtopiaStd-Regular.otf" https://raw.github.com/p4lang/p4-spec/gh-pages/fonts/UtopiaStd-Regular.otf
curl -fsSL --output "${FONT_INSTALL_DIR}/luximr.ttf" https://raw.github.com/p4lang/p4-spec/gh-pages/fonts/luximr.ttf

set +x
echo "------------------------------------------------------------"
echo "Time and disk space used when installation was complete:"
set -x
date
df -BM .

if [ ${DISTRIBUTOR_ID} == "Ubuntu" -a ${UBUNTU_RELEASE} == "22.04" ]
then
    set +x
    1>&2 echo ""
    1>&2 echo "------------------------------------------------------------"
    1>&2 echo "WARNING!"
    1>&2 echo "------------------------------------------------------------"
    1>&2 echo ""
    1>&2 echo "While this script can successfully install the required"
    1>&2 echo "packages on an Ubuntu 22.04 system like this one, these"
    1>&2 echo "installed packages are different versions than for"
    1>&2 echo "other supported OS's, and in our testing they GIVE"
    1>&2 echo "ERRORS and FAIL TO BUILD HTML and PDF files for the P4"
    1>&2 echo "specifications.  See this issue:"
    1>&2 echo ""
    1>&2 echo "    https://github.com/p4lang/p4-spec/issues/1115"
    1>&2 echo ""
    1>&2 echo "If you know how to fix this, your help is much appreciated."
fi
