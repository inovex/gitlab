FROM ubuntu:bionic-20190912.1

ARG GITLAB_VERSION
ARG GITLAB_DOWNLOAD_URL=https://gitlab.com/gitlab-org/gitlab-ce/repository/v${GITLAB_VERSION}/archive.tar.gz
ARG GOLANG_VERSION=1.12.9

# sperated ENV layers due to dependices to upper-layered env vars
ENV \
  GITLAB_DATA_DIR="/home/git/data" \
  GITLAB_HOME="/home/git" \
  GITLAB_INSTALL_DIR="/home/git/gitlab" \
  GITLAB_SHELL_INSTALL_DIR="/home/git/gitlab-shell"

ENV \
  BUILD_DEPENDENCIES="\
    build-essential \
    cmake \
    g++ \
    gcc \
    gettext \
    libc6-dev \
    libcurl4-openssl-dev \
    libffi-dev \
    libgdbm-dev \
    libicu-dev \
    libncurses5-dev \
    libpq-dev \
    libreadline-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    libyaml-dev \
    make \
    patch \
    paxctl \
    pkg-config \
    ruby2.6-dev \
    runit \
    rsync \
    checkinstall \
    zlib1g-dev \
  " \
  GITLAB_DEPENDENCIES="\
    curl \
    gettext-base \
    graphicsmagick \
    libpcre2-8-0 \
    git-core \
    libcurl4 \
    libffi6 \
    libgdbm5 \
    libicu60 \
    libncurses5 \
    libpq5 \
    libimage-exiftool-perl \
    libre2-dev \
    libreadline7 \
    libssl1.0.0 \
    libxml2 \
    libxslt1.1 \
    libyaml-0-2 \
    locales \
    logrotate \
    nodejs \
    openssh-server \
    postgresql-client-10 \
    postgresql-contrib-10 \
    python3 \
    python3-docutils \
    redis-tools \
    ruby2.6 \
    supervisor \
    tzdata \
    yarn \
    zlib1g \
  " \
  GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
  GITALY_SOCKET_PATH="${GITLAB_INSTALL_DIR}/tmp/sockets/private/gitaly.socket" \
  GITLAB_BACKUP_DIR="${GITLAB_DATA_DIR}/backups" \
  GITLAB_BUILDS_DIR="${GITLAB_DATA_DIR}/builds" \
  GITLAB_BUILD_DIR="/tmp/build" \
  GITLAB_CONFIG="${GITLAB_INSTALL_DIR}/config/gitlab.yml" \
  GITLAB_DATABASE_CONFIG="${GITLAB_INSTALL_DIR}/config/database.yml" \
  GITLAB_LOG_DIR="/var/log/gitlab" \
  GITLAB_METRICS_DIR="${GITLAB_DATA_DIR}/metrics" \
  GITLAB_RACK_ATTACK_CONFIG="${GITLAB_INSTALL_DIR}/config/initializers/rack_attack.rb" \
  GITLAB_REPOS_DIR="${GITLAB_DATA_DIR}/repositories" \
  GITLAB_RESQUE_CONFIG="${GITLAB_INSTALL_DIR}/config/resque.yml" \
  GITLAB_ROBOTS_CONFIG="${GITLAB_INSTALL_DIR}/public/robots.txt" \
  GITLAB_RUNTIME_DIR="/etc/docker-gitlab/" \
  GITLAB_SECRETS_CONFIG="${GITLAB_INSTALL_DIR}/config/secrets.yml" \
  GITLAB_SHARED_DIR="${GITLAB_DATA_DIR}/shared" \
  GITLAB_SHELL_CONFIG="${GITLAB_SHELL_INSTALL_DIR}/config.yml" \
  GITLAB_SMTP_CONFIG="${GITLAB_INSTALL_DIR}/config/initializers/smtp_settings.rb" \
  GITLAB_TEMP_DIR="${GITLAB_DATA_DIR}/tmp" \
  GITLAB_UNICORN_CONFIG="${GITLAB_INSTALL_DIR}/config/unicorn.rb" \
  NODE_ENV=production \
  RAILS_ENV=production \
  prometheus_multiproc_dir=${GITLAB_DATA_DIR}/prometheus \
  TERM=xterm

ENV \
  GITLAB_ARTIFACTS_DIR="${GITLAB_SHARED_DIR}/artifacts" \
  GITLAB_DOWNLOADS_DIR="${GITLAB_TEMP_DIR}/downloads" \
  GITLAB_LFS_OBJECTS_DIR="${GITLAB_SHARED_DIR}/lfs-objects" \
  GITLAB_PAGES_DIR="${GITLAB_SHARED_DIR}/pages" \
  GITLAB_REGISTRY_DIR="${GITLAB_SHARED_DIR}/registry" 

COPY assets/runtime/ ${GITLAB_RUNTIME_DIR}/

COPY assets/build/10_prepare-install.sh ${GITLAB_BUILD_DIR}/
RUN ${GITLAB_BUILD_DIR}/10_prepare-install.sh

COPY assets/build/20_install.sh ${GITLAB_BUILD_DIR}/
RUN ${GITLAB_BUILD_DIR}/20_install.sh

WORKDIR ${GITLAB_INSTALL_DIR}
CMD /bin/bash -c "\
  source ${GITLAB_RUNTIME_DIR?}/functions && \
  initialize_system && \
  exec /usr/bin/supervisord -nc /etc/supervisor/supervisord.conf"

