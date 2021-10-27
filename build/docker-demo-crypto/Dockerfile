FROM alpine
RUN apk --no-cache add ca-certificates
RUN apk add --no-cache bash wget jq curl
RUN wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.14.1/yq_linux_amd64"
RUN chmod +x /usr/local/bin/yq 

ADD /build/config/zoneinfo.zip /zoneinfo.zip
ENV ZONEINFO /zoneinfo.zip
COPY ./scripts /scripts
WORKDIR /scripts/exporters/crypto
ENTRYPOINT ./exporter.sh
