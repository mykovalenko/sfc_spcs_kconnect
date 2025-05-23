#!/bin/bash

echo "(!)  Before proceeding, make sure you had successfully run and/or meet  (!)"
echo "(!)  all the requirements addressed in [preinstall.sh]. It's aimed for  (!)"
echo "(!)  installation of required tools: Docker engine and Snowflake CLI.   (!)"

PWD=$(pwd)
APPNAME=$(basename ${PWD} | tr '[:upper:]' '[:lower:]')

# Prompt user for input
read -p "Give a name for your deployment [${APPNAME}]: " DEPNAME
DEPNAME=${DEPNAME:-${APPNAME}}

read -p "Provide target Snowflake ORG name [ORG]: " ORGNAME
ORGNAME=$(echo "${ORGNAME:-'ORG'}" | tr '[:upper:]' '[:lower:]')

read -p "Provide target Snowflake ACC alias [ACC]: " ACCALIAS
ACCALIAS=$(echo "${ACCALIAS:-'ACC'}" | tr '[:upper:]' '[:lower:]')

read -p "Provide EventHub namespace (without [.servicebus.windows.net]): " HUBNAME
HUBNAME=$(echo "${HUBNAME:-'missing'}" | tr '[:upper:]' '[:lower:]')

read -p "Provide source topic name (Event Hub): " TOPNAME
TOPNAME=$(echo "${TOPNAME:-'missing'}" | tr '[:upper:]' '[:lower:]')

read -p "Provide SAS Key Name [RootManageSharedAccessKey]: " KEYNAME
KEYNAME=$(echo "${KEYNAME:-RootManageSharedAccessKey}")

read -p "Provide SAS Key: " KEYPASS
KEYPASS=$(echo "${KEYPASS:-'missing'}")

read -p "Provide target database name (should be created manually): " DBSNAME
DBSNAME=$(echo "${DBSNAME:-'apps'}" | tr '[:upper:]' '[:lower:]')

read -p "Provide target table name (created automatically): " TBLNAME
TBLNAME=$(echo "${TBLNAME:-'messages'}" | tr '[:upper:]' '[:lower:]')

read -p "Is target an Iceberg table (false): " ICEFLAG
ICEFLAG=$(echo "${ICEFLAG:-'false'}" | tr '[:upper:]' '[:lower:]')

if [ "_"$ICEFLAG != "_true" ]; then
	ICEFLAG='false'
else
	echo "You must manually create ICEBERG table after deployment:"
	echo ""
	echo "GRANT USAGE ON EXTERNAL VOLUME <volume_name> TO ROLE APP_${DEPNAME}_OWNER;"
	echo "CREATE OR REPLACE ICEBERG TABLE ${DBSNAME}.${DEPNAME}.${TBLNAME}(RECORD_METADATA OBJECT())"
	echo "    EXTERNAL_VOLUME = '<volume_name>'"
	echo "    BASE_LOCATION = '<path/location/on/volume/storage>'"
	echo "    CATALOG = 'SNOWFLAKE';"
	echo "ALTER ICEBERG TABLE ${DBSNAME}.${DEPNAME}.${TBLNAME} SET ENABLE_SCHEMA_EVOLUTION = TRUE;"
fi

read -r -p "Proceed building the deployment? [Y/n]: " response
case "${response}" in
    [nN][oO]|[nN]) 
        exit 1
        ;;
    *)
        echo ""
        ;;
esac

ACCNAME="${ORGNAME}_${ACCALIAS}"
CXNNAME="${ACCNAME}_SETUP"

CLIHOME="$HOME/.config/snowflake"
BASEDIR="${PWD}/bld/${ACCNAME}/${DEPNAME}"
CONFDIR="${BASEDIR}/cfg/${ACCNAME}"

rm -rf "${BASEDIR}"
mkdir -p "${CONFDIR}"
mkdir -p "${BASEDIR}/log"
mkdir -p "${BASEDIR}/cfg"
cp -rf ./etc/* "${BASEDIR}"
cp -rf ./img "${BASEDIR}"
cp -rf ./dbs "${BASEDIR}"

cd ${BASEDIR}

openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ${CONFDIR}/deployusr_rsa_key.p8 -nocrypt
openssl rsa -in ${CONFDIR}/deployusr_rsa_key.p8 -pubout -out ${CONFDIR}/deployusr_rsa_key.pub

pk=$(cat ${CONFDIR}/deployusr_rsa_key.pub | grep -v 'PUBLIC KEY'  | tr -d '\n')
p8=$(cat ${CONFDIR}/deployusr_rsa_key.p8  | grep -v 'PRIVATE KEY' | tr -d '\n')
echo "USE ROLE ACCOUNTADMIN; ALTER USER APP_${DEPNAME}_USER SET RSA_PUBLIC_KEY='${pk}';" >${BASEDIR}/dbs/setkey.sql

sed -i "s|&{ depname }|${DEPNAME}|g" ${BASEDIR}/Makefile
sed -i "s|&{ hubname }|${HUBNAME}|g" ${BASEDIR}/Makefile
sed -i "s|&{ dbsname }|${DBSNAME}|g" ${BASEDIR}/Makefile
sed -i "s|&{ cnxname }|${CXNNAME}|g" ${BASEDIR}/Makefile
sed -i "s|&{ accname }|${ORGNAME}-${ACCALIAS}|g" ${BASEDIR}/Makefile

sed -i "s|&{ depname }|${DEPNAME}|g" ${BASEDIR}/img/service.yaml
sed -i "s|&{ dbsname }|${DBSNAME}|g" ${BASEDIR}/img/service.yaml
sed -i "s|&{ accname }|${ORGNAME}-${ACCALIAS}|g" ${BASEDIR}/img/service.yaml

sed -i "s|&{ topname }|${TOPNAME}|g" ${BASEDIR}/post_message.sh
sed -i "s|&{ hubname }|${HUBNAME}|g" ${BASEDIR}/post_message.sh
sed -i "s|&{ keyname }|${KEYNAME}|g" ${BASEDIR}/post_message.sh
sed -i "s|&{ keypass }|${KEYPASS}|g" ${BASEDIR}/post_message.sh

sed -i "s|&{ hubname }|${HUBNAME}|g" ${BASEDIR}/img/eventhub.properties
sed -i "s|&{ keyname }|${KEYNAME}|g" ${BASEDIR}/img/eventhub.properties
sed -i "s|&{ keypass }|${KEYPASS}|g" ${BASEDIR}/img/eventhub.properties

sed -i "s|&{ topname }|${TOPNAME}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ tblname }|${TBLNAME}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ iceflag }|${ICEFLAG}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ accname }|${ORGNAME}-${ACCALIAS}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ dbsname }|${DBSNAME}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ xmaname }|${DEPNAME}|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ svcrole }|APP_${DEPNAME}_OWNER|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ svcuser }|APP_${DEPNAME}_USER|g" ${BASEDIR}/img/snowflake.properties
sed -i "s|&{ keypair }|${p8}|g" ${BASEDIR}/img/snowflake.properties

sed -i "s|&{ depname }|${DEPNAME}|g" ${BASEDIR}/dbs/control.ipynb
sed -i "s|&{ dbsname }|${DBSNAME}|g" ${BASEDIR}/dbs/control.ipynb

# Create SETUP MASTER USER connection entry for snow cli
grep -qis "${CXNNAME}" ${CLIHOME}/connections.toml
if [ $? -eq 0 ]; then
	echo "Connection profile [${CXNNAME}] found."
else
	echo "Connection profile [${CXNNAME}] not found in [${CLIHOME}/connections.toml]"
	read -r -p "Create connection profile for this deployment? [Y/n] " response
	case "$response" in
	    [nN][oO]|[nN]) 
	        echo "Cannot proceed without Snowflake connection. Aborting."
	        exit 1
	        ;;
	    *)
			#echo ${PWD##*/}>.dmp
			#openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 des3 -inform PEM -out ${CONFDIR}/1setupusr_rsa_key.p8 -passout file:.dmp
			#openssl rsa -in ${CONFDIR}/setupusr_rsa_key.p8 -pubout -out ${CONFDIR}/setupusr_rsa_key.pub -passin file:.dmp
			openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out ${CONFDIR}/setupusr_rsa_key.p8 -nocrypt
			openssl rsa -in ${CONFDIR}/setupusr_rsa_key.p8 -pubout -out ${CONFDIR}/setupusr_rsa_key.pub
			#rm .dmp

			# Generate CREATE USER statement - to be executed manually in Snowflake before proceeding further
			pk=$(cat ${CONFDIR}/setupusr_rsa_key.pub | grep -v 'PUBLIC KEY' | tr -d '\n')
			echo "Execute the following statement in target Snowflake account"
			echo -e "-- {INI} --\n"
			echo -e "USE ROLE ACCOUNTADMIN;"                      | tee -a "./dbs/install_user.sql"
			echo -e "CREATE OR REPLACE USER ${CXNNAME}"           | tee -a "./dbs/install_user.sql"
			echo -e "TYPE = SERVICE"                              | tee -a "./dbs/install_user.sql"
			echo -e "DEFAULT_ROLE = ACCOUNTADMIN"                 | tee -a "./dbs/install_user.sql"
			echo -e "RSA_PUBLIC_KEY = '${pk}';"                   | tee -a "./dbs/install_user.sql"
			echo -e "GRANT ROLE ACCOUNTADMIN TO USER ${CXNNAME};" | tee -a "./dbs/install_user.sql"
			echo -e "GRANT ROLE SYSADMIN TO USER ${CXNNAME};"     | tee -a "./dbs/install_user.sql"
			echo -e "\n-- {END} --"

			read -r -p "Have you run SQL script to create install user? [Y/n]: " response
			case "${response}" in
			    [nN][oO]|[nN]) 
			        exit 1
			        ;;
			    *)
			        echo ""
			        ;;
			esac

			# Connection profile for setup master user
			echo -e "Adding profile to snow cli connections\n"
			echo -e "\n[${CXNNAME}]"                              | tee -a "${CONFDIR}/connections.toml"
			echo -e "account = \"${ORGNAME}-${ACCALIAS}\""        | tee -a "${CONFDIR}/connections.toml"
			echo -e "warehouse = \"COMPUTE_WH\""                  | tee -a "${CONFDIR}/connections.toml"
			echo -e "database = \"SNOWFLAKE\""                    | tee -a "${CONFDIR}/connections.toml"
			echo -e "schema = \"ACCOUNT_USAGE\""                  | tee -a "${CONFDIR}/connections.toml"
			echo -e "role = \"ACCOUNTADMIN\""                     | tee -a "${CONFDIR}/connections.toml"
			echo -e "user = \"${CXNNAME}\""                       | tee -a "${CONFDIR}/connections.toml"
			echo -e "private_key_path = \"${CLIHOME}/${ACCNAME}/setupusr_rsa_key.p8\"" | tee -a "${CONFDIR}/connections.toml"
			echo -e "authenticator = \"SNOWFLAKE_JWT\""           | tee -a "${CONFDIR}/connections.toml"
			
			# Update permissions on config file and test connection
			chmod 0600 "${CONFDIR}/connections.toml"

			mkdir -p ${CLIHOME}/${ACCNAME}/bak
			cp ${CLIHOME}/connections.toml ${CLIHOME}/${ACCNAME}/bak/
			cp ${CONFDIR}/setupusr_rsa_key.* ${BASEDIR}/dbs/install_user.sql ${CLIHOME}/${ACCNAME}/
			cat "${CONFDIR}/connections.toml" >>${CLIHOME}/connections.toml
	        ;;
	esac
fi

#snow --config-file="${CONFDIR}/config.toml" sql -c snowflake_installer -q "SELECT CURRENT_ACCOUNT_NAME() as TEST"
#snow sql -c "${CXNNAME}" -q "SELECT CURRENT_ACCOUNT_NAME() as TEST"
snow connection test -c "${CXNNAME}"

read -r -p "Was connection successfull? [Y/n] " response
case "$response" in
    [nN][oO]|[nN]) 
        exit 1
        ;;
    *)
        echo ""
        ;;
esac

echo "All done. Go to [${BASEDIR}] and run deployment using Makefile"
cd ${BASEDIR}
