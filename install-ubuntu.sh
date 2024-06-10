#IMPORTANT! This script is only for the x-c1
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
#sudo sed -i '$ i /etc/x-c1-pwr.sh &' ${AUTO_RUN}

#x-c1 full shutdown through shell
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

# create pigpiog service - begin
SERVICE_NAME="/lib/systemd/system/pigpiod.service"
# Create service file on system.
if [ -e ${SERVICE_NAME} ]; then
	sudo rm ${SERVICE_NAME} -f
fi

sudo echo '[Unit]
Description=Daemon required to control GPIO pins via pigpio
[Service]
ExecStart=/usr/local/bin/pigpiod
ExecStop=/bin/systemctl kill pigpiod
Type=forking
[Install]
WantedBy=multi-user.target
' >> ${SERVICE_NAME}

# create pigpiog service - begin
sudo systemctl enable pigpiod

CUR_DIR=$(pwd)

#####################################
echo "#!/bin/bash
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Print the IP address
_IP=$(hostname -I) || true
if [ "${_IP}" ]; then
  printf "My IP address is %s\n" "${_IP}"
fi

/etc/x-c1-pwr.sh &
python3 ${CUR_DIR}/fan.py &
exit 0
" > /etc/rc.local
sudo chmod +x /etc/rc.local

#得到上一级目录
#dname=$(dirname ${CUR_DIR})
#echo "alias xoff='sudo /usr/local/bin/x-c1-softsd.sh'" >> ${dname}/.bashrc

sudo pigpiod
python3 ${CUR_DIR}/fan.py&

echo "The installation is complete."
echo "Please run 'sudo reboot' to reboot the device."
echo "NOTE:"
echo "1. DON'T modify the name fold: $(basename ${CUR_DIR}), or the PWM fan will not work after reboot."
echo "2. fan.py is python file to control fan speed according temperature of CPU, you can modify it according your needs.The fan.py file uses the third-party pigpiod library, and fan-rpi.py only uses the gpio library of the Raspberry Pi. We will gradually abandon the use of the third-party pigpiod library"
echo "3. PWM fan needs a PWM signal to start working. If fan doesn't work in third-party OS afer reboot only remove the FAN HS jumper of x-c1 shield to let the fan run immediately or contact us: info@geekworm.com."
