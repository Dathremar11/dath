#!/bin/bash -e
export ANSIBLE_LOG_PATH=/var/log/install_szabbix/install_$(date "+%Y-%m-%d_%H-%M-%S").log
result=$(dirname "$ANSIBLE_LOG_PATH")
mkdir -p $result

apt update
apt install curl -y
#установка забикса
apt install zabbix-server-pgsql zabbix-frontend-php zabbix-agent -y

#установка apache2
apt install apache2 libapache2-mod-php -y

#установка postgresql
apt install postgresql php-pgsql -y
#echo postgres installed 

#мандатный доступ
#pdpl-user -l 0:0 -i 63 postgres
#pdpl-user -l 0:0 zabbix
#setfacl -d -m u:postgres:r /etc/parsec/{macdb,capdb}
#setfacl -R -m u:postgres:r /etc/parsec/{macdb,capdb}
#setfacl -m u:postgres:rx /etc/parsec/{macdb,capdb}

#настройка линукс парсека
#/etc/parsec/mswitch.conf
if grep -Fq "zero_if_notfound: yes" /etc/parsec/mswitch.conf;
then
  echo "zero if not found is set to yes"
  else
    echo "zero if not found is set to no, will change to yes now"
      sed -i "/zero_if_notfound:/c\zero_if_notfound: yes" /etc/parsec/mswitch.conf
      fi

      #настройка apache
      #/etc/php/*/apache2/php.ini
      if grep -Fq "date.timezone = Europe/Moscow" /etc/php/*/apache2/php.ini;
      then
        echo "apache timezone is set to Europe/Moscow"
        else
          echo "apache timezone is not set to Europe/Moscow, will fix now"
            sed -i "/;date.timezone =/c\date.timezone = Europe/Moscow" /etc/php/*/apache2/php.ini
            fi
            #/etc/apache2/apache2.conf
            if grep -Fq "AstraMode off" /etc/apache2/apache2.conf;
            then
              echo "AstraMode is set to off"
              else
                echo "AstraMode is set to on, will change to off now"
                  sed -i "/AstraMode on/c\AstraMode off" /etc/apache2/apache2.conf
                  fi


                  #изменение хостов
                  #/etc/hosts
                  #уточнить ip адрес машины
                  #if grep -Fq 192.168.56.101 /etc/hosts;
                  #then echo "домен уже добавлен"
                  #else 
                  #  echo "домена нет, добавляю домен"
                  #  sed  -i "/127.0.0.1 /a192.168.32.101 arm1" /etc/hosts
                  #
                  #if grep -q "#127.0.1.1" /etc/hosts; then
                  #    echo "127.0.1.1 is #127.0.1.1"
                  #else
                  #    echo "commenting 127.0.1.1"
                  #    sed -i 's/127\.0\.1\.1/#127.0.1.1/' /etc/hosts
                  #fi


                  systemctl reload apache2
                  #настройка postgreSQL
                  #/etc/postgresql/*/main/pg_hba.conf
                  echo postgres config check
                  #проверка хостов
                  echo -e "Looking for string: \033[0;33m host   zabbix        zabbix              127.0.0.1/32           trust \033[0m"
                  if grep -Fq "host   zabbix        zabbix              127.0.0.1/32           trust" /etc/postgresql/*/main/pg_hba.conf; then
                    echo -e "\033[0;32m Zabbix host has already been added \033[0m"
                    else
                      echo -e "\033[0;31m No zabbix host, will add now \033[0m"
                        sed -i '/#host    all             all             127.0.0.1\/32            md5/a host   zabbix        zabbix              127.0.0.1\/32           trust' /etc/postgresql/*/main/pg_hba.conf
                        fi
                        #проверка бд
                        echo -e 'looking for string: \033[0;33m local  zabbix        zabbix                                     trust'
                        if grep -Fq "local  zabbix        zabbix                                     trust" /etc/postgresql/*/main/pg_hba.conf; then
                          echo -e '\033[0;32m Zabbix database has already been added \033[0m'
                          else
                            echo -e '\033[0;31m No zabbix database, will add now \033[0m'
                              sed -i '/# TYPE  DATABASE        USER            ADDRESS                 METHOD/a local  zabbix        zabbix                                     trust' /etc/postgresql/*/main/pg_hba.conf
                              fi

                              systemctl restart postgresql

                              cd /opt

                              echo "creating zabbix db and user and granting acces"
                              echo "CREATE DATABASE ZABBIX;" |sudo -u postgres psql
                              echo "CREATE USER zabbix WITH PASSWORD '12345678';" | sudo -u postgres psql
                              echo "GRANT ALL ON DATABASE zabbix to zabbix;" | sudo -u postgres psql
                              echo "ALTER DATABASE zabbix OWNER TO zabbix;" | sudo -u postgres psql

                              #настройка zabbix /// для 3.* верссии /usr/share/doc/zabbix-server-pgsql/create.sql
                              zcat /usr/share/zabbix-server-pgsql/{schema,images}.sql.gz | psql -h localhost zabbix zabbix
                              #включение php модуля zabbix сервера в web-сервере Apache
                              a2enconf zabbix-frontend-php
                              systemctl reload apache2
                              #копирование файла примерных настроек zabbix-сервера в файл первоначальных настроек.
                              cp /usr/share/zabbix/conf/zabbix.conf.php.example /etc/zabbix/zabbix.conf.php
                              #установить права доступа к созданному файлу
                              chown www-data:www-data /etc/zabbix/zabbix.conf.php

                              file=/etc/zabbix/zabbix.conf.php
                              if ! grep -q "\$DB\['TYPE'\]\s*=\s*'POSTGRESQL'" "$file" || \
                                 ! grep -q "\$DB\['PASSWORD'\]\s*=\s*'12345678'" "$file" || \
                                    ! grep -q "\$DB\['USER'\]\s*=\s*'zabbix'" "$file"; then

                                        sed -i "s/\(\$DB\['TYPE'\]\s*=\s*'\).*\('.*\)/\1POSTGRESQL\2/" "$file"
                                            sed -i "s/\(\$DB\['PASSWORD'\]\s*=\s*'\).*\('.*\)/\112345678\2/" "$file"
                                                sed -i "s/\(\$DB\['USER'\]\s*=\s*'\).*\('.*\)/\1zabbix\2/" "$file"

                                                    echo "Configuration updated successfully."
                                                    else
                                                        echo "No changes needed; the configuration is already set."
                                                        fi


                                                        file="/etc/zabbix/zabbix_server.conf"

                                                        if ! grep -q "^DBPassword=12345678" "$file"; then

                                                            # Uncomment the line if it starts with a #
                                                                sed -i "s/^#\s*DBPassword=\(.*\)/DBPassword=\1/" "$file"

                                                                    # Use sed to replace the line with DBPassword=12345678
                                                                        sed -i "s/^DBPassword=\(.*\)/DBPassword=12345678/" "$file"

                                                                            echo "DBPassword updated successfully."
                                                                            else
                                                                                echo "No changes needed; the DBPassword is already set."
                                                                                fi

                                                                                systemctl reload psql
                                                                                systemctl reload apache2
                                                                                systemctl reload zabbix-server