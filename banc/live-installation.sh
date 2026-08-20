#!/usr/bin/bash
# Session live avec DEUX disques :
#   vda  la cible de l'installation
#   vdb  un disque de travail pour /var/lib/containers — sans lui, podman
#        devrait stocker l'image dans la surcouche en RAM de la session live,
#        ou 15 Go decompresses ne tiennent pas.
#
# Le branchement a chaud n'etait pas possible : le bus pcie.0 de q35 ne le
# supporte pas. D'ou ce redemarrage.

VM="/c/Users/Ghis/Desktop/S-vm"
ISO="/c/Users/Ghis/Downloads/bazzite-gnome-stable-live-amd64.iso"

exec "/c/Program Files/qemu/qemu-system-x86_64.exe" \
  -name "S - installation bootc" \
  -accel whpx,kernel-irqchip=off \
  -machine q35 \
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm \
  -smp 4 \
  -m 8192 \
  -bios "$VM/firmware/bios.fd" \
  -drive file="$VM/S.qcow2",if=virtio,format=qcow2 \
  -drive file="$VM/scratch.qcow2",if=virtio,format=qcow2 \
  -cdrom "$ISO" \
  -kernel "$VM/boot/vmlinuz" \
  -initrd "$VM/boot/initrd.img" \
  -append "root=live:CDLABEL=Bazzite-Live rd.live.image enforcing=0 console=tty0 console=ttyS0,115200" \
  -serial tcp:127.0.0.1:4446,server,nowait \
  -vga std \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0 \
  -monitor tcp:127.0.0.1:4445,server,nowait
