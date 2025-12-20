#!/bin/bash

###########################################################
# Variables (ajustar a necesidad)
###########################################################
TARGET_DISK="/dev/sda"
STAGE3="https://distfiles.gentoo.org/releases/amd64/autobuilds/20251207T170056Z/stage3-amd64-desktop-openrc-20251207T170056Z.tar.xz"

# Model(HP245): amdgpu radeonsi
# Model(Qemu):  virgl
VIRGL_DRIVER="amdgpu radeonsi"
MOUNT_POINT="/mnt/gentoo"


###########################################################
# FUNCIÓN DE INSTALACIÓN DENTRO DEL CHROOT
###########################################################
install_inside_chroot() {
    ###########################################################
    # 5. Montar el gestor de arranque y sincronización
    ###########################################################
    mkdir -p /efi
    mount /dev/sda1 /efi

    emerge-webrsync

    ###########################################################
    # 5b. ¡AQUÍ ESTÁ EL LUGAR! (Para Root)
    ###########################################################
    echo "Estableciendo la contraseña de root (¡Introduce la contraseña ahora!)"
    passwd

    ###########################################################
    # 6. Comando para binarios
    ###########################################################
    getuto


    ###########################################################
    # 7. Configurar 'flags' del cpu
    ###########################################################
    emerge --ask=n --oneshot app-portage/cpuid2cpuflags
    CPU_FLAGS=$(cpuid2cpuflags)
    echo "*/* ${CPU_FLAGS}" > /etc/portage/package.use/00cpu-flags


    ###########################################################
    # 8. Configurar video y Red (Corregido)
    ###########################################################
    echo 'VIDEO_CARDS="amdgpu radeonsi"' >> /etc/portage/make.conf
    echo '*/* video_cards_amdgpu video_cards_radeonsi' > /etc/portage/package.use/00video_cards

    # Configurar Red wlo1
    ln -s /etc/init.d/net.lo /etc/init.d/net.wlo1
    echo 'modules_wlo1="wpa_supplicant"' >> /etc/conf.d/net
    echo 'config_wlo1="dhcp"' >> /etc/conf.d/net
    echo 'associate_timeout_wlo1="60"' >> /etc/conf.d/net
    
    mkdir -p /etc/wpa_supplicant
    echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel" > /etc/wpa_supplicant/wpa_supplicant.conf
    echo "update_config=1" >> /etc/wpa_supplicant/wpa_supplicant.conf
    
    rc-update add net.wlo1 default


    ###########################################################
    # 9. Aceptar licencias
    ###########################################################
    echo "ACCEPT_LICENSE='-* @FREE @BINARY-REDISTRIBUTABLE'" >> /etc/portage/make.conf


    ###########################################################
    # 10. Configurar locales, idiomas (es_ES UTF8), teclado(es) 
    ###########################################################
    ln -sf ../usr/share/zoneinfo/America/Santiago /etc/localtime
    echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
    echo es_ES.UTF-8 UTF-8 >> /etc/locale.gen

    locale-gen

    # eselect locale set 5 (Aseguramos la selección correcta)
    ESELECT_LOCALE=$(eselect locale list | grep 'es_ES.UTF-8' | awk '{print $1}')
    if [ ! -z "$ESELECT_LOCALE" ]; then
        eselect locale set "$ESELECT_LOCALE"
    fi

    sed -i 's/^keymap=".*"$/keymap="es"/' /etc/conf.d/keymaps
    /etc/init.d/keymaps restart

    env-update && source /etc/profile && export PS1="(chroot) ${PS1}"


    ###########################################################
    # 11. Emerger el firmware
    ###########################################################
    emerge --ask=n -q sys-kernel/linux-firmware
    emerge --ask=n -q sys-firmware/sof-firmware


    ###########################################################
    # 12. Cargador del Arranque
    ###########################################################
    echo "sys-kernel/installkernel grub dracut" >> /etc/portage/package.use/installkernel


    ###########################################################
    # 13. Initramfs
    ###########################################################
    mkdir /etc/dracut.conf.d

    # Se usa /dev/sda3 ya que la variable UUID_ENCONTRADO no se exporta automáticamente
    echo 'kernel_cmdline=" root=/dev/sda3 "' >> /etc/dracut.conf.d/00-installkernel.conf

    emerge --ask=n -q sys-kernel/installkernel

    echo "sys-apps/systemd-utils boot kernel-install" >> /etc/portage/package.use/uki

    emerge --ask=n -q sys-apps/systemd-utils

    emerge --ask=n -q sys-kernel/installkernel

    #Se agrega a condición de revisar lo que ocurre con el grub
    emerge --ask=n -q dracut grub


    ###########################################################
    # 14. Núcleo (Precompilado)
    ###########################################################
    emerge --ask=n -q sys-kernel/gentoo-kernel-bin
    emerge --ask=n -q sys-kernel/gentoo-sources


    ###########################################################
    # 15. Fstab (Sincronizado con montajes)
    ###########################################################
    UUID_D1=$(blkid -o value -s UUID /dev/sda1)
    UUID_D2=$(blkid -o value -s UUID /dev/sda2)
    UUID_D3=$(blkid -o value -s UUID /dev/sda3)

    cat > /etc/fstab <<EOT
UUID=$UUID_D1   /efi        vfat    umask=0077,tz=UTC     0 2
UUID=$UUID_D2   none         swap    sw                   0 0
UUID=$UUID_D3   /            xfs    defaults,noatime      0 1
EOT

    echo gentoo > /etc/hostname

    emerge --ask=n -q net-misc/dhcpcd

    rc-update add dhcpcd default
    # rc-service dhcpcd start # Se iniciará después del reinicio


    ###########################################################
    # 16. Utilidades
    ###########################################################
    emerge --ask=n -q app-admin/sysklogd

    rc-update add sysklogd default

    emerge --ask=n -q sys-apps/mlocate

    emerge --ask=n -q app-shells/bash-completion

    emerge --ask=n -q net-misc/chrony

    rc-update add chronyd default

    emerge --ask=n -q sys-block/io-scheduler-udev-rules

    emerge --ask=n -q net-misc/dhcpcd

    emerge --ask=n -q net-wireless/wpa_supplicant

    ###########################################################
    # 16b. Configurar Red Inalámbrica (wlo1)
    ###########################################################
    ln -s /etc/init.d/net.lo /etc/init.d/net.wlo1
    echo 'modules_wlo1="wpa_supplicant"' >> /etc/conf.d/net
    echo 'config_wlo1="dhcp"' >> /etc/conf.d/net
    
    # Crear archivo config base para wpa_supplicant
    mkdir -p /etc/wpa_supplicant
    echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel" > /etc/wpa_supplicant/wpa_supplicant.conf
    echo "update_config=1" >> /etc/wpa_supplicant/wpa_supplicant.conf
    
    rc-update add net.wlo1 default

    ###########################################################
    # 17a. Configuración del arranque
    ###########################################################
    echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf

    emerge --ask=n -q sys-boot/grub:2 efibootmgr

    emerge --ask=n -q neofetch

    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Gentoo
    grub-mkconfig -o /boot/grub/grub.cfg

    # grub-install --efi-directory=/efi
    #se usa el de arriba VMWARE
    #grub-install --target=x86_64-efi --efi-directory=/efi --removable

    emerge -q sys-boot/grub sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr

    echo "GRUB_CFG=/efi/EFI/Gentoo/grub.cfg" >> /etc/env.d/99grub

    env-update

    grub-mkconfig -o /boot/grub/grub.cfg

    ###########################################################
    # 17b. Crear el usuario antes de salir
    ###########################################################

    emerge --ask=n -q app-admin/sudo

    sed -i '/^# %wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL/s/^# //' /etc/sudoers

    useradd -m -G users,wheel,audio,video,cdrom,portage -s /bin/bash tux
    passwd tux

    emerge --ask=n -q sys-kernel/linux-firmware
    
    rc-update add elogind default
    rc-service elogind start

    # El script saldrá automáticamente de esta función.
}
export -f install_inside_chroot


###########################################################
# 1. Particionado del disco (GPT recomendado para EFI)
###########################################################
dd if=/dev/zero of=${TARGET_DISK} bs=512 count=1

sfdisk ${TARGET_DISK} <<EOF
label: gpt
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
size=4G, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

D1="${TARGET_DISK}1"
D2="${TARGET_DISK}2"
D3="${TARGET_DISK}3"

mkfs.vfat -F 32 $D1
mkswap $D2
swapon $D2
mkfs.xfs -f $D3

mkdir -p $MOUNT_POINT
mount $D3 $MOUNT_POINT

# Unificamos a /efi
mkdir -p $MOUNT_POINT/efi
mount $D1 $MOUNT_POINT/efi


###########################################################
# 2. Descargar y descomprimir el Stage3
###########################################################
cd $MOUNT_POINT
wget ${STAGE3}
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C $MOUNT_POINT && \


###########################################################
# 3. Aplicar arquitectura nativa a la compilación
###########################################################
sed -i '/^COMMON_FLAGS/ s/\"/\"-march=native /' $MOUNT_POINT/etc/portage/make.conf && \


###########################################################
# 4. Ingresar el entorno enjaulado
###########################################################
cp --dereference /etc/resolv.conf $MOUNT_POINT/etc/

mount --types proc /proc $MOUNT_POINT/proc
mount --rbind /sys $MOUNT_POINT/sys
mount --make-rslave $MOUNT_POINT/sys
mount --rbind /dev $MOUNT_POINT/dev
mount --make-rslave $MOUNT_POINT/dev
mount --bind /run $MOUNT_POINT/run
mount --make-slave $MOUNT_POINT/run

# Ejecutamos la función completa dentro del chroot de forma no interactiva
chroot $MOUNT_POINT /bin/bash -c "source /etc/profile; export PS1='(chroot) ${PS1}'; declare -f install_inside_chroot > /tmp/chroot_func.sh; source /tmp/chroot_func.sh; install_inside_chroot; rm /tmp/chroot_func.sh"


###########################################################
# 17c. Finalizar (Modo simplificado)
###########################################################

cd
umount -l $MOUNT_POINT/dev{/shm,/pts,}
umount -R $MOUNT_POINT
reboot