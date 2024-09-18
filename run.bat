@echo off
docker run -v ${pwd}:/home/cse160 -ti ucmercedandeslab/tinyos_debian
:: docker run --rm -v /:/app -w /app ucmercedandeslab/tinyos_debian:latest sh -c "make micaz sim"   $:: don't use this line