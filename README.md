Monitorix
=========

A light monitoring tools.

[![Integration level](https://dash.yunohost.org/integration/monitorix.svg)](https://ci-apps.yunohost.org/jenkins/job/monitorix%20%28Community%29/lastBuild/consoleFull) 

[![Install Monitorix with YunoHost](https://install-app.yunohost.org/install-with-yunohost.png)](https://install-app.yunohost.org/?app=monitorix)

Install
-------

From command line:

`sudo yunohost app install -l Monitorix https://github.com/YunoHost-Apps/monitorix_ynh`

Upgrade
-------

From command line:

`sudo yunohost app upgrade -u https://github.com/YunoHost-Apps/monitorix_ynh`

More sensor
-----------

If you want to see the temperature of some sensor you can install the `lm-sensor` packet. For disk temperature you can instal the `hddtemp` packet.

Custom config
-------------

If you want do custom the monitorix config for more personnal information you can add a file in `/etc/monitorix/conf.d/`. This config file will be overwritte the original config in `/etc/monitorix/monitorix.conf`.

License
-------

Monitorix is published under the GNU General Public License v2.0 License : http://www.monitorix.org/license.html
