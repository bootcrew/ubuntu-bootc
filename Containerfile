FROM docker.io/library/ubuntu:questing

COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install -y libzstd-dev libssl-dev pkg-config libostree-dev curl git build-essential meson libfuse3-dev ostree

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV CARGO_FEATURES="composefs-backend"
ENV PATH="/root/.cargo/bin:$PATH"

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/bootc-dev/bootc.git bootc && \
    cd bootc && \
    git fetch --all && \
    git switch origin/composefs-backend -d && \
    make && \
    make install-all && \
    make install-initramfs-dracut

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/p5/coreos-bootupd.git bootupd && \
    cd bootupd && \
    git fetch --all && \
    git switch origin/sdboot-support -d && \
    /root/.cargo/bin/cargo build --release --bins --features systemd-boot && \
    install -Dpm0755 -t /usr/bin ./target/release/bootupd && \
    ln -s ./bootupd /usr/bin/bootupctl

RUN apt install -y \
  dracut \
  linux-image-generic \
  linux-firmware \
  systemd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  udev \
  cpio \
  zstd \
  binutils \
  dosfstools \
  conmon \
  crun \
  netavark \
  skopeo \
  dbus \
  fdisk \
  systemd-boot*

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    cp /boot/vmlinuz-$(cat kernel_version.txt) "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    rm kernel_version.txt

# If you want a desktop :)
RUN apt install -y ubuntu-desktop-minimal

# Make expected mutable / directories
RUN rm /snap -rf && \
    mkdir -p /boot /sysroot /var/home && \
    rm -rf /var/log /root /usr/local /srv && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv && \
    mkdir -p /snap /home /root

COPY files/root.mount /usr/lib/systemd/system/
COPY files/home.mount /usr/lib/systemd/system/
COPY files/snap.mount /usr/lib/systemd/system/
COPY files/tmpfiles-snap.conf /usr/lib/tmpfiles.d/

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p '$6$AJv9RHlhEXO6Gpul$5fvVTZXeM0vC03xckTIjY8rdCofnkKSzvF5vEzXDKAby5p3qaOGTHDypVVxKsCE3CbZz7C3NXnbpITrEUvN/Y/' root

RUN systemctl enable home.mount snap.mount root.mount
RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-no-languages && \
    userdel --remove ubuntu && \
    mkdir --parents /etc/pkcs11/modules && \
     mkdir /usr/share/empty

# Necessary labels
LABEL containers.bootc 1
