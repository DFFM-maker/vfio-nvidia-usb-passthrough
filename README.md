# kvm-vfio-nvidia-usb

Guida, script e configurazioni per abilitare KVM/QEMU con VFIO passthrough per GPU NVIDIA e dispositivi USB.  
Obiettivo: fornire istruzioni passo‑passo, script di diagnostica e esempi per creare macchine virtuali con passthrough GPU (NVIDIA) e passthrough dispositivi USB.

## Contenuti
- docs/: guide dettagliate (BIOS/GRUB/IOMMU/modprobe)
- scripts/: utility per diagnostica, bind/unbind VFIO, export config
- examples/: file libvirt / virt-manager / OVMF examples
- troubleshooting.md: problemi comuni e soluzioni (blacklist driver, iommu groups, VFIO bind)

## Priorità e scopo
Questo progetto copre:
- Abilitazione IOMMU su host (Intel/AMD)
- Identificazione e isolamento della GPU NVIDIA (vendor:device)
- Binding GPU e dispositivi USB a vfio-pci
- Configurazione GRUB e modprobe per il boot
- Creazione VM con OVMF (UEFI) e passaggio della GPU + USB controller
- Script di diagnostica e recovery (per ripristinare host GPU)

Non è lo scopo:
- Script per aggirare restrizioni o DRM specifici delle GPU proprietarie
- Supporto per moduli proprietari non compatibili con passthrough senza riavvio

## Quick start (sintesi)
1. Leggi `docs/overview.md`.
2. Esegui `scripts/check-iommu.sh` per verificare IOMMU e gruppi.
3. Identifica device IDs: `lspci -nnk | grep -i vga -A3`.
4. Aggiungi kernel param (GRUB) `intel_iommu=on iommu=pt` o `amd_iommu=on iommu=pt`.
5. Configura `/etc/modprobe.d/vfio.conf` con i vendor:device da isolare.
6. Riavvia e verifica con `scripts/check-iommu.sh`.
7. Crea VM con virt-manager usando OVMF e mappa GPU + USB controller.

## License
MIT — vedi LICENSE

## Contribuire
Apri issue o PR per miglioramenti, bugfix e nuove guide di hardware specifico (es. passare GPU integrata vs discreta).
