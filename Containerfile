FROM docker.io/library/ubuntu:questing

ARG DEBIAN_FRONTEND=noninteractive
# Antipattern but we are doing this since `apt`/`debootstrap` does not allow chroot installation on unprivileged podman builds
ENV DEV_DEPS="libzstd-dev libssl-dev pkg-config libostree-dev curl git build-essential meson libfuse3-dev go-md2man dracut whois dracut"

RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-no-languages && \
    userdel --remove ubuntu && \
    mkdir --parents /etc/pkcs11/modules && \
    mkdir /usr/share/empty && \
    apt update -y && \
    apt install -y $DEV_DEPS ostree

ENV CARGO_FEATURES="composefs-backend"
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile minimal -y && \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    cd /tmp/bootc && \
    PATH=/root/.cargo/bin:$PATH make && \
    make install-all && \
    make install-initramfs-dracut && \
    git clone https://github.com/p5/coreos-bootupd.git -b sdboot-support /tmp/bootupd && \
    cd /tmp/bootupd && \
    /root/.cargo/bin/cargo build --release --bins --features systemd-boot && \
    make install

RUN apt install -y \
  linux-image-generic \
  linux-firmware \
  systemd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  dosfstools \
  skopeo \
  fdisk \
  systemd-boot*

ENV DRACUT_NO_XATTR=1
RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    cp /boot/vmlinuz-$(cat kernel_version.txt) "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    rm kernel_version.txt

COPY files/root.mount /usr/lib/systemd/system/
COPY files/home.mount /usr/lib/systemd/system/
COPY files/snap.mount /usr/lib/systemd/system/
COPY files/tmpfiles-snap.conf /usr/lib/tmpfiles.d/

RUN systemctl enable home.mount snap.mount root.mount

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN apt remove -y $DEV_DEPS && \
    apt autoremove -y

ENV DEV_DEPS=

RUN rm /snap /var /boot -rf && \
    mkdir -p /boot /sysroot /var/home /snap /home /root && \
    rm -rf /root /usr/local /srv && \
    ln -s /var/usrlocal /usr/local && \
    ln -s sysroot/ostree /ostree && \
    ln -s /var/srv /srv

# Necessary for `bootc install`
RUN mkdir -p /usr/lib/ostree/prepare-root && tee "/usr/lib/ostree/prepare-root.conf" <<EOF
[composefs]
enabled = yes
[sysroot]
readonly = true
EOF

RUN bootc container lint

# Necessary labels
LABEL containers.bootc 1
