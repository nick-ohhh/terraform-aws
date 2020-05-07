#!/bin/bash
sudo apt-get -y update
sudo apt-get -y install nginx
sudo ufw allow 'Nginx HTTP'
sudo service nginx start
sudo apt -y install awscli
#add bucket logo to nginx homepage
cd /var/www/html/
sudo aws s3 cp s3://jjbalogo/jjba_logo.jpg .
sudo sed -i '14 a <img src="jjba_logo.jpg" alt="JoJos Bizarre Adventure logo">' index.nginx-debian.html
sudo mkdir /var/log/nick
cd /etc/nginx/
sudo sed -i 's|\<access_log /var/log/nginx/access.log;\>|access_log /var/log/nick/access.log;|g' nginx.conf