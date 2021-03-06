#!/bin/bash
set -e  # Fail on errors
set -x  # Verbosity all the way

# Upgrade pbuilder
sudo apt-get install pbuilder
wget http://mirrors.kernel.org/ubuntu/pool/main/p/pbuilder/pbuilder_0.215ubuntu7_all.deb
sudo dpkg -i pbuilder*deb

GIT_IGNORE_NEW="true"
USE_ALIOTH="false"
SKIP_PBUILDER="false"
BUILD_JUST_SOURCE_IN_TRAVIS="true"
DPKG_SOURCE_COMMIT="false"
DO_NOT_SIGN=true
PACKAGE="python-scikits.audiolab"

if [[ "$DO_NOT_SIGN" == "true" ]] ; then
    EXTRA_BUILDPACKAGE_ARGS="$EXTRA_GIT_BUILDPACKAGE_ARGS -us -uc"
else
    EXTRA_BUILDPACKAGE_ARGS="$EXTRA_GIT_BUILDPACKAGE_ARGS"
fi

export DEBEMAIL=asheesh@asheesh.org
export DEBFULLNAME="Asheesh Laroia"
echo "CCACHEDIR=" | sudo tee -a /etc/pbuilderrc  # Hoping to disable ccache use by pbuilder

# Tell git on Travis who we are
git config --global user.email travis-ci@asheesh.org
git config --global user.name "Asheesh Laroia (on travis-ci.org)"

dget --allow-unauthenticated -x "http://mentors.debian.net/debian/pool/main/p/python-scikits.audiolab/python-scikits.audiolab_0.11.0-1.dsc"

# Smarter install build-deps
sudo apt-get install devscripts equivs
sudo mk-build-deps -i "$PACKAGE"*dsc

# Make sure it builds outside a pbuilder
cd "$PACKAGE"*

# FIXME: Check if it's a dfsg package, and only then
# set this to true.
CHECK_GET_ORIG_SOURCE="false"

## HACK
# Don't bother with this for scikits learn
# Rely on the pbuilder.
#dpkg-buildpackage $EXTRA_BUILDPACKAGE_ARGS

if [[ "$SKIP_PBUILDER" == "true" ]] ; then
    exit 0  # skip pbuilder for now
fi

# Create a pbuilder chroot
## FIXME: Cache this somewhere.
sudo apt-get install ubuntu-dev-tools
wget https://ftp-master.debian.org/keys/archive-key-7.0.asc
gpg --import $PWD/archive-key-7.0.asc
pbuilder-dist sid create --debootstrapopts --keyring=$HOME/.gnupg/pubring.gpg --mirror http://cdn.debian.net/debian/ || pbuilder-dist sid create --debootstrapopts --keyring=$HOME/.gnupg/pubring.gpg --mirror http://mirror.mit.edu/debian/


# Before building, add a hook to run lintian
mkdir ~/pbuilderhooks
cp /usr/share/doc/pbuilder/examples/B90lintian $HOME/pbuilderhooks
echo "HOOKDIR=$HOME/pbuilderhooks/" >> ~/.pbuilderrc
# FIXME: also run piuparts or something else???

pbuilder-dist sid build ../*.dsc

if [[ "$CHECK_GET_ORIG_SOURCE" == "true" ]] ; then
    # Make sure get-orig-source works
    debian/rules get-orig-source
fi
