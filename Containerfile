FROM docker.io/library/ubuntu:questing

COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install -y libzstd-dev libssl-dev pkg-config libostree-dev curl git build-essential meson libfuse3-dev ostree

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/bootc-dev/bootc.git bootc && \
    cd bootc && \
    git fetch --all && \
    git switch origin/composefs-backend -d && \
    /root/.cargo/bin/cargo build --release --bins && \
    install -Dpm0755 -t /usr/lib/dracut/modules.d/37composefs/ ./crates/initramfs/dracut/module-setup.sh && \
    install -Dpm0644 -t /usr/lib/systemd/system/ ./crates/initramfs/bootc-root-setup.service && \
    install -Dpm0755 -t /usr/bin ./target/release/bootc ./target/release/system-reinstall-bootc && \
    install -Dpm0755  ./target/release/bootc-initramfs-setup /usr/lib/bootc/initramfs-setup 

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
# RUN apt install -y ubuntu-desktop-minimal

# Make expected mutable / directories
RUN rm /snap -r && \
    mkdir -p /boot /sysroot /var/home && \
    rm -rf /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv && \
    ln -s /var/lib/snapd/snap /snap

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p '$6$AJv9RHlhEXO6Gpul$5fvVTZXeM0vC03xckTIjY8rdCofnkKSzvF5vEzXDKAby5p3qaOGTHDypVVxKsCE3CbZz7C3NXnbpITrEUvN/Y/' root

# Necessary labels
LABEL containers.bootc 1
