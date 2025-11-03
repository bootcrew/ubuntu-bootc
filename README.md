# Ubuntu Bootc

Experiment to see if Bootc could work on Ubuntu

<img width="2192" height="1239" alt="image" src="https://github.com/user-attachments/assets/a203c7ab-3a13-40da-baf2-d73e5b3b34d1" />

## Building

In order to get a running ubuntu-bootc system you can run the following steps:
```shell
just build-containerfile # This will build the containerfile and all the dependencies you need
just generate-bootable-image # Generates a bootable image for you using bootc!
```

Then you can run the `bootable.img` as your boot disk in your preferred hypervisor.
