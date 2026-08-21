#!/usr/bin/bash
# Le banc qui remplace la cle USB par un disque virtuel de la MEME TAILLE.
#
# Pourquoi : ecrire sur la vraie cle exige l'elevation (acces brut a un disque
# physique) et immobilise l'utilisateur. Un qcow2 de 61 524 148 224 octets --
# l'octet pres -- laisse passer le garde-fou de taille de poser-sur-cle.sh sans
# aucune modification : c'est donc EXACTEMENT le meme chemin de code qui est
# exerce, y compris la sonde d'ecriture et le controle de place.
#
# Meme technique que le banc VHD de PC Boost, qui avait trouve trois vrais
# defauts que la relecture n'avait pas vus.
#
# Ce que ce banc NE prouve PAS : le debit reel de la memoire flash, et le
# comportement du controleur USB. Il prouve tout le reste.
VM="/c/Users/Ghis/Desktop/S-vm"

exec "/c/Program Files/qemu/qemu-system-x86_64.exe" \
  -name "S - banc cle virtuelle" \
  -accel whpx,kernel-irqchip=off \
  -machine q35 \
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm \
  -smp 4 \
  -m 8192 \
  -bios "$VM/firmware/bios.fd" \
  -drive file="$VM/S.qcow2",if=virtio,format=qcow2 \
  -drive file="$VM/cle-virtuelle.qcow2",if=virtio,format=qcow2 \
  -boot order=c \
  -serial tcp:127.0.0.1:4446,server,nowait \
  -vga std \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0 \
  -monitor tcp:127.0.0.1:4445,server,nowait
