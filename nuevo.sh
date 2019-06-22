#!/bin/bash

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
devs=$(find /dev/disk/by-path | grep -- '-usb-' | grep -v -- '-part[0-9]*$' || true)
# Si no hay ningun usb se cierra el programa
# el -z compara si la longitud de "$devs" es cero
opcion="1"
while [ -z "$devs" ] && [ $opcion -ne "0" ]; do
	echo -e "\\033[0;31mERROR: no se encontro ningun USB\\033[0m"
	echo -e "Inserte dispositivo USB."
	echo -e "0 - Cancelar"
	read opcion
done

if [ $opcion -eq "0" ]; then
	exit 2
fi

devs="$(readlink -f $devs)"
echo "Seleccione un dispositivo."
count=0
for x in $devs; do
	model="$(lsblk -ndo model "$x")"
	echo "$count - $x $model"
	vec[$count]="$x"
	count=$(($count+1))
done
read opcion2
dev=${vec["$(($opcion2))"]}

echo $dev
