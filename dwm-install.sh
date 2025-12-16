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

