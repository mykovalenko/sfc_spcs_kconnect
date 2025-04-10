#!/bin/bash
cp -f /opt/spcs/stage/*.properties /opt/spcs/
cd /opt/spcs/

export CONNECT_REST_ADVERTISED_HOST_NAME=$HOSTNAME
sed -i "s|&{ spcshost }|${CONNECT_REST_ADVERTISED_HOST_NAME}|g" /opt/spcs/eventhub.properties
sleep 15 && curl -X PUT -H "Content-Type: application/json" --data @/opt/spcs/snowflake.properties http://localhost:8084/connectors/snow-connect/config &
/usr/bin/connect-distributed /opt/spcs/eventhub.properties
