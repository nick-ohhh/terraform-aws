#!/bin/bash
sudo apt-get -y update
sudo apt-get -y install nginx
sudo ufw allow 'Nginx HTTP'
sudo service nginx start
