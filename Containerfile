FROM docker.io/library/ubuntu:questing

ARG DEBIAN_FRONTEND=noninteractive
# Antipattern but we are doing this since `apt`/`debootstrap` does not allow chroot installation on unprivileged podman builds
ENV DEV_DEPS="libzstd-dev libssl-dev pkg-config libostree-dev curl git build-essential meson libfuse3-dev go-md2man dracut"

RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-no-languages && \
    apt update -y && \
    apt install -y $DEV_DEPS ostree

ENV CARGO_HOME=/tmp/rust
ENV RUSTUP_HOME=/tmp/rust
RUN --mount=type=tmpfs,dst=/tmp \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile minimal -y && \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    sh -c ". ${RUSTUP_HOME}/env ; make -C /tmp/bootc bin install-all install-initramfs-dracut"

ENV DRACUT_NO_XATTR=1
RUN apt install -y \
  btrfs-progs \
  dosfstools \
  e2fsprogs \
  fdisk \
  linux-firmware \
  linux-image-generic \
  skopeo \
  systemd \
  systemd-boot* \
  xfsprogs

RUN sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$KERNEL_VERSION/initramfs.img" && \
    cp /boot/vmlinuz-$KERNEL_VERSION "/usr/lib/modules/$KERNEL_VERSION/vmlinuz"'

# Setup a temporary root passwd (changeme) for dev purposes
# RUN apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN apt remove -y $DEV_DEPS && \
    apt autoremove -y
ENV DEV_DEPS=

# Currently (03/11/2025), bootc relies on `cp -a` to properly copy the `/etc` for three-way merging, which entirely breaks on uutils `cp` since it scans the directories, than copies, so no files actually get copied during an update or rebase. Please remove once bootc upstream has changed these lines:
# https://github.com/bootc-dev/bootc/blob/042aa21d235dd9f13f30b74d0b515e46f03f88e2/crates/lib/src/bootc_composefs/state.rs#L95-L101
# FIXME: remove
RUN apt install -y busybox && \
    ln -s ./busybox /usr/bin/cp

COPY files/root.mount /usr/lib/systemd/system/
COPY files/home.mount /usr/lib/systemd/system/
COPY files/snap.mount /usr/lib/systemd/system/
COPY files/tmpfiles-snap.conf /usr/lib/tmpfiles.d/

RUN systemctl enable home.mount snap.mount root.mount

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"

# We do this slightly differently from other images because of snapd
RUN rm -rf /snap /boot /root /usr/local /srv && \
    mkdir -p /boot /sysroot /var/home /snap /home /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s sysroot/ostree /ostree && \
    ln -s /var/srv /srv

# Necessary for `bootc install`
RUN mkdir -p /usr/lib/ostree && \
    printf "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | \
    tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
