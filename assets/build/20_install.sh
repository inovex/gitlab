#!/bin/bash -xe

export DEBIAN_FRONTEND=noninteractive

# Execute a command as git
exec_as_git() {
  if [[ $(whoami) == git ]]; then
    $@
  else
    sudo -HEu git "$@"
  fi
}

# Updating package cache
apt-get update -qq

# Install build pkgs
apt-get install -V -y \
  ${BUILD_DEPENDENCIES?}

update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX
locale-gen en_US.UTF-8
dpkg-reconfigure locales

gem install --no-document bundler -v 1.17.3 \


# https://en.wikibooks.org/wiki/Grsecurity/Application-specific_Settings#Node.js
paxctl -Cm `which nodejs`

# remove the host keys generated during openssh-server installation
rm -rf \
  /etc/ssh/ssh_host_*_key \
  /etc/ssh/ssh_host_*_key.pub

# add git user
useradd --create-home --user-group --home-dir=${GITLAB_HOME?} git

# configure git for git
exec_as_git git config --global core.autocrlf input
exec_as_git git config --global gc.auto 0
exec_as_git git config --global repack.writeBitmaps true

###############################################
# Golang (used by gitlab-shell and others)
echo "Setup golang (${GOLANG_VERSION?})..."
wget -cnv https://storage.googleapis.com/golang/go${GOLANG_VERSION?}.linux-amd64.tar.gz -O /tmp/golang.tar.gz
tar -C /usr/local -xzf /tmp/golang.tar.gz
ln -sf /usr/local/go/bin/{go,godoc,gofmt} /usr/local/bin/

###############################################
# Gitlab
echo "Setup Gitlab ${GITLAB_VERSION?}.."
#exec_as_git git clone -q -b v${GITLAB_VERSION} --depth 1 ${GITLAB_CLONE_URL} ${GITLAB_INSTALL_DIR?}
exec_as_git mkdir -p ${GITLAB_INSTALL_DIR?}
exec_as_git wget -xnv ${GITLAB_DOWNLOAD_URL?} -O /tmp/gitlab.tar.gz
exec_as_git tar --strip-components=1 -xf /tmp/gitlab.tar.gz -C ${GITLAB_INSTALL_DIR?}
cd ${GITLAB_INSTALL_DIR?}

# configure bundler
exec_as_git mkdir -p ${GITLAB_INSTALL_DIR?}/.bundle/
cat > ${GITLAB_INSTALL_DIR?}/.bundle/config <<EOF
---
BUNDLE_JOBS: "6"
BUNDLE_PATH: "vendor/bundle"
BUNDLE_WITHOUT: "development:test:aws:mysql:kerberos"
EOF
chown git: ${GITLAB_INSTALL_DIR?}/.bundle/config

# gather required/installed component versions
GITLAB_SHELL_VERSION=$(cat ${GITLAB_INSTALL_DIR?}/GITLAB_SHELL_VERSION)
GITLAB_WORKHORSE_VERSION=$(cat ${GITLAB_INSTALL_DIR?}/GITLAB_WORKHORSE_VERSION)

# patch Gitlab to support oid connect (https://gitlab.com/gitlab-org/gitlab-ce/issues/23255)

#case ${GITLAB_VERSION?} in
#12.1.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#11.9.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#11.8.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#11.7.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#11.6.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#11.4.*)
#  git apply -v ${GITLAB_BUILD_DIR?}/patches/11.4/*
#;;
#*)
#  patch \
#    ${GITLAB_INSTALL_DIR?}/app/controllers/omniauth_callbacks_controller.rb \
#    ${GITLAB_BUILD_DIR?}/patches/old/omniauth_callbacks_controller.patch
#
#  patch \
#    ${GITLAB_INSTALL_DIR?}/lib/gitlab/o_auth/user.rb \
#    ${GITLAB_BUILD_DIR?}/patches/old/user.rb.patch#
#
#  patch \
#    ${GITLAB_INSTALL_DIR?}/lib/gitlab/ldap/person.rb \
#    ${GITLAB_BUILD_DIR?}/patches/old/person.rb.patch
#esac

# configure Gitlab
exec_as_git cp ${GITLAB_INSTALL_DIR?}/config/resque.yml.example ${GITLAB_INSTALL_DIR?}/config/resque.yml
exec_as_git cp ${GITLAB_INSTALL_DIR?}/config/gitlab.yml.example ${GITLAB_INSTALL_DIR?}/config/gitlab.yml
exec_as_git cp ${GITLAB_INSTALL_DIR?}/config/database.yml.postgresql ${GITLAB_INSTALL_DIR?}/config/database.yml

# revert `rake gitlab:setup` changes from gitlabhq/gitlabhq@a54af831bae023770bf9b2633cc45ec0d5f5a66a
exec_as_git sed -i 's/db:reset/db:setup/' ${GITLAB_INSTALL_DIR?}/lib/tasks/gitlab/setup.rake

# patch Gitlab to support oid connect (https://gitlab.com/gitlab-org/gitlab-ce/issues/23255)
#exec_as_git bundle add omniauth-openid-connect
exec_as_git bundle install --deployment

echo "Compiling assets. Please be patient, this will take a damn long while..."
exec_as_git yarn install --production --pure-lockfile
exec_as_git bundle exec rake gitlab:assets:compile USE_DB=false SKIP_STORAGE_VALIDATION=true NODE_OPTIONS="--max-old-space-size=4096"


###############################################
# Gitlab-Shell
echo "Setup gitlab-shell..."

cd ${GITLAB_INSTALL_DIR?}
exec_as_git bundle exec rake gitlab:shell:install SKIP_STORAGE_VALIDATION=true


###############################################
# Gitlab-Workhorse
echo "Setup gitlab-workhorse..."
exec_as_git bundle exec rake "gitlab:workhorse:install[${GITLAB_HOME?}/gitlab-workhorse]"

# Make the generated binaries available for everybody
find ${GITLAB_HOME?}/gitlab-workhorse -mindepth 1 -maxdepth 1 -type f -perm -o+x -exec ln -s {} /usr/bin/ \;


###############################################
# Gitaly
echo "Setup gitaly..."

cd ${GITLAB_INSTALL_DIR?}
case ${GITLAB_VERSION?} in
12.1.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
11.9.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
11.8.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
11.7.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
11.6.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
11.4.*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?},${GITLAB_REPOS_DIR?}]"
;;
*)
  exec_as_git bundle exec rake "gitlab:gitaly:install[${GITALY_INSTALL_DIR?}]"
;;
esac

###############################################
# MISC

# remove unused repositories directory created by gitlab-shell install
exec_as_git rm -rf ${GITLAB_HOME?}/repositories
exec_as_git ln -s ${GITLAB_REPOS_DIR?} ${GITLAB_HOME?}/repositories

exec_as_git mkdir -p \
  ${GITLAB_DATA_DIR?} \
  ${GITLAB_INSTALL_DIR?}/tmp/pids/ \
  ${GITLAB_INSTALL_DIR?}/tmp/sockets/

# remove auto generated files that need to be instance-specific
rm -rf \
  ${GITLAB_DATA_DIR?}/config/secrets.yml \
  ${GITLAB_INSTALL_DIR?}/.gitlab_shell_secret \
  ${GITLAB_INSTALL_DIR?}/.gitlab_workhorse_secret \
  ${GITLAB_HOME?}/.ssh \
  ${GITLAB_INSTALL_DIR?}/log \
  ${GITLAB_INSTALL_DIR?}/public/uploads \
  ${GITLAB_INSTALL_DIR?}/.secret

chmod -R u+rwX ${GITLAB_INSTALL_DIR?}/tmp

exec_as_git ln -sf ${GITLAB_DATA_DIR?}/.secret ${GITLAB_INSTALL_DIR?}/.secret
exec_as_git ln -sf ${GITLAB_DATA_DIR?}/.ssh ${GITLAB_HOME?}/.ssh
exec_as_git ln -sf ${GITLAB_DATA_DIR?}/uploads ${GITLAB_INSTALL_DIR?}/public/uploads
exec_as_git ln -sf ${GITLAB_LOG_DIR?}/gitlab ${GITLAB_INSTALL_DIR?}/log


# WORKAROUND for https://github.com/sameersbn/docker-gitlab/issues/509 #TODO still necessary?
rm -rf ${GITLAB_INSTALL_DIR?}/builds
rm -rf ${GITLAB_INSTALL_DIR?}/shared

# install gitlab bootscript, to silence gitlab:check warnings
cp ${GITLAB_INSTALL_DIR?}/lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab

###############################################
# SSHd
sed -i \
  -e "s|^[#]*UsePrivilegeSeparation yes|UsePrivilegeSeparation no|" \
  -e "s|^[#]*PasswordAuthentication yes|PasswordAuthentication no|" \
  -e "s|^[#]*LogLevel INFO|LogLevel VERBOSE|" \
  /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "AllowUsers git" >> /etc/ssh/sshd_config

###############################################
# Supervisor

# initializing logdirs
mkdir -p ${GITLAB_LOG_DIR?}/supervisor
chmod 755 ${GITLAB_LOG_DIR?}/supervisor
chown root: ${GITLAB_LOG_DIR?}/supervisor

mkdir -p ${GITLAB_LOG_DIR?}/gitlab
chmod 755 ${GITLAB_LOG_DIR?}/gitlab
chown git: ${GITLAB_LOG_DIR?}/gitlab

mkdir -p ${GITLAB_LOG_DIR?}/gitlab-shell
chmod 755 ${GITLAB_LOG_DIR?}/gitlab-shell
chown git: ${GITLAB_LOG_DIR?}/gitlab-shell

# move supervisord.log file to ${GITLAB_LOG_DIR?}/supervisor/
sed -i "s|^[#]*logfile=.*|logfile=${GITLAB_LOG_DIR?}/supervisor/supervisord.log ;|" /etc/supervisor/supervisord.conf

# configure supervisord log rotation #TODO do we need logrotation?
cat > /etc/logrotate.d/supervisord <<EOF
${GITLAB_LOG_DIR?}/supervisor/*.log {
  weekly
  missingok
  rotate 52
  compress
  delaycompress
  notifempty
  copytruncate
}
EOF

# configure gitlab log rotation
cat > /etc/logrotate.d/gitlab <<EOF
${GITLAB_LOG_DIR?}/gitlab/*.log {
  weekly
  missingok
  rotate 52
  compress
  delaycompress
  notifempty
  copytruncate
}
EOF

# configure gitlab-shell log rotation
cat > /etc/logrotate.d/gitlab-shell <<EOF
${GITLAB_LOG_DIR?}/gitlab-shell/*.log {
  weekly
  missingok
  rotate 52
  compress
  delaycompress
  notifempty
  copytruncate
}
EOF

# configure supervisord to start unicorn
cat > /etc/supervisor/conf.d/unicorn.conf <<EOF
[program:unicorn]
priority=10
directory=${GITLAB_INSTALL_DIR?}
environment=HOME=${GITLAB_HOME?}
command=bundle exec unicorn_rails -c ${GITLAB_INSTALL_DIR?}/config/unicorn.rb -E ${RAILS_ENV?}
user=git
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=${GITLAB_LOG_DIR?}/supervisor/%(program_name)s.log
stderr_logfile=${GITLAB_LOG_DIR?}/supervisor/%(program_name)s.log
EOF

# configure supervisor to start sshd
mkdir -p /var/run/sshd
cat > /etc/supervisor/conf.d/sshd.conf <<EOF
[program:sshd]
directory=/
command=/usr/sbin/sshd -D -E ${GITLAB_LOG_DIR?}/supervisor/%(program_name)s.log
user=root
autostart=true
autorestart=true
stdout_logfile=${GITLAB_LOG_DIR?}/supervisor/%(program_name)s.log
stderr_logfile=${GITLAB_LOG_DIR?}/supervisor/%(program_name)s.log
EOF

# purge build dependencies and cleanup apt
apt-get purge -V -y --auto-remove ${BUILD_DEPENDENCIES?}
rm -rf \
  /usr/local/go/ \
  /var/lib/apt/lists/* \
  /tmp/*

# make sure everything in ${GITLAB_HOME} is owned by git user
chown -R git: ${GITLAB_HOME?}
