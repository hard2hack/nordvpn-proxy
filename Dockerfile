FROM alpine:3.21.0
LABEL MAINTAINER "Jeroen Slot"

ENV OVPN_FILES="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip" \
    OVPN_CONFIG_DIR="/app/ovpn/config" \
    SERVER_RECOMMENDATIONS_URL="https://api.nordvpn.com/v1/servers/recommendations" \
    CRON="*/15 * * * *" \
    CRON_OVPN_FILES="@daily"\
    PROTOCOL="tcp"\
    USERNAME="" \
    PASSWORD="" \
    COUNTRY="" \
    LOAD=75 \
    RANDOM_TOP="" \
    LOCAL_NETWORK="" \
    REFRESH_TIME="120"

COPY app /app
EXPOSE 8118

RUN \
    echo "####### Installing packages #######" && \
    apk --update --no-cache add \
      privoxy \
      openvpn \
      runit \
      bash \
      jq \
      ncurses \
      curl \
      unzip \
      && \
    echo "####### Changing permissions #######" && \
      find /app -name run | xargs chmod u+x && \
      find /app -name *.sh | xargs chmod u+x \
      && \
    echo "####### Removing cache #######" && \
      rm -rf /var/cache/apk/*

CMD ["runsvdir", "/app"]

# The old wp-admin/admin-ajax?action=get_user_info_data page was retired by NordVPN.
# Use the v1 "insights" helper through the proxy: .protected is true only when the
# request egresses via a NordVPN server.
HEALTHCHECK --interval=1m --timeout=10s \
  CMD if [[ $( curl -s -x localhost:8118 https://api.nordvpn.com/v1/helpers/ips/insights | jq -r '.["protected"]' ) = "true" ]] ; then exit 0; else exit 1; fi

