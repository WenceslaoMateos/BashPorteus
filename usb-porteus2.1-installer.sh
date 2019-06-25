#!/bin/bash

#----------------------------------------------------------------------#
#                        SCRIPT DE BASH
#                  INSTALACION DE PORTEUS EN USB   

# Version: 0.8

# UNMDP - Facultad de Ingenieria
# Catedra: Analisis Numerico Para Ingenieria

# Autores: Belcic Martin, Mateos Wenceslao, Vilchez Sol

# 2019
#----------------------------------------------------------------------#

# Si no se tienen permisos root se cierra el programa
# el -ne significa not equal
if [ "$(id -u)" -ne 0 ]; then
	#los numeros es para ponerle formato a las letras
	echo -e "\\033[0;31mERROR: Se debe ejecutar como ROOT\\033[0m"
	exit 1
fi

echo "Adquiriendo dispositivos..."
# Busca todos los dispositivos usb
devs=$(find /dev/disk/by-path | grep -- '-usb-' | grep -v -- '-part[0-9]*$' || true)
# Si no hay ningun usb se espera que se ingrese uno.
# el -z compara si la longitud de "$devs" es cero
opcion="1"
while [ -z "$devs" ] && [ $opcion -ne "0" ]; do
	echo -e "\\033[0;31mERROR: no se encontro ningun USB\\033[0m"
	echo -e "Inserte dispositivo USB."
	echo -e "0 - Cancelar"
	echo -e "Cualquier tecla para volver a comprobar"
	read opcion
	devs=$(find /dev/disk/by-path | grep -- '-usb-' | grep -v -- '-part[0-9]*$' || true)
done

if [ $opcion -eq "0" ]; then
	exit 2
fi

devs="$(readlink -f $devs)"
echo "Seleccione un dispositivo."
count=-1
for x in $devs; do
	count=$(($count+1))
	model="$(lsblk -ndo model "$x")"
	echo "$count - $x $model"
	vec[$count]="$x"
done
read opcion2

band="1"
if ! [[ $opcion2 =~ '[^0-9]+' ]]; then
	band="0"
fi
while [ $band -ne "0" ] || [ $opcion2 -gt $count ] || [ $opcion2 -lt "0" ]; do
	echo "Seleccione un numero de dispositivo valido"
	read opcion2
	if ! [[ $opcion2 =~ '[^0-9]+' ]]; then
		band="0"
	else
		band="1"
	fi
done
device=${vec["$(($opcion2))"]}
unset devs
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

# setea las variables correspondientes a ambas particiones.
par1="$device"1
par2="$device"2

echo -e "\\033[1;33mFormateando particiones...\\033[0m"
cat << EOF | mkfs.ext4 $par2
s
EOF
mkfs.vfat -F 32 $par1

echo -e "\\033[1;33mDesmontando particiones...\\033[0m"
# se ubica en directorio anterior y desmonta particiones
umount /mnt/usbExt
umount /mnt/iso
umount /mnt/usbFat

echo -e "\\033[1;33mBorrando carpetas viejas...\\033[0m"
# borra carpetas creadas previamente
rm -rf /mnt/usbExt
rm -rf /mnt/iso
rm -rf /mnt/usbFat

echo -e "\\033[1;33mCreando directorios...\\033[0m"

# crea directorio para montar la particion FAT32
mkdir /mnt/usbFat
# crea directorio para montar la particion EXT4
mkdir /mnt/usbExt
# crea directorio para montar la imagen ISO
mkdir /mnt/iso

echo -e "\\033[1;33mMontando archivos y particiones...\\033[0m"

# monta imagen ISO
mount -o loop ./AN_PORTEUS2.1_x86_64.iso /mnt/iso
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
# se ubica en directorio HOME y desmonta particiones
cd $HOME
umount /mnt/usbExt
umount /mnt/iso
umount /mnt/usbFat

echo -e "\\033[1;33mBorrando carpetas viejas...\\033[0m"
# borra carpetas creadas previamente
rm -rf /mnt/usbFat
rm -rf /mnt/usbExt
rm -rf /mnt/iso

echo -e "\\033[0;32mInstalacion finalizada.\\033[0m"