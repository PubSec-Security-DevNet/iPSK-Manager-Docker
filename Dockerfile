FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV IPSK_SQL_INSTALLER_PASSWORD=Cisco1234

ENV SSO=false

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
    && apt-get clean \
    && apt-get purge \
    && rm -rf /var/lib/apt/lists/* \
    && a2enmod rewrite \
    && a2enmod ssl

RUN if [ "$SSO" = true ] ; then apt-get install --no-install-recommends -y libapache2-mod-shib && a2enmod shib ; fi

COPY ./apache-config/vhosts/*.conf /etc/apache2/sites-available
COPY ./apache-config/ssl/server.key ./apache-config/ssl/*.crt /etc/apache2/ssl/

RUN a2dissite 000-default && a2ensite ipsk-admin-portal && a2ensite ipsk-user-portal

WORKDIR /var/www/
RUN git clone -b installer-updating-flow-and-docker https://github.com/CiscoDevNet/iPSK-Manager.git && chown www-data:www-data -R iPSK-Manager

#WORKDIR /opt/ipskmgr
#CMD ["/sbin/apache2ctl", "-D", "FOREGROUND"]
WORKDIR /
RUN sed -i 's/^bind-address/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf && \
    echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
    mkdir /opt/ipsk-manager && \
    chown www-data:www-data /opt/ipsk-manager && \
    touch init.sh && \
    chmod 744 init.sh && \
    echo "#!/bin/sh" >> init.sh && \
    echo "if [ ! -f "/opt/ipsk-manager/config.php" ]; then" >> init.sh && \
    echo "TEMP_FILE='/tmp/mysql-start.sql'" >> init.sh && \
    echo "echo \"CREATE USER 'install'@'%' IDENTIFIED BY '\$IPSK_SQL_INSTALLER_PASSWORD';\" >> \$TEMP_FILE" >> init.sh && \
	echo "echo \"GRANT ALL PRIVILEGES ON *.* TO 'install'@'%' WITH GRANT OPTION;\" >> \$TEMP_FILE" >> init.sh && \
	echo "echo \"FLUSH PRIVILEGES;\" >> \$TEMP_FILE" >> init.sh && \
    echo "/usr/bin/mysql -su root < \${TEMP_FILE}" >> init.sh && \
    echo "fi" >> init.sh && \
    touch run.sh && \
    chmod 744 run.sh && \
    echo "#!/bin/sh" >> run.sh && \
    echo "service mysql start" >> run.sh && \
    echo "./init.sh" >> run.sh && \
    echo "sed -i '/.\/init.sh/{N;d;}' ./run.sh && rm ./init.sh && rm /tmp/mysql-start.sql" >> run.sh && \
    echo "apachectl -D FOREGROUND" >> run.sh



EXPOSE 8443 443 3306

CMD ["./run.sh"]

