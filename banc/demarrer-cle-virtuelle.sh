#!/usr/bin/bash
# Demarre la cle virtuelle SEULE, en UEFI, comme le fera la M720q par F12.
#
# Aucun autre disque n'est attache : si ca demarre, c'est que la cle se suffit
# a elle-meme -- ESP, chargeur, noyau et racine. C'est la seule chose que ce
# banc doit prouver.
#
# Ce qu'il ne prouve PAS : le materiel reel. Un firmware virtuel qui trouve la
# cle ne dit rien du controleur USB de la machine ni de son iGPU.
VM="/c/Users/Ghis/Desktop/S-vm"

exec "/c/Program Files/qemu/qemu-system-x86_64.exe" \
  -name "S - demarrage depuis la cle virtuelle" \
  -accel whpx,kernel-irqchip=off \
  -machine q35 \
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm \
  -smp 4 \
  -m 6144 \
  -bios "$VM/firmware/bios.fd" \
  -drive file="$VM/cle-virtuelle.qcow2",if=virtio,format=qcow2 \
  -boot order=c \
  -serial tcp:127.0.0.1:4448,server,nowait \
  -vga std \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2223-:22 \
  -device virtio-net-pci,netdev=n0 \
  -monitor tcp:127.0.0.1:4447,server,nowait
