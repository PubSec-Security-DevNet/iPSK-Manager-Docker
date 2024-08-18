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

ARG SSO_ENABLE=false
ARG MYSQL_ENABLE=true

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
    && apt-get upgrade -y \
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
        sudo \
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
    sed -i 's|ErrorLog \${APACHE_LOG_DIR}/error.log|ErrorLog /dev/stderr|' /etc/apache2/apache2.conf && \
    echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
    export SQL_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 20) && \
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
    echo "sed -i '/<input type=\"text\" my-field-state=\"required\" class=\"form-control shadow my-form-field\" id=\"dbhostname\" name=\"dbhostname\">/ s/<input /<input value=\"127.0.0.1\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sed -i '/<input type=\"text\" my-field-state=\"required\" class=\"form-control shadow my-form-field\" id=\"dbusername\" name=\"dbusername\">/ s/<input /<input value=\"ipskdbuser\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sed -i '/<input type=\"text\" my-field-state=\"required\" class=\"form-control shadow my-form-field\" id=\"iseusername\" name=\"iseusername\">/ s/<input /<input value=\"ipskiseuser\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sed -i '/<input type=\"text\" my-field-state=\"required\" class=\"form-control shadow my-form-field\" id=\"databasename\" name=\"databasename\">/ s/<input /<input value=\"ipsk\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sed -i '/<input type=\"text\" class=\"form-control shadow\" id=\"rootusername\" name=\"rootusername\">/ s/<input /<input value=\"install\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sed -i '/<input type=\"password\" my-field-state=\"required\" class=\"form-control shadow my-form-field\" id=\"rootpassword\" name=\"rootpassword\">/ s/<input /<input value=\"$SQL_PASSWORD\" readonly /' /var/www/iPSK-Manager/adminportal/installer.php" >> init.sh && \
    echo "sudo sed -i '\$a www-data ALL=(root) NOPASSWD: /removeinstalluser.sh' /etc/sudoers" >> init.sh && \
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
    unset SQL_PASSWORD && \
    touch removeinstalluser.sh && \
    chmod 744 removeinstalluser.sh && \
    echo "#!/bin/sh" >> removeinstalluser.sh && \
    echo "TEMP_FILE='/tmp/mysql-remove-install.sql'" >> removeinstalluser.sh && \
    echo "echo \"DROP USER 'install'@'%';\" >> \$TEMP_FILE" >> removeinstalluser.sh && \
    echo "echo \"FLUSH PRIVILEGES;\" >> \$TEMP_FILE" >> removeinstalluser.sh && \
    echo "/usr/bin/mysql -su root < \${TEMP_FILE}" >> removeinstalluser.sh && \
    echo "rm /tmp/mysql-remove-install.sql" >> removeinstalluser.sh && \
    echo "sed -i '/www-data ALL=(root) NOPASSWD: \/removeinstalluser.sh/d' /etc/sudoers" >> removeinstalluser.sh && \
    touch run.sh && \
    chmod 744 run.sh && \
    echo "#!/bin/sh" >> run.sh && \
    echo "if [ \"$MYSQL_ENABLE\" = true ] ; then service mysql start ; fi" >> run.sh && \
    echo "./init.sh" >> run.sh && \
    echo "sed -i '/.\/init.sh/{N;d;}' ./run.sh && rm ./init.sh && rm /tmp/mysql-start.sql" >> run.sh && \
    echo "if [ \"$SSO_ENABLE\" = true ] ; then service shibd start ; fi" >> run.sh && \
    echo "apachectl -D FOREGROUND" >> run.sh

EXPOSE 8443 443 3306

CMD ["./run.sh"]

