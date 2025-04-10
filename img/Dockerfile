FROM confluentinc/cp-kafka-connect:latest
ENV CONNECT_PLUGIN_PATH="/usr/share/confluent-hub-components"

# install snowflake kafka connector
RUN confluent-hub install --no-prompt snowflakeinc/snowflake-kafka-connector:latest
#RUN confluent-hub install --no-prompt confluentinc/kafka-connect-azure-event-hubs:latest

# main script
WORKDIR /opt/spcs
COPY ./main.sh /opt/spcs/

# main script
CMD ["chmod +x /opt/spcs/main.sh"]
ENTRYPOINT ["/opt/spcs/main.sh"]
