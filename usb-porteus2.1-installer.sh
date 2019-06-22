#!/bin/bash

# 1. Si al momento de su ejecución, el usuario no esta en /home/user, elimina el sistema de boteo
#   actual.

# 2. Al utilizarlo en una PC con una configuración de mas de un HDD, el mismo tiende a fallar.

# 3. Si el usuario al ejecutar el instalador por algun motivo interrumpe el programa, el mismo al volver 
#   a ser ejecutado no funciona.


# Luego de la primera prueba, en las dos condiciones de error pasadas, el equipo funciona correctamente
# pero el usb no es reconocido por mi computadora, y en la de martin tira un error

# Volvimos a probarlo pero esta vez ejecutamos todo desde el home, anduvo perfectamente con la salvedad
# de que no anda la persistencia.

#----------------------------------------------------------------------#
#                        SCRIPT DE BASH
#                  INSTALACION DE PORTEUS EN USB   

# Version: 0.7

# UNMDP - Facultad de Ingenieria
# Catedra: Analisis Numerico Para Ingenieria

# Autores: Belcic Martin, Mateos Wenceslao, Vilchez Sol

# 2018
#----------------------------------------------------------------------#

# si no esta instalado, descarga e instala Dialog
apt install dialog -y

# Si no se tienen permisos root se cierra el programa
# el -ne significa not equal
if [ "$(id -u)" -ne 0 ]; then
	#los numeritos es para ponerle colorcito
	echo -e "\\033[0;31mERROR: Se debe ejecutar como ROOT\\033[0m"
	exit 1
fi

# Si no se tienen permisos root se cierra el programa  
echo "Adquiriendo dispositivos..."
# Busca todos los dispositivos usb
devs="$(find /dev/disk/by-path | grep -- '-usb-' | grep -v -- '-part[0-9]*$' || true)"
# Si no hay ningun usb se cierra el programa
# el -z compara si la longitud de "$devs" es cero
if [ -z "$devs" ]; then
	echo -e "\\033[0;31mERROR: no se encontro ningun USB\\033[0m"
	exit 2
fi
# "Normalizo" directorio 
# readlink da el path posta desde la raiz hasta ese dispisitivo
devs="$(readlink -f $devs)"

dialogdevs=""
dialogmodel=""
# Establezco valores de variables
for dialogdev in $devs; do
	dialogmodel="$(lsblk -ndo model "$dialogdev")"
	dialogdevs="$dialogdevs $dialogdev '$dialogmodel' off"
done
unset dialogdev
unset dialogmodel
# Menu para elegir usb con dialog
# el -z compara si la longitud de "$device" es cero
while [ -z "$device" ]; do
	device="$(eval "dialog --stdout --radiolist 'Seleccionar usb' 12 40 5 $dialogdevs")"
	#si el dialog anterior por algun motivo falla (osea, devuelve 0 el dialog), termina el script
	if [ "$?" -ne "0" ]; then
		exit
	fi
done
unset dialogdevs
unset devs

# desmonta particiones que tenga el usb originalmente

# Las particiones que figuran en /proc/mounts se buscan y se guardan en un arreglo
mapfile -t devicePartitions < <(grep -oP "^\\K$device\\S*" /proc/mounts)

echo -e "\\033[1;33mParticiones a desmontar:\\033[0m"

# Se desmontan todas las particiones guardadas en el arreglo anterior
for partition in "${devicePartitions[@]}"; do
	echo $partition
	if ! umount "$partition" >/dev/null; then
		echo -e "\\033[0;31mError al desmontar $partition. La particion esta en uso.\\033[0m"
		exit
	fi
	echo -e "\\033[0;32mParticion $partition desmontada correctamente\\033[0m"
done

# borra particiones originales y crea nuevas con fdisk, mediante un piping
# NO BORRAR los espacios dentro de EOF, son necesarios para las opciones
# por defecto. NO COMENTAR dentro del piping

# crea primero una tabla de particiones DOS, luego una particion FAT de 120 Mb
# y luego una EXT4 con el espacio restante

echo -e "\\033[1;33mCreando Particiones...\\033[0m"
cat << EOF2 | fdisk $device
o
n
p
1

+120M
n
p
2


w
EOF2

# actualiza tabla de particiones del sistema
partprobe

# formatea ambas particiones, en el FileSystem correspondiente
par1="$device"1
par2="$device"2

echo -e "\\033[1;33mFormateando particiones...\\033[0m"
cat << EOF | mkfs.ext4 $par2
s
EOF
mkfs.vfat -F 32 $par1

echo -e "\\033[1;33mCreando directorios...\\033[0m"

# crea directorio para montar la particion FAT32
mkdir /mnt/usbFat
# crea directorio para montar la particion EXT4
mkdir /mnt/usbExt
# crea directorio para montar la imagen ISO
mkdir /mnt/iso

echo -e "\\033[1;33mMontando archivos y particiones...\\033[0m"

# monta imagen ISO
#aca podriamos agregar un wget para descargar la iso y no tener que andar paseandola
mount -o loop AN_PORTEUS2.1_x86_64.iso /mnt/iso
# monta particion FAT32 
mount $par1 /mnt/usbFat
# montar particion EXT4 
mount $par2 /mnt/usbExt

echo -e "\\033[1;33mCopiando carpetas a particiones...\\033[0m"
# copia carpetas boot y EFI en partición FAT32
cp -a /mnt/iso/boot /mnt/usbFat
cp -a /mnt/iso/EFI /mnt/usbFat
# copia carpeta porteus en partición EXT4
cp -a /mnt/iso/porteus /mnt/usbExt

echo -e "\\033[1;33mEjecutando script Porteus-Installer...\\033[0m"
# se ubica en directorio /mnt/usbFat/boot
cd /mnt/usbFat/boot
# ejecuta el programa que hace booteable el USB
cat << EOF2 | bash Porteus-installer-for-Linux.com
ok
EOF2

echo -e "\\033[1;33mDesmontando particiones...\\033[0m"
# se ubica en directorio anteriro y desmonta particiones
cd $OLDPWD
umount /mnt/usbExt
umount /mnt/iso
umount /mnt/usbFat

echo -e "\\033[1;33mBorrando carpetas viejas...\\033[0m"
# borra carpetas creadas previamente
rm -rf /mnt/usbFat
rm -rf /mnt/usbExt
rm -rf /mnt/iso

echo -e "\\033[0;32mInstalacion finalizada.\\033[0m"
