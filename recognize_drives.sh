#!/bin/bash
#Autor: Atila Aloise
#e-mail: atila.aloise@tce.ro.gov.br
#
#Descrição: Este script armazena os ids dos drives do robo de tape, e do braço automatizado. Em seguida ele obtem a lista de dispositivos scsi conectados
#os paths dos devices do tipo Tape sao armazenados na variavel "get_path_drives", em seguida o script verifica se o id obtido no caminho desse path corresponde ao id do drive,
# em associa o path a veriavel do drive correspondente, podendo ser "TAPE_DRIVE_1" ou "TAPE_DRIVE_2_SITE1".
#Adicione os ids dos drives que estiver usando e ajuste os "IF´S" para que sejam comparados.
# o mesmo é feito para os braços do robô

####To do list:
#### Detectar automaticamente quantidade de braços e tapes conectados
#### Comparar automaticamente os ids com os devices conectados
#### INserir Configurações no bacula-sd.conf de acordo com os devices detectados.y


ID_DRIVE1='Your_drive_id'
ID_DRIVE2_site_1='Your_second_drive_id'
ID_ARM_1='Arm_of_tape_library'

#OBTENDO LISTA DE DRIVES DE FITA

get_path_drives=`lsscsi -g | grep tape |awk '{print $6;}'`

for tape in $get_path_drives 
	do
	id_tape=`udevadm info --query=property --name $tape | grep ID_PATH_TAG | cut -d '=' -f 2`

	if [[ "$id_tape" == *"$ID_DRIVE1"* ]]

		then 
		TAPE_DRIVE_1=$tape
	fi

	if [[ "$id_tape" = *"$ID_DRIVE2"* ]]
			
			then 
			TAPE_DRIVE_2=$tape
	
	fi

done

#OBTENDO LISTA DE BRAÇOS 
GET_path_ARM=`lsscsi -g | grep mediumx |awk '{print $7;}'`

for arm in $GET_path_ARM 
	do
	id_arm=`udevadm info --query=property --name $arm | grep ID_SCSI_SERIAL | cut -d '=' -f 2`

	if [[ "$id_arm" == *"$ID_ARM_1"* ]]

		then ARM_SITE1=$arm
	fi


done

echo "Path drive 1  = " $TAPE_DRIVE_1
echo "Path drive 2  = " $TAPE_DRIVE_2_SITE1
echo "Path TAPE ARM = " $ARM_SITE1


#Agora vamos alterar o conf do bacula-sd para que os devices correspondam ao drive correto
#Mantenha o arquivo /etc/bacula/bacula-sd.conf.template para que seja feita  manipulação das strings que apontam para as tapes e braços do robô
#o conteúdo do arquivo deve ser o seguinte:
######################################################################################
##############inicio do arquivo/etc/bacula/bacula-sd.conf.template####################
######################################################################################
# Default Bacula Storage 
#
# Autochanger {
  # Name = Autochanger
  # Device = YOUR-DRIVE-1-TAPE-DEVICE
  # Device = YOUR-DRIVE-2-TAPE-DEVICE
  # Changer Device = ARM1
  # Changer Command = "/etc/bacula/scripts/mtx-changer %c %o %S %a %d"
# #  Changer Command = /dev/null
 # # Changer Device = /dev/null
                    # # %c = changer device
                    # # %o = command (unload|load|loaded|list|slots)
                    # # %S = slot index (1-based)
                    # # %a = archive device (i.e., /dev/sd* name for tape drive)
                    # # %d = drive index (0-based)
# }
# #################### SITE 1 ########################################
# Device {
  # Name = YOUR-DRIVE-1-TAPE-DEVICE
  # Drive Index = 0
  # Media Type = LTO-5
  # Archive Device = TAPE1
  # Changer Device = ARM1
  # AutomaticMount = yes;
 # #Autoselect = yes;
  # AlwaysOpen = yes;
  # LabelMedia = yes;
  # RandomAccess = no;
  # RemovableMedia = yes;
  # Maximum Changer Wait = 300 seconds
  # Maximum Rewind Wait = 300 seconds
  # Maximum Open Wait = 300 seconds 
  # Alert Command = "sh -c 'tapeinfo -f %c |grep TapeAlert|cat'"
  # Autochanger = yes;
# } 
# #################### drive 2 ########################################
# Device {
  # Name = YOUR-DRIVE-2-TAPE-DEVICE
  # Drive Index = 1
  # Media Type = LTO-5
  # Archive Device = TAPE2
  # Changer Device = ARM1
  # AutomaticMount = yes;
  # #Autoselect = yes;
  # AlwaysOpen = yes;
  # LabelMedia = yes;
  # RandomAccess = no;
  # RemovableMedia = yes;
  # Maximum Changer Wait = 300 seconds
  # Maximum Rewind Wait = 300 seconds
  # Maximum Open Wait = 300 seconds 
  # Alert Command = "sh -c 'tapeinfo -f %c |grep TapeAlert|cat'"
  # Autochanger = yes;
# } 
# # Storage Daemon
# Storage {
  # Name = StorageDaemon
  # SDAddress = 192.168.
  # SDPort = 9103
  # WorkingDirectory = "/var/lib/bacula"
  # Pid Directory = "/var/run/bacula"
  # Maximum Concurrent Jobs = 2
# } 
# # Dados do Bacula Dir
# Director {
  # Name = srv-bkp-01-dir
  # Password = "dIRP@SSW0RD"
# }

# # Messagens
# Messages {
  # Name = Standard
  # director = srv-bkp-01-dir = all
# }

######################################################################################
##############fim do arquivo/etc/bacula/bacula-sd.conf.template####################
######################################################################################


#Aqui pegamos o arquivo template e substituimos a STRING "ARM1" pelo path do braço do robô do site 1

sed "s:ARM1:$ARM_SITE1:" /etc/bacula/bacula-sd.conf.template > /etc/bacula/bacula-sd.conf.changed

echo "Arquivo template com o braço do robô configurado!"

sed "s:TAPE1:/dev/nst${TAPE_DRIVE_1:7}:" /etc/bacula/bacula-sd.conf.changed > /etc/bacula/bacula-sd.conf.rechanged

echo "Arquivo template com o DRIVE1 do robô configurado!"

sed "s:TAPE2:/dev/nst${TAPE_DRIVE_2_SITE1:7}:" /etc/bacula/bacula-sd.conf.rechanged > /etc/bacula/bacula-sd.conf.changed

echo "Arquivo template com o DRIVE2 do robô configurado!"

echo "Ajustando conf do bacula-sd"
cat /etc/bacula/bacula-sd.conf.changed > /etc/bacula/bacula-sd.conf

echo "limpando temporarios"
rm /etc/bacula/bacula-sd.conf.*changed


echo "reiniciando bacula-sd"
service bacula-sd restart

echo "reiniciando bacula-director"
service bacula-director restart