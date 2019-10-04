#!/bin/bash -xe

export DEBIAN_FRONTEND=noninteractive


# Updating package cache and install wget to import keys
apt-get update -qq
apt-get install -Vy \
  apt-transport-https \
  gnupg2 \
  sudo \
  wget

# Preparing pkg repos for use
cat >> /etc/apt/sources.list.d/gitlab-install.list <<-EOF
deb http://ppa.launchpad.net/git-core/ppa/ubuntu bionic main
deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu bionic main
deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main
deb https://dl.yarnpkg.com/debian/ stable main
EOF

case ${GITLAB_VERSION?} in
*)
  echo "deb https://deb.nodesource.com/node_12.x bionic main" >> /etc/apt/sources.list.d/gitlab-install.list
;;
esac

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8B3981E7A6852F782CC4951600A6F0A3C300EE8C
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E1DD270288B4E6030699E45FA1715D88E1DF1F24
wget --quiet -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
wget --quiet -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Updating package cache
apt-get update -qq

# Install all needed pkgs (except build pkgs)
apt-get install -Vy \
  ${GITLAB_DEPENDENCIES?}

# cleanup apt
rm -rf /var/lib/apt/lists/*

# Check GIT Version
git --version
