FROM ubuntu:24.04

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

ARG HOSTNAME=localhost
ARG IDPURL=https://idp.local
ARG USERPORT=443
ARG USERREDIRECTPORT=80
ARG ADMINPORT=8443
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

COPY ./apache-ssl/ /etc/apache2/ssl/
COPY ./shibboleth/ /etc/shibboleth/

WORKDIR /var/www/
RUN git clone https://github.com/CiscoDevNet/iPSK-Manager.git && chown www-data:www-data -R iPSK-Manager

WORKDIR /
RUN cat <<EOF > /etc/shibboleth/shibboleth2.xml 
<?xml version="1.0" encoding="UTF-8"?>
<SPConfig xmlns="urn:mace:shibboleth:3.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:3.0:native:sp:config"

    clockSkew="180">

    <OutOfProcess tranLogFormat="%u|%s|%IDP|%i|%ac|%t|%attr|%n|%b|%E|%S|%SS|%L|%UA|%a" />

    <ApplicationDefaults entityID="https://$HOSTNAME/shibboleth" 
        REMOTE_USER="eppn subject-id pairwise-id persistent-id"
        metadataAttributePrefix="Meta-"
        sessionHook="/Shibboleth.sso/AttrChecker"
        cipherSuites="DEFAULT:!EXP:!LOW:!aNULL:!eNULL:!DES:!IDEA:!SEED:!RC4:!3DES:!kRSA:!SSLv2:!SSLv3:!TLSv1:!TLSv1.1">
    
        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false" handlerSSL="true" cookieProps="https"
                  redirectLimit="exact">

            <SSO entityID="$IDPURL">
              SAML2
            </SSO>

            <Logout>SAML2 Local</Logout>
            <LogoutInitiator type="Admin" Location="/Logout/Admin" acl="127.0.0.1 ::1" />
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>

        <MetadataProvider type="XML" validate="true" path="partner-metadata.xml"/>
        
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>

        <CredentialResolver type="File" use="signing"
            key="sp-key.pem" certificate="sp-cert.pem"/>
        <CredentialResolver type="File" use="encryption"
            key="sp-key.pem" certificate="sp-cert.pem"/>
    </ApplicationDefaults>
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF
RUN sed -i 's/^bind-address/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf && \
    sed -i 's|ErrorLog \${APACHE_LOG_DIR}/error.log|ErrorLog /dev/stderr|' /etc/apache2/apache2.conf && \
    echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf && \
    export SQL_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 20) && \
    mkdir /opt/ipsk-manager && \
    chown www-data:www-data /opt/ipsk-manager && \
    echo "$HOSTNAME" > /opt/ipsk-manager/hostname && \
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
    echo "if [ ! -f \"/etc/apache2/ssl/server.crt\" -o ! -f \"/etc/apache2/ssl/server.key\" -o ! -f \"/etc/apache2/ssl/ca.crt\" ]; then" >> init.sh && \
    echo "openssl genrsa -out /etc/apache2/ssl/ca.key 4096" >> init.sh && \
    echo "openssl req -x509 -new -nodes -key /etc/apache2/ssl/ca.key -sha256 -days 5478 -out /etc/apache2/ssl/ca.crt -subj '/CN=iPSK Manager Root CA/C=US/ST=California/L=San Jose/O=Cisco DevNet'" >> init.sh && \
    echo "openssl req -new -nodes -out /etc/apache2/ssl/server.csr -newkey rsa:4096 -keyout /etc/apache2/ssl/server.key -subj '/CN=$HOSTNAME/C=US/ST=California/L=San Jose/O=Cisco DevNet'" >> init.sh && \
    echo "openssl x509 -req -in /etc/apache2/ssl/server.csr -CA /etc/apache2/ssl/ca.crt -CAkey /etc/apache2/ssl/ca.key -CAcreateserial -out /etc/apache2/ssl/server.crt -days 3652 -sha256" >> init.sh && \
    echo "fi" >> init.sh && \
    echo "cat <<EOF > /etc/apache2/sites-available/ipsk-user-portal.conf" >> init.sh && \
    echo "<IfModule mod_ssl.c>" >> init.sh && \
    echo "  <VirtualHost *:$USERPORT>" >> init.sh && \
    echo "      ServerAdmin webmaster@ipskmanager" >> init.sh && \
    echo "      DocumentRoot /var/www/iPSK-Manager/portals" >> init.sh && \
    echo "      <Directory /var/www/iPSK-Manager/portals>" >> init.sh && \
    echo "          AllowOverride All" >> init.sh && \
    echo "      </Directory>" >> init.sh && \
    echo "      ErrorLog /dev/stderr" >> init.sh && \
    echo "      CustomLog /dev/stdout combined" >> init.sh && \
    echo "      SSLEngine on" >> init.sh && \
    echo "      SSLCertificateFile /etc/apache2/ssl/server.crt" >> init.sh && \
    echo "      SSLCertificateKeyFile /etc/apache2/ssl/server.key" >> init.sh && \
    echo "      SSLCertificateChainFile /etc/apache2/ssl/ca.crt" >> init.sh && \
    echo "      <FilesMatch \"\\.(cgi|shtml|phtml|php)$\">" >> init.sh && \
    echo "          SSLOptions +StdEnvVars" >> init.sh && \
    echo "      </FilesMatch>" >> init.sh && \
    echo "  </VirtualHost>" >> init.sh && \
    echo "</IfModule>" >> init.sh && \
    echo "EOF" >> init.sh && \
    echo "cat <<EOF > /etc/apache2/sites-available/ipsk-admin-portal.conf" >> init.sh && \
    echo "<IfModule mod_ssl.c>" >> init.sh && \
    echo "  Listen $ADMINPORT" >> init.sh && \
    echo "  <VirtualHost *:$ADMINPORT>" >> init.sh && \
    echo "      ServerAdmin webmaster@ipskmanager" >> init.sh && \
    echo "      DocumentRoot /var/www/iPSK-Manager/adminportal" >> init.sh && \
    echo "      <Directory /var/www/iPSK-Manager/adminportal>" >> init.sh && \
    echo "          AllowOverride All" >> init.sh && \
    echo "      </Directory>" >> init.sh && \
    echo "      ErrorLog /dev/stderr" >> init.sh && \
    echo "      CustomLog /dev/stdout combined" >> init.sh && \
    echo "      SSLEngine on" >> init.sh && \
    echo "      SSLCertificateFile /etc/apache2/ssl/server.crt" >> init.sh && \
    echo "      SSLCertificateKeyFile /etc/apache2/ssl/server.key" >> init.sh && \
    echo "      SSLCertificateChainFile /etc/apache2/ssl/ca.crt" >> init.sh && \
    echo "      <FilesMatch \"\\.(cgi|shtml|phtml|php)$\">" >> init.sh && \
    echo "          SSLOptions +StdEnvVars" >> init.sh && \
    echo "      </FilesMatch>" >> init.sh && \
    echo "  </VirtualHost>" >> init.sh && \
    echo "</IfModule>" >> init.sh && \
    echo "EOF" >> init.sh && \
    echo "cat <<EOF > /etc/apache2/sites-available/ipsk-user-portal-redirect.conf" >> init.sh && \
    echo "<VirtualHost *:$USERREDIRECTPORT>" >> init.sh && \
    echo "  ServerAdmin webmaster@ipskmanager" >> init.sh && \
    echo "  ErrorLog /dev/stderr" >> init.sh && \
    echo "  CustomLog /dev/stdout combined" >> init.sh && \
    echo "  Redirect permanent / https://$HOSTNAME/" >> init.sh && \
    echo "</VirtualHost>" >> init.sh && \
    echo "EOF" >> init.sh && \
    echo "a2dissite 000-default && a2ensite ipsk-user-portal-redirect && a2ensite ipsk-user-portal && a2ensite ipsk-admin-portal && a2dismod shib && a2disconf shib" >> init.sh && \
    echo "sed -i '/<!-- The eduPerson attribute version (note the OID-style name): -->/{" >> init.sh && \
    echo "n; s/^/<!-- /; s/$/ -->/;" >> init.sh && \
    echo "n; s/^/<!-- /; s/$/ -->/;" >> init.sh && \
    echo "n; s/^/<!-- /; s/$/ -->/;" >> init.sh && \
    echo "}' /etc/shibboleth/attribute-map.xml" >> init.sh && \
    echo "sed -i 's|<Attribute name=\"urn:oasis:names:tc:SAML:2.0:nameid-format:persistent\" id=\"persistent-id\">|<Attribute name=\"urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified\" id=\"persistent-id\">|' /etc/shibboleth/attribute-map.xml" >> init.sh && \
    echo "sed -i 's|<AttributeDecoder xsi:type=\"NameIDAttributeDecoder\" formatter=\"\$NameQualifier!\$SPNameQualifier!\$Name\" defaultQualifiers=\"true\"/>|<AttributeDecoder xsi:type=\"NameIDAttributeDecoder\" formatter=\"\$Name\" defaultQualifiers=\"true\"/>|' /etc/shibboleth/attribute-map.xml" >> init.sh && \
    echo "#!/bin/sh" >> disablesso.sh && \
    echo "unlink /opt/ipsk-manager/sso" >> disablesso.sh && \
    echo "service shibd stop" >> disablesso.sh && \
    echo "a2dismod shib && a2disconf shib" >> disablesso.sh && \
    echo "apachectl -k graceful" >> disablesso.sh && \
    echo "#!/bin/sh" >> enablesso.sh && \
    echo "if [ -f \"/etc/shibboleth/sp-cert.pem\" -a -f \"/etc/shibboleth/sp-key.pem\" ]; then" >> enablesso.sh && \
    echo "chmod 644 /etc/shibboleth/sp-cert.pem" >> enablesso.sh && \
    echo "chown _shibd:_shibd /etc/shibboleth/sp-cert.pem" >> enablesso.sh && \
    echo "chmod 600 /etc/shibboleth/sp-key.pem" >> enablesso.sh && \
    echo "chown _shibd:_shibd /etc/shibboleth/sp-key.pem" >> enablesso.sh && \
    echo "else" >> enablesso.sh && \
    echo "shib-keygen -h \$(cat /opt/ipsk-manager/hostname) -e \$(cat /opt/ipsk-manager/hostname)" >> enablesso.sh && \
    echo "fi" >> enablesso.sh && \
    echo "touch /opt/ipsk-manager/sso" >> enablesso.sh && \
    echo "service shibd start" >> enablesso.sh && \
    echo "a2enmod shib && a2enconf shib" >> enablesso.sh && \
    echo "apachectl -k graceful" >> enablesso.sh && \
    chmod 744 enablesso.sh && \
    chmod 744 disablesso.sh && \
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
    echo "if [ -f \"/opt/ipsk-manager/sso\" ]; then service shibd start ; fi" >> run.sh && \
    echo "apachectl -D FOREGROUND" >> run.sh

EXPOSE 8443 443 3306

CMD ["./run.sh"]

