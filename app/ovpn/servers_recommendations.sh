#!/bin/bash

. /app/date.sh --source-only

#Env
JSON_FILE=/tmp/servers_recommendations.json
JSON_FILE_SERVER_COUNTRIES=/tmp/servers_countries

# If no server was set, choose the best
if [[ ! -v SERVER ]]; then
    echo "$(adddate) INFO: SERVER has not been set, choosing best for you."
    QUERY_PARAM='?'
    if [ -z "$RANDOM_TOP" ]
        then
            QUERY_PARAM=$QUERY_PARAM'limit=1'
        else
            QUERY_PARAM=$QUERY_PARAM'limit='$RANDOM_TOP
    fi
    if [ -z "$COUNTRY" ]
        then 
            echo "$(adddate) INFO: No country has been set. The default will be picked by NordVPN API. If you want to use a country, please use e.g. COUNTRY=it"
            #GET fastest server based on NordVPN API
            #https://api.nordvpn.com/v1/servers/recommendations
        else
            echo "$(adddate) INFO: Your country setting will be used. This is set to: ${COUNTRY^^}"

            #Country codes will only be fetched once. You can force to get a new list to start a new container
            #This will speed up the process
            if [ -f "$JSON_FILE_SERVER_COUNTRIES" ]
                then
                    echo "$(adddate) INFO: The country codes are known, skipping"
                    export COUNTRY_CODE=$(cat $JSON_FILE_SERVER_COUNTRIES | jq '.[]  | select(.code == "'${COUNTRY^^}'") | .id')
                else 
                    echo "$(adddate) INFO: The country codes are unknown, getting country codes from API"
                    # The old wp-admin/admin-ajax?action=servers_countries page was retired by
                    # NordVPN (now returns 403/HTML). The v1 API exposes the same .code/.id shape.
                    curl -s https://api.nordvpn.com/v1/servers/countries -o /tmp/servers_countries
                    export COUNTRY_CODE=$(cat $JSON_FILE_SERVER_COUNTRIES | jq '.[]  | select(.code == "'${COUNTRY^^}'") | .id')
            fi

            QUERY_PARAM=$QUERY_PARAM'&filters%5Bcountry_id%5D='$COUNTRY_CODE
    fi
    
    #Set filter based on OpenVPN with the correct protocol
    QUERY_PARAM=$QUERY_PARAM'&filters%5Bservers_technologies%5D%5Bidentifier%5D=openvpn_'$PROTOCOL

    #GET fastest server based on COUNTRY
    #https://api.nordvpn.com/v1/servers/recommendations?limit=10&filters=[country_id]=106
    curl -s $SERVER_RECOMMENDATIONS_URL$QUERY_PARAM -o $JSON_FILE

    NUMBER_OF_SERVERS="$(jq length $JSON_FILE)"
    DESIRED_SERVER_NUMBER="$(shuf -i 0-$(($NUMBER_OF_SERVERS - 1)) -n 1)"

    #Set vars
    export SERVER="$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)"
    export SERVERNAME="$(jq -r '.['$DESIRED_SERVER_NUMBER'].name' $JSON_FILE)"
    export LOAD="$(jq -r '.['$DESIRED_SERVER_NUMBER'].load' $JSON_FILE)"
    export UPDATED_AT="$(jq -r '.['$DESIRED_SERVER_NUMBER'].updated_at' $JSON_FILE)"
    export IP="$(jq -r '.['$DESIRED_SERVER_NUMBER'].station' $JSON_FILE)"
    echo "$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)"
    echo "$(jq -r '.['$DESIRED_SERVER_NUMBER'].hostname' $JSON_FILE)" > /tmp/nordvpn_hostname

# Otherwise, use the server that was specified
else
    echo "$(adddate) INFO: SERVER has been set to ${SERVER^^}"
    # NordVPN retired api.nordvpn.com/server and the undefined SERVER_STATS_URL the
    # old code relied on. For a pinned server this metadata is informational only:
    # OpenVPN connects using the ${SERVER}.<proto>.ovpn config by hostname, and the
    # cron load check (get-status-server.sh) queries the v1 recommendations API on
    # its own. Pull live load/IP best-effort from recommendations (a pinned host may
    # not be in the recommended set, in which case these stay "n/a").
    curl -s "$SERVER_RECOMMENDATIONS_URL" > "$JSON_FILE" || echo '[]' > "$JSON_FILE"
    export SERVERNAME="$SERVER"
    export UPDATED_AT=""
    export LOAD="$(jq -r '.[] | select(.hostname=="'"$SERVER"'") | .load' "$JSON_FILE" | head -n1)"
    export IP="$(jq -r '.[] | select(.hostname=="'"$SERVER"'") | .station' "$JSON_FILE" | head -n1)"
    : "${LOAD:=n/a}"
    : "${IP:=n/a}"
    echo "$SERVER" > /tmp/nordvpn_hostname
fi