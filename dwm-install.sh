#########################################
# Instalación de 'dwm'
#########################################

#########################################
# (1) Listar 'info'
#########################################
emerge --info | grep ^USE


#########################################
# (2) Editar el make.conf (y quitar esc.)
#########################################
echo "USE='-gnome -kde -bluetooth -cups -dvd -dvdr -cdr'" >> /etc/portage/make.conf

#########################################
# (3) Instalar un binario de 'rust'
#########################################
emerge --ask=n -q rust-bin

#########################################
# (4) actualizar e instalar herramientas para nuevo uso 
#########################################
emerge --deep --newuse --update -q @world xorg-server dwm elogind network-manager dbus

