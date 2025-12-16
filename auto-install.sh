#!/bin/bash

###########################################################
# Variables (ajustar a necesidad)
###########################################################
TARGET_DISK="/dev/sda"
STAGE3="https://distfiles.gentoo.org/releases/amd64/autobuilds/20251207T170056Z/stage3-amd64-desktop-openrc-20251207T170056Z.tar.xz"

# Model(HP245): amdgpu radeonsi
# Model(Qemu):  virgl
VIRGL_DRIVER="virgl"
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
    # 8. Configurar video
    ###########################################################
    echo '*/* VIDEO_CARDS: ${VIRGL_DRIVER}' >> /etc/portage/package.use/00video_cards


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
    # 15. Fstab
    ###########################################################
    UUID_D1=$(blkid -o value -s UUID /dev/sda1)
    UUID_D2=$(blkid -o value -s UUID /dev/sda2)
    UUID_D3=$(blkid -o value -s UUID /dev/sda3)

    cat > /etc/fstab <<EOT
UUID=$UUID_D1   /efi        vfat    umask=0077,tz=UTC     0 2
UUID=$UUID_D2   none         swap    sw                   0 0
UUID=$UUID_D3   /            xfs    defaults,noatime              0 1
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


    ###########################################################
    # 17a. Configuración del arranque
    ###########################################################
    echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf

    emerge --ask=n -q sys-boot/grub efibootmgr neofetch

    grub-install --efi-directory=/efi
    #se usa el de arriba VMWARE
    #grub-install --target=x86_64-efi --efi-directory=/efi --removable

    emerge -q sys-boot/grub sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr

    echo "GRUB_CFG=/efi/EFI/Gentoo/grub.cfg" >> /etc/env.d/99grub

    env-update

    grub-mkconfig -o /boot/grub/grub.cfg

    ###########################################################
    # 17b. Crear el usuario antes de salir
    ###########################################################

    useradd -m -G users,wheel,audio,video,cdrom,portage -s /bin/bash tux
    passwd tux


    ###########################################################
    # Configuraciones finales (añadidas)
    ###########################################################
    emerge --ask=n -q app-admin/sudo

    sed -i '/^# %wheel[[:space:]]\+ALL=(ALL)[[:space:]]\+ALL/s/^# //' /etc/sudoers

    sudo emerge --ask=n -q sys-kernel/linux-firmware

    sudo rc-update add elogind default
    sudo rc-service elogind start

    # El script saldrá automáticamente de esta función.
}
export -f install_inside_chroot


###########################################################
# 1. Particionado del disco
###########################################################
dd if=/dev/zero of=${TARGET_DISK} bs=512 count=1

sfdisk ${TARGET_DISK} <<EOF
label: dos
size=1G, type=83, bootable
size=4G, type=82
type=83

EOF

D1="${TARGET_DISK}1"
D2="${TARGET_DISK}2"
D3="${TARGET_DISK}3"

mkfs.vfat -F 32 $D1
mkswap $D2
swapon $D2
mkfs.xfs $D3

mkdir -p $MOUNT_POINT
mount $D3 $MOUNT_POINT

mkdir -p $MOUNT_POINT/boot
mount $D1 $MOUNT_POINT/boot


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