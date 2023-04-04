# Build Arguments
## BASEIMAGE   : Base image for the build
## BASETAG     : Tag of base image for the build
## OSK_VERSION : Desired OpenSatKit version
ARG BASEIMAGE
ARG BASETAG

# STAGE FOR CACHING APT PACKAGE LIST
FROM ${BASEIMAGE}:${BASETAG} as stage_apt

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# UPDATE APT REPOSITORY FOR CACHING PACKAGE LISTS
RUN \
    rm -rf /etc/apt/apt.conf.d/docker-clean \
	&& echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
	&& apt-get update


# STAGE FOR INSTALLING APT DEPENDENCIES
FROM ${BASEIMAGE}:${BASETAG} as stage_deps

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV \
    DEBIAN_FRONTEND=noninteractive \
    NONINTERACTIVE=true \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/home/user/.rbenv/bin:$PATH

# INSTALL APT DEPENDENCIES USING CACHE OF stage_apt
RUN \
    --mount=type=cache,target=/var/cache/apt,from=stage_apt,source=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt,from=stage_apt,source=/var/lib/apt \
    --mount=type=cache,target=/etc/apt/sources.list.d,from=stage_apt,source=/etc/apt/sources.list.d \
	  apt-get upgrade -y

# GET LIST OF DEPENDENCIES AVAILABLE BY APT
COPY requirements.txt /tmp/aptdeps.txt

# INSTALL DEPENDENCIES BY APT
## --no-install-recommends IS NOT APPLIED
## SINCE THAT WILL CAUSE DEPENDENCY ERROR FOR COSMOS BUILD
RUN \
    --mount=type=cache,target=/var/cache/apt,from=stage_apt,source=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt,from=stage_apt,source=/var/lib/apt \
    --mount=type=cache,target=/etc/apt/sources.list.d,from=stage_apt,source=/etc/apt/sources.list.d \
	  apt-get install -y $(cat /tmp/aptdeps.txt) \
    && rm -rf /tmp/*

# Add non-root user 'user' with group 'user'
RUN \
    groupadd user \
    && useradd -ms /bin/bash user -g user \
    && echo "user ALL=NOPASSWD: ALL" >> /etc/sudoers

# Change default user and directory for running a container
USER user
WORKDIR /home/user

# Install Ruby 2.5.8
RUN \
    git clone https://github.com/rbenv/rbenv.git /home/user/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git /home/user/.rbenv/plugins/ruby-build \
    && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/user/.bashrc \
    && echo 'eval "$(rbenv init -)"' >> /home/user/.bashrc \
    && rbenv init - \
    && CONFIGURE_OPTS="--enable-shared" rbenv install 2.5.8 \
    && rbenv rehash \
    && rbenv global 2.5.8 \
    && echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc


# STAGE FOR BUILDING APPLICATION CONTAINER
FROM stage_deps as stage_app

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG OSK_VERSION

ENV \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/home/user/.rbenv/shims:$PATH

# CLONE OpenSatKit REPOSITORY, BUILD CFS AND GRANT RUN PERMISSION
RUN \
    git clone -b ${OSK_VERSION} https://github.com/OpenSatKit/OpenSatKit.git \
    && make distclean -C /home/user/OpenSatKit/cfs \
    && make prep -C /home/user/OpenSatKit/cfs \
    && make -C /home/user/OpenSatKit/cfs \
    && make install -C /home/user/OpenSatKit/cfs \
    && chmod u=rwx /home/user/OpenSatKit/cfs/cmake.sh

# BUILD 42 SIMULATOR AND GRANT RUN PERMISSION
RUN \
    make -C /home/user/OpenSatKit/42 \
    && chmod u=rx /home/user/OpenSatKit/42/42

# CHANGE INITIAL DIRECTORY TO COSMOS DIRECTORY
WORKDIR /home/user/OpenSatKit/cosmos

# BUILD COSMOS AND GRANT RUN PERMISSION
RUN \
    source /home/user/.bashrc \
    && gem install bundler -v 1.17.3 \
    && gem install qtbindings -v 4.8.6.5 \
    && bundle install

# COPY INITIALIZATION SCRIPT USED AS A DOCKER CMD
COPY --chmod=777 entrypoint.sh /usr/local/bin/entrypoint.sh

# APPLY LABELS TO THIS CONTAINER
LABEL title="OpenSatkit Container"
LABEL version="v2.5-20230224"
LABEL description="Dockerized OpenSatKit container \
for Cubesat development" 

# SET INTIALIZATION SCRIPT AS DEFAULT CMD
CMD [ "/usr/local/bin/entrypoint.sh" ]

# ---------- BUILD COMMAND ----------
# DOCKER_BUILDKIT=1 docker build --no-cache \
# --build-arg BASEIMAGE=ubuntu \
# --build-arg BASETAG=18.04 \
# --build-arg OSK_VERSION=v2.5 \
# -t kestr3l/opensatkit:18.04-v2.5-original \
# -f Dockerfile .
