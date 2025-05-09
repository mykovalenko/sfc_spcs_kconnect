MESSAGE="{\"tms\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"pid\": $$, \"id\": $RANDOM, \"wc\": $(echo \"$1\" | wc -w), \"msg\": \"${1}\"}"
TOPIC_NAME="&{ topname }"
EVENTHUB_URI="&{ hubname }.servicebus.windows.net"
SHARED_ACCESS_KEY_NAME="&{ keyname }"
SHARED_ACCESS_KEY="&{ keypass }"
EXPIRY=${EXPIRY:=$((60 * 60 * 24))} # Default token expiry is 1 day

ENCODED_URI=$(echo -n $EVENTHUB_URI | jq -s -R -r @uri)
TTL=$(($(date +%s) + $EXPIRY))
UTF8_SIGNATURE=$(printf "%s\n%s" $ENCODED_URI $TTL | iconv -t utf8)

HASH=$(echo -n "$UTF8_SIGNATURE" | openssl sha256 -hmac $SHARED_ACCESS_KEY -binary | base64)
ENCODED_HASH=$(echo -n $HASH | jq -s -R -r @uri)

sig="SharedAccessSignature sr=$ENCODED_URI&sig=$ENCODED_HASH&se=$TTL&skn=$SHARED_ACCESS_KEY_NAME"

echo "Sending ${MESSAGE}..."
curl -X POST "https://${EVENTHUB_URI}/${TOPIC_NAME}/messages?timeout=60&api-version=2014-01" \
-H "Authorization: ${sig}" \
-H "Content-Type: application/atom+xml;type=entry;charset=utf-8" \
-d "${MESSAGE}"