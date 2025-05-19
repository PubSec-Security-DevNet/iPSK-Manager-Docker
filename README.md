# iPSK-Manager Docker Container

This project is dedicated to the development of a Docker container image tailored for those who prefer the convenience and flexibility of running [iPSK Manager](https://github.com/CiscoDevNet/iPSK-Manager) within a Docker environment. The current Docker build process incorporated in this project encompasses several key features:

- Persistent Storage: The project supports persistent storage for both MySQL databases and iPSK Manager configuration files. This ensures that your data and settings are retained across container restarts and rebuilds.
- SAML Single Sign-On (SSO): Integration with SAML SSO is facilitated through Shibboleth Service Provider (SP) for those who wish to enable SSO in iPSK Manager.
- MySQL Database Flexibility: Users have the option to utilize MySQL within the container or to connect to an external MySQL database, depending on their infrastructure and requirements.
- Simplified Upgrade Process: The project offers a straightforward method for upgrading iPSK Manager, minimizing downtime and complexity.

*Please note that in order to benefit from persistent storage, it is crucial to adhere to the provided guidelines on creating and attaching the necessary persistent storage volumes to your Docker container. It is also important to understand that Docker volumes are not inherently backed up. Therefore, the responsibility lies with you to ensure that backups of the MySQL database and iPSK Manager configuration files are regularly performed to safeguard your data.*

## Build Process

Prior to proceeding with the build and installation of the container, it is essential to confirm that Docker is installed on the system intended for use. Docker Desktop is not a necessity for this operation, as the forthcoming instructions are designed to utilize the command-line interface (CLI) for the construction and deployment of the Docker container.

Please ensure that the Docker engine is properly set up and functioning on your machine. You can verify the installation and check the version of Docker by executing the following command in your terminal or command prompt:

```
docker --version
```

If Docker is not installed, you will need to download and install the appropriate version for your operating system. Detailed instructions for installing Docker can be found on the official Docker documentation website. Once Docker is successfully installed, you may proceed with the build and run instructions for the Docker container as outlined below.

## Downloading Build Files

To clone this GitHub repository to your device using Git, you can follow these steps:
1.	Open a terminal window (on Linux or macOS) or command prompt/PowerShell (on Windows).
2.	Navigate to the directory where you want the cloned repository to be placed using the cd (change directory) command.
3.	Use the git clone command followed by the repository's URL. 

```
git clone https://github.com/PubSec-Security-DevNet/iPSK-Manager-Docker.git
```

Alternatively, you can also download a zip file from the GitHub repository for this project and unzip it in the directory you want to use.

## Build arguments

- HOSTNAME=\<string\>
    - Define the hostname that resolves to the iPSK Manager container. (Default: locahost)
- IDPURL=\<string\>
    - The entityID of the IDP. (Default: locahost)
- USERPORT=\<integer\>
    - TCP port that Apache should use for iPSK Manager user portals. (Default: 443)
- USERREDIRECTPORT=\<integer\>
    - TCP port that Apache should use to redirect to the SSL userport. (Default: 80)
- ADMINPORT=\<integer\>
    - TCP port that Apache should use for iPSK Manager admin portal. (Default: 8443)
- MYSQL_ENABLED=\<true/false\>
    - Option to enable or disable MySQL process from running within container (Default: true)

## Persistent Volumes

To ensure that your iPSK Manager configuration and MySQL database remain intact when you refresh or update the Docker container, persistent storage must be set up. This is achieved by creating Docker volumes that will store this data outside of the container's lifecycle. The following commands should be executed in your terminal or command prompt to initialize the persistent storage volumes. This step is necessary only once, before you build the container image for the first time.
1.	Create a Docker volume for the iPSK Manager configuration:
```
docker volume create ipskconfig
```
2.	Create a Docker volume for the MySQL database:
```
docker volume create mysqldata
```
These commands will create two separate Docker volumes, one for the iPSK Manager configuration and another for the MySQL database. The data stored in these volumes will persist across container rebuilds and restarts, ensuring that your configuration and database are not lost during updates or maintenance.

## Apache Configuration

Apache is automatically configured using the default ports specified in the build arguments above. If you want to change the ports, simply modify the build arguments. SSL is enabled by default, with certificates being automatically generated unless you provide your own. To use custom certificates, place them in the apache-ssl folder before building the image. The files must be named as follows: server.crt (server certificate), server.key (server certificate key), and ca.crt (CA chain certificate).

## Shibboleth Configuration (SSO Only)

This Docker container uses Shibboleth as the built-in SAML Service Provider (SP). If you plan to use SAML for authentication with iPSK Manager, define the HOSTNAME and IDPURL during the build process, as some Shibboleth configuration files are generated during the container's initial startup, even if you don't enable SAML. Additionally, you’ll need to place your Identity Provider (IdP) metadata file in the shibboleth folder and name it partner-metadata.xml.

By default, signing and encryption certificates and keys are auto-generated when SSO is enabled for the first time. If you prefer not to use auto-generated certificates/keys, you must generate your own and place them in the shibboleth folder before building the image. The files should be named sp-key.pem (SP key) and sp-cert.pem (SP certificate). Currently, the same certificate and key are used for both signing and encryption.

To enable SSO after the container is running, issue the following command from the host machine running the container:

```sh
docker exec -i ipskmanager sh -c '/enablesso.sh'
```

To disable SSO after the container is running, issue the following command from the host machine running the container:

```sh
docker exec -i ipskmanager sh -c '/disablesso.sh'
```

*Please note that once SSO is enabled, access to the iPSK Manager login pages will require SSO authentication, even if SSO has not been fully configured for iPSK Manager. If SSO is not functioning correctly, access will still be restricted. You can disable SSO at any time using the command above to regain access to iPSK Manager and bypass SSO authentication requirements.*

## Build Docker Image

To build the iPSK Manager Docker image on your system, please follow these steps:
1.	Open a command-line interface (CLI) on your computer. This could be Terminal on macOS or Linux, or Command Prompt or PowerShell on Windows.
2.	Navigate to the base directory of the iPSK Manager Docker repository that you have either cloned or downloaded. Use the cd command to change directories to the location where the repository resides on your system. For example:

```
cd /path/to/ipsk-manager-docker
```

3.	Once you're in the correct directory, run the following Docker build command to build the image with default options, other examples are below:

```
docker build -t ipskmanager-image . --no-cache
```

Breaking down this command:
-	**docker build** is the Docker command used to create a Docker image from a Dockerfile.
-	**-t ipskmanager-image** assigns the tag "ipskmanager-image" to the new Docker image, which allows you to easily reference the image later.
-	**.** (a period) tells Docker to look for the Dockerfile in the current directory.
-	**--no-cache** is an option that tells Docker not to use any cached layers when building the image. This ensures that each step of the build process uses the most recent version of the data, which is particularly useful when you want to ensure that the latest version of iPSK Manager is included in your image.

The build command above will proceed to create the Docker image with the default parameters specified:
- MySQL will be enabled within the container.
- Single Sign-On (SSO) will be disabled.

### Examples of other Docker build commands to change settings

To set MySQL to not run within the container

```
docker build --build-arg MYSQL_ENABLED=false --no-cache -t ipskmanager-image .
```

To set HOSTNAME and IDPURL as enabled and not run MySQL within the container

```
docker build --build-arg HOSTNAME=ipsk.example.local --build-arg IDPURL='https://idp.example.local/idp-server' --build-arg MYSQL_ENABLED=false --no-cache -t ipskmanager-image .
```

## Running Docker Image

To start the docker image open a CLI and enter the following command

```
docker run -d --name ipskmanager --mount source=mysqldata,destination=/var/lib/mysql \
--mount source=ipskconfig,destination=/opt/ipsk-manager \
-p 80:80/tcp -p 443:443/tcp -p 8443:8443/tcp -p 3306:3306/tcp ipskmanager-image
```

For new installations of iPSK Manager within a Docker container, follow the initial build and run steps outlined below. For subsequent container runs, the system will automatically load the persistent state from the mounted volumes. To upgrade iPSK Manager, execute the build process again to pull updates from the GitHub repository and then start the container using the same syntax as before. Upon starting the upgraded container, access the Admin Portal URL where iPSK Manager will detect the existing configuration, migrate the necessary state files, and present you with a login screen, indicating that the upgrade is complete and iPSK Manager is ready for use.

## Optional Docker Static IP Configuration

Sometimes, you may want to assign a specific IP address to a Docker container. To achieve this, you can create a network and then assign it to the container using the `docker run` command. Below is an example of how to assign a static IP address to the iPSK Manager Docker container.

Create a network 

```
docker network create -d ipvlan \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  -o parent=eth0.100 \
  ipsk-manager-network
```

Breaking down this command:
-	**-d ipvlan** Specifies the ipvlan driver.
-	**--subnet=192.168.100.0/24** Defines the subnet for the network.
-	**--gateway=192.168.100.1** Defines the gateway for the subnet.
-	**-o parent=eth0.100** Specifies the parent interface, and the VLAN interface if you created one, otherwise leave VLAN off.
-	**ipsk-manager-network** The name of the new network.

Running iPSK Manager Docker image with defined network

```
docker run -d --name ipskmanager --mount source=mysqldata,destination=/var/lib/mysql \
--mount source=ipskconfig,destination=/opt/ipsk-manager \
--network ipsk-manager-network -p 80:80/tcp -p 443:443/tcp \
-p 8443:8443/tcp -p 3306:3306/tcp ipskmanager-image
```

## New iPSK Manager Installation within Container

If you are running the iPSK Manager container for the first time and iPSK Manager has not been installed previously, you will need to complete the iPSK Manager installation process via the web-based installer. Here's what you need to do:
1.	Open a web browser and navigate to the URL of the admin dashboard for iPSK Manager, which by default is set to use port 8443. Replace \<ipsk-manager-url\> with the actual URL or IP address of your Docker host:

```
https://<ipsk-manager-url>:8443
```
2.	Upon visiting the URL, you should see the iPSK Manager installation screen. Follow the prompts and click "Next" until you reach the database configuration screen.

![install-image-1](images/ipsk-install-1.png)

3.	If you built the container to use the built-in MySQL server (default), all values on the database configuration screen should be pre-populated and not editable. You can press "Next" to continue the installation process.

    *Note: If you built the container to use an external MySQL server, you will need to fill in all the values on this page as you would for a standalone installation. Refer to the iPSK Manager project README for guidance.*
	   
![install-image-2](images/ipsk-install-2.png)

4.	Continue following the installer prompts. The remaining installation process for iPSK Manager is the same as when it is not containerized.
5.	Once the installation is complete, you should be redirected to the iPSK Manager login screen.

## Running the expire-endpoints cron script
As the container does not have cron installed if you wish to use the example cron script for endpoint expire or log truncating you will need to use a cron process outside the container that will run the script within the container.  Before doing this you will need to edit the script.

Steps to edit script:

Run the command below to set the path of iPSK-Manager in the script.

```sh
docker exec -it ipskmanager sed -i 's|\$ipskManagerPath = "/path/to/iPSK-Manager";|\$ipskManagerPath = "/var/www/iPSK-Manager";|' /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt
```

Option Settings:

To enable endpoint expire process

```sh
docker exec -it ipskmanager sed -i 's|\$expireEndpoints = false;|\$expireEndpoints = true;|'  /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt
```

To enable endpoint expire email warning

```sh
docker exec -it ipskmanager sed -i 's|\$expireEmailNotice = false;|\$expireEmailNotice = true;|'  /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt
```

To change number of days before expire warning from default 10 to 20 days as example

```sh
docker exec -it ipskmanager sed -i 's|\$expireWarningDays = 10;|\$expireWarningDays = 20;|'  /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt
```

To enable log truncation

```sh
docker exec -it ipskmanager sed -i 's|\$truncateLogs = false;|\$truncateLogs = true;|'  /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt
```

Once you have finished setting the options you wish to set then enter the command below to copy the script

```sh
docker exec -it ipskmanager cp /var/www/iPSK-Manager/expire-endpoints-cron-example.php.txt /var/www/iPSK-Manager/expire-endpoints-cron.php
```

Set the cron process on the container host OS to run the following line at the interval you choose

```sh
docker exec -i ipskmanager sh -c 'php /var/www/iPSK-Manager/expire-endpoints-cron.php'
```

Note, the above steps should be performed after every container rebuild in order to run the script in a host OS crontab. 

## Database Schema Updates (When Required)
Sometimes schema changes may be included in an update of iPSK Manager. After logging into the admin portal, if you are presented with a database schema update required message, follow the steps below to process the schema update for the particular schema version you need to apply. Remember, schema version changes are not cumulative.

### Schema Update v4
1. Run command below to change contents of the schemaupdate-v4.sql file to point to the iPSK Manager database used on the Docker Container.
```sh
docker exec -it ipskmanager sed -i 's/USE `<ISE_DB_NAME>`;/USE `ipsk`;/g' /var/www/iPSK-Manager/schemaupdate-v4.sql
```
2. Run command below to apply schema change to database
```sh
docker exec -i ipskmanager sh -c 'mysql -u root < /var/www/iPSK-Manager/schemaupdate-v4.sql'
```

### Schema Update v5
1. Run commands below to change contents of the schemaupdate-v5.sql file to point to the iPSK Manager database used on the Docker Container.
```sh
docker exec -it ipskmanager sed -i 's/USE `<ISE_DB_NAME>`;/USE `ipsk`;/g' /var/www/iPSK-Manager/schemaupdate-v5.sql
docker exec -it ipskmanager sed -i 's/CREATE DEFINER=`<ISE_DB_USERNAME>`@`%` PROCEDURE/CREATE DEFINER=`ipskiseuser`@`%` PROCEDURE/g' /var/www/iPSK-Manager/schemaupdate-v5.sql
```
2. Run command below to apply schema change to database
```sh
docker exec -i ipskmanager sh -c 'mysql -u root < /var/www/iPSK-Manager/schemaupdate-v5.sql'
```

### Schema Update v6
1. Run commands below to change contents of the schemaupdate-v6.sql file to point to the iPSK Manager database used on the Docker Container.
```sh
docker exec -it ipskmanager sed -i 's/USE `<ISE_DB_NAME>`;/USE `ipsk`;/g' /var/www/iPSK-Manager/schemaupdate-v6.sql
docker exec -it ipskmanager sed -i 's/CREATE DEFINER=`<IPSK_DB_USERNAME>`@`%` TRIGGER/CREATE DEFINER=`ipskdbuser`@`%` TRIGGER/g' /var/www/iPSK-Manager/schemaupdate-v6.sql
docker exec -it ipskmanager sed -i 's/CREATE DEFINER=`<ISE_DB_USERNAME>`@`%` PROCEDURE/CREATE DEFINER=`ipskiseuser`@`%` PROCEDURE/g' /var/www/iPSK-Manager/schemaupdate-v6.sql
```
2. Run command below to apply schema change to database
```sh
docker exec -i ipskmanager sh -c 'mysql -u root < /var/www/iPSK-Manager/schemaupdate-v6.sql'
```
