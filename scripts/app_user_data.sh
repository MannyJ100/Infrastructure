#!/bin/bash

cd /home/ubuntu/app
export DB_HOST=mongodb://${db_ip}:27017
node app.js