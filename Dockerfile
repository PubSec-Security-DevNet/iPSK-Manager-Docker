FROM ubuntu:22.04

# Copyright (c) 2024 Cisco and/or its affiliates.
#
# This software is licensed to you under the terms of the Cisco Sample
# Code License, Version 1.1 (the "License"). You may obtain a copy of the
# License at
#
#			    https://developer.cisco.com/docs/licenses
#
# All use of the material herein must be in accordance with the terms of
# the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.
#

LABEL version="0.1"
LABEL description="Containerized iPSK-Manager"
LABEL maintainer="nciesins@cisco.com"

ARG SQL_PASSWORD=Cisco1234
ARG SSO_ENABLE=false
ARG MYSQL_ENABLE=true

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade \
    && apt-get install --no-install-recommends -y \
        php \
        apache2 \
        mysql-server \
        php-mysqlnd \
        php-ldap \
        php-curl \
        php-mbstring \
        php-xml \ 
        git-all \
        libapache2-mod-shib \
    && apt-get clean \
    && apt-get purge \
    && rm -rf /var/lib/apt/lists/* \
    && a2enmod rewrite \
    && a2enmod ssl

RUN if [ "$SSO_ENABLE" = true ] ; then a2enmod shib && a2enconf shib; else a2dismod shib && a2disconf shib; fi

COPY ./apache-config/vhosts/*.conf /etc/apache2/sites-available
COPY ./apache-config/ssl/server.key ./apache-config/ssl/*.crt /etc/apache2/ssl/
COPY ./shibboleth/config/* /etc/shibboleth

RUN a2dissite 000-default && a2ensite ipsk-admin-portal && a2ensite ipsk-user-portal && a2ensite ipsk-user-portal-redirect

WORKDIR /var/www/
RUN git clone https://github.com/CiscoDevNet/iPSK-Manager.git && chown www-data:www-data -R iPSK-Manager

WORKDIR /
RUN sed -i 's/^bind-address/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf && \
    echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
    mkdir /opt/ipsk-manager && \
    chown www-data:www-data /opt/ipsk-manager && \
    touch init.sh && \
    chmod 744 init.sh && \
    echo "#!/bin/sh" >> init.sh && \
    echo "if [ ! -f \"/opt/ipsk-manager/config.php\" ] && [ \"$MYSQL_ENABLE\" = true ]; then" >> init.sh && \
    echo "TEMP_FILE='/tmp/mysql-start.sql'" >> init.sh && \
    echo "echo \"CREATE USER 'install'@'%' IDENTIFIED BY '$SQL_PASSWORD';\" >> \$TEMP_FILE" >> init.sh && \
	echo "echo \"GRANT ALL PRIVILEGES ON *.* TO 'install'@'%' WITH GRANT OPTION;\" >> \$TEMP_FILE" >> init.sh && \
	echo "echo \"FLUSH PRIVILEGES;\" >> \$TEMP_FILE" >> init.sh && \
    echo "/usr/bin/mysql -su root < \${TEMP_FILE}" >> init.sh && \
    echo "fi" >> init.sh && \
    echo "if [ -f \"/etc/shibboleth/sp-cert.pem\" ]; then" >> init.sh && \
    echo "chmod 644 /etc/shibboleth/sp-cert.pem" >> init.sh && \
    echo "chown _shibd:_shibd /etc/shibboleth/sp-cert.pem" >> init.sh && \
    echo "fi" >> init.sh && \
    echo "if [ -f \"/etc/shibboleth/sp-key.pem\" ]; then" >> init.sh && \
    echo "chmod 600 /etc/shibboleth/sp-key.pem" >> init.sh && \
    echo "chown _shibd:_shibd /etc/shibboleth/sp-key.pem" >> init.sh && \
    echo "else" >> init.sh && \
    echo "shib-keygen" >> init.sh && \
    echo "fi" >> init.sh && \
    touch removeinstalluser.sh && \
    chmod 744 removeinstalluser.sh && \
    echo "#!/bin/sh" >> removeinstalluser.sh && \
    echo "TEMP_FILE='/tmp/mysql-remove-install.sql'" >> removeinstalluser.sh && \
    echo "echo \"DROP USER 'install'@'%';\" >> \$TEMP_FILE" >> removeinstalluser.sh && \
    echo "echo \"FLUSH PRIVILEGES;\" >> \$TEMP_FILE" >> removeinstalluser.sh && \
    echo "/usr/bin/mysql -su root < \${TEMP_FILE}" >> removeinstalluser.sh && \
    echo "rm /tmp/mysql-remove-install.sql" >> removeinstalluser.sh && \
    touch run.sh && \
    chmod 744 run.sh && \
    echo "#!/bin/sh" >> run.sh && \
    echo "if [ \"$MYSQL_ENABLE\" = true ] ; then service mysql start ; fi" >> run.sh && \
    echo "if [ \"$SSO_ENABLE\" = true ] ; then service shibd start ; fi" >> run.sh && \
    echo "./init.sh" >> run.sh && \
    echo "sed -i '/.\/init.sh/{N;d;}' ./run.sh && rm ./init.sh && rm /tmp/mysql-start.sql" >> run.sh && \
    echo "apachectl -D FOREGROUND" >> run.sh

EXPOSE 8443 443 3306

CMD ["./run.sh"]

