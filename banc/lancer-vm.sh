#!/usr/bin/bash
# Lance la machine virtuelle de S.
#
# Quatre reglages ne sont pas cosmetiques :
#
#   -bios firmware/bios.fd
#         WHPX ne prend PAS en charge les peripheriques mappes en lecture seule
#         (ROMD), or c'est exactement le mecanisme de « -drive if=pflash ».
#         D'ou « WHPX: Failed to emulate MMIO access » puis « Failed to exec a
#         virtual processor », des le demarrage. Le contournement documente en
#         amont est de passer le firmware par -bios, avec un fichier concatene
#         variables + code, dans cet ordre — l'image flash se lit du bas vers
#         le haut. Contrepartie : les variables UEFI ne survivent pas a un
#         redemarrage, puisque le firmware est en lecture seule.
#
#   -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm
#         Fedora 44 exige x86-64-v2, SSE 4.2 comprise. Le modele par defaut de
#         QEMU, « qemu64 », ne l'expose pas : le noyau refuserait de demarrer.
#
#   -device qemu-xhci + usb-tablet
#         La machine q35 ne cree AUCUN controleur USB par defaut : sans le xhci,
#         la tablette n'a pas de bus et QEMU refuse de demarrer. Et sans la
#         tablette, la souris est capturee et decalee — l'installateur
#         graphique devient impraticable.
#
#   -monitor tcp:...4445
#         Captures d'ecran par « screendump », et « info blockstats » pour
#         distinguer « lent » de « plante ».

VM="/c/Users/Ghis/Desktop/S-vm"
ISO="/c/Users/Ghis/Downloads/bazzite-gnome-stable-live-amd64.iso"

exec "/c/Program Files/qemu/qemu-system-x86_64.exe" \
  -name "S - jalon 2" \
  -accel whpx,kernel-irqchip=off \
  -machine q35 \
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm \
  -smp 4 \
  -m 8192 \
  -bios "$VM/firmware/bios.fd" \
  -drive file="$VM/S.qcow2",if=virtio,format=qcow2 \
  -cdrom "$ISO" \
  -boot order=dc \
  -vga std \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0 \
  -device virtio-net-pci,netdev=n0 \
  -monitor tcp:127.0.0.1:4445,server,nowait
