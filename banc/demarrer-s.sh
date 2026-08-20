#!/usr/bin/bash
# Demarre le systeme installe : plus de CD, plus de -kernel, c'est le disque
# qui doit se debrouiller seul. C'est la seule chose que le jalon 2 doit prouver.
VM="/c/Users/Ghis/Desktop/S-vm"
exec "/c/Program Files/qemu/qemu-system-x86_64.exe" \
  -name "S" \
  -accel whpx,kernel-irqchip=off \
  -machine q35 \
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm \
  -smp 4 \
  -m 8192 \
  -bios "$VM/firmware/bios.fd" \
  -drive file="$VM/S.qcow2",if=virtio,format=qcow2 \
  -boot order=c \
  -serial tcp:127.0.0.1:4446,server,nowait \
  -vga std \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0 \
  -monitor tcp:127.0.0.1:4445,server,nowait
