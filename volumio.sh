#IMPORTANT! This script is only for the x-c1 on Raspberry Pi OS
#x-c1 Powering on /reboot /full shutdown through hardware
#!/bin/bash

echo '#!/bin/bash

SHUTDOWN=4
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
pigs modes ${SHUTDOWN} r
BOOT=17
pigs modes ${BOOT} w
pigs w ${BOOT} 1

echo "Your device are shutting down..."

while [ 1 ]; do
  shutdownSignal=$(pigs r ${SHUTDOWN})
  if [ ${shutdownSignal} -eq 0 ]; then
    /bin/sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ ${shutdownSignal} -eq 1 ]; do
      /bin/sleep 0.02
      if [ $(($(date +%s%N | cut -b1-13)-${pulseStart})) -gt ${REBOOTPULSEMAXIMUM} ]; then
        echo "Your device are shutting down", SHUTDOWN, ", halting Rpi ..."
        sudo poweroff
        exit
      fi
      shutdownSignal=$(pigs r ${SHUTDOWN})
    done
    if [ $(($(date +%s%N | cut -b1-13)-${pulseStart})) -gt ${REBOOTPULSEMINIMUM} ]; then
      echo "Your device are rebooting", SHUTDOWN, ", recycling Rpi ..."
      sudo reboot
      exit
    fi
  fi
done' > /etc/x-c1-pwr.sh
sudo chmod +x /etc/x-c1-pwr.sh
sudo sed -i '$ i /etc/x-c1-pwr.sh &' /etc/rc.local


#x-c1 full shutdown through Software
#!/bin/bash

echo '#!/bin/bash

BUTTON=27

pigs modes ${BUTTON} w
pigs w ${BUTTON} 1

SLEEP=${1:-4}

re='^[0-9\.]+$'
if ! [[ ${SLEEP} =~ ${re} ]] ; then
   echo "error: sleep time not a number" >&2; exit 1
fi

echo "Your device will shutting down in 4 seconds..."
/bin/sleep ${SLEEP}

pigs w ${BUTTON} 0
' > /usr/local/bin/x-c1-softsd.sh
sudo chmod +x /usr/local/bin/x-c1-softsd.sh
sudo systemctl enable pigpiod

CUR_DIR=$(pwd)
sudo sed -i "$ i echo 'volumio' | sudo -S pigpiod" /etc/rc.local
sudo sed -i "$ i python ${CUR_DIR}/fan.py &" /etc/rc.local

#sudo echo "alias xoff='sudo x-c1-softsd.sh'" >> /home/pi/.bashrc
sudo pigpiod
python ${CUR_DIR}/fan.py&

echo "The installation is complete."
echo "Please run 'sudo reboot' to reboot the device."
echo "NOTE:"
echo "1. DON'T modify the name fold: $(basename ${CUR_DIR}), or the PWM fan will not work after reboot."
echo "2. fan.py is python file to control fan speed according temperature of CPU, you can modify it according your needs."
echo "3. PWM fan needs a PWM signal to start working. If fan doesn't work in third-party OS afer reboot only remove the YELLOW wire of fan to let the fan run immediately or contact us: info@geekworm.com."
