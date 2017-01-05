# Monitorix

## Install

From command line:

`sudo yunohost app install -l Monitorix https://github.com/YunoHost-Apps/monitorix_ynh`

## Upgrade

From command line:

`sudo yunohost app upgrade -u https://github.com/YunoHost-Apps/monitorix_ynh`

## More sensor

If you want to see the temperature of some sensor you can install the `lm-sensor` packet. For disk temperature you can instal the `hddtemp` packet.

## Custom config

If you want do custom the monitorix config for more personnal information you can add a file in `/etc/monitorix/conf.d/`. This config file will be overwritte the original config in `/etc/monitorix/monitorix.conf`.