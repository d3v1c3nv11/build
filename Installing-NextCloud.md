**Installing NextCloud**

Download [Armbian_5.92.4_Olinuxino-a20_Ubuntu_bionic_next_5.2.21_desktop.7z](ftp://staging.olimex.com/Allwinner_Images/A20-OLinuXino/1.latest_mainline_images/bionic/images/Armbian_5.92.4_Olinuxino-a20_Ubuntu_bionic_next_5.2.21_desktop.7z) and write it with **Image Writer** to blank micro-SD card.

Use ethernet cable to connect to Internet.

Use USB cable to connect PC to USB-OTG connector on the server.

Insert the card and boot.

Wait 30 seconds and check which serial port is created last with:

`dmesg | grep ttyACM`

Now connect to server via serial port:

`cu -l /dev/ttyACM0`

Initial login is **root 1234** after which you will be forced to change your password.

Get the install script from our ftp with:

```
wget ftp://staging.olimex.com/Allwinner_Images/A20-OLinuXino/5.NextCloud/install_NextCloud.sh
```

make script executable:

```
chmod +x install_NextCloud.sh
```

then run the script:

```
./install_NextCloud.sh 
```

at the end the script will run NextCloud server and will display the IP of the server. The first initialization is slow - it might take up to 5 minutes, so you have to patiently wait untill login page appear.

