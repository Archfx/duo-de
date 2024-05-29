FROM ubuntu:22.04
LABEL Alberto Ponces="ponces26@gmail.com"

COPY . /aosp/treble_aosp
RUN ln -s /aosp/treble_aosp/build.sh /usr/bin/treblebuild && \
    ln -s /aosp/treble_aosp/sync.sh /usr/bin/treblesync

ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 && \
    apt update && apt install -y \
    aapt \
    bc \
    bison \
    build-essential \
    curl \
    dos2unix \
    flex \
    fontconfig \
    g++-multilib \
    gcc-multilib \
    git \
    gnupg \
    gperf \
    imagemagick \
    jq \
    libncurses5 \
    libstdc++6 \
    libstdc++6:i386 \
    libxml2-utils \
    locales \
    lunzip \
    lzip \
    lzop \
    m4 \
    openjdk-17-jdk \
    python-is-python3 \
    python3-pip \
    rsync \
    simg2img \
    squashfs-tools \
    sudo \
    tree \
    unzip \
    wget \
    xattr \
    xmlstarlet \
    xsltproc \
    zip \
    zlib1g \
    zlib1g:i386 ; \
    apt clean autoclean

RUN locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

RUN curl https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt update && apt install git-lfs && \
    git lfs install

RUN git config --global user.name "Alberto Ponces" && \
    git config --global user.email ponces26@gmail.com && \
    git config --global color.ui auto

USER root
WORKDIR /aosp
