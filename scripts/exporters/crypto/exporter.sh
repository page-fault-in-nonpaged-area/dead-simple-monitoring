#!/usr/bin/env bash

CONFIG="config.yml"

debug="$(cat $CONFIG | yq eval ".Exporter.Debug" -)"
coin_list="$(cat $CONFIG | yq eval ".Exporter.Sources.Coingecko" -)"
coin_list_len="$(cat $CONFIG | yq eval ".Exporter.Sources.Coingecko | length" -)"
fiat_rate="$(cat $CONFIG | yq eval ".Exporter.FiatRate" -)"

influx_host="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Addr" -)"
influx_port="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Port" -)"
influx_token="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.AuthToken" -)"
influx_org="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Org" -)"
influx_bucket="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Bucket" -)"

sleep_interval="$(cat $CONFIG | yq eval ".Exporter.Interval" -)"

function sem200 {
   while [ "$(jobs | wc -l)" -ge 200 ]
   do
      sleep 1
   done
}

function process_line {
    local coin_data="$1"
    local coin_id="$2"
    local index="$3"
    local selector="$4"
    local selector_label="$5"
    local data="$(echo "$coin_data" | jq '.'"$selector"'['"$index"']')"
    local line=""
    if [ "$data" != "null" ]; then
        timestamp="$(echo "$data" | jq '.[0]')"
        local timestamp_padded="$(printf %-19s "$timestamp" | tr ' ' 0)"
        local value="$(echo "$data" | jq '.[1]')"
        line="crypto,coin_id=$coin_id $selector_label=$value $timestamp_padded"
    fi
    echo "$line"
}

function load_historical {
    for ((i=0;i<=coin_list_len-1;i++)); do
        local coin_id="$(echo "$coin_list" | yq eval ".$i.Id" -)"
        local current_ts="$(date +%s)"
        local coin_data="$(curl --silent -X 'GET' \
            'https://api.coingecko.com/api/v3/coins/'"$coin_id"'/market_chart/range?vs_currency=usd&from=1483228800&to='"$current_ts"'' \
            -H 'accept: application/json')"

        local data_length="$(echo "$coin_data" | jq '.prices | length')"
        for ((j=0;j<=data_length-1;j++)); do
            sem200
            (
                local price_line="$(process_line "$coin_data" "$coin_id" "$j" prices price)"
                local volume_line="$(process_line "$coin_data" "$coin_id" "$j" total_volumes volume)"
                local market_cap_line="$(process_line "$coin_data" "$coin_id" "$j" market_caps market_cap)"
                
                curl --request POST \
                "http://$influx_host:$influx_port/api/v2/write?org=$influx_org&bucket=$influx_bucket&precision=ns" \
                --header "Authorization: Token $influx_token" \
                --header "Content-Type: text/plain; charset=utf-8" \
                --header "Accept: application/json" \
                --data-binary '
                    '"$price_line"'
                    '"$volume_line"'
                    '"$market_cap_line"'
                '
                printf "processing %6s of %-6s historical records for %s\n" "$j" "$data_length" "$coin_id"
            ) & 
        done
        wait
    done
}

function update_coins {
    while true; do
        for ((i=0;i<=coin_list_len-1;i++)); do
            sem200
            (
                local coin_id="$(echo "$coin_list" | yq eval ".$i.Id" -)"
                local coin_data="$(curl --silent -X 'GET' 'https://api.coingecko.com/api/v3/coins/'"$coin_id"'' -H 'accept: application/json')"
                local coin_price="$(echo "$coin_data" | jq .market_data.current_price."$fiat_rate")"
                local coin_volume="$(echo "$coin_data" | jq .market_data.total_volume."$fiat_rate")"
                local coin_market_cap="$(echo "$coin_data" | jq .market_data.market_cap."$fiat_rate")"
                local coin_sentiment="$(echo "$coin_data" | jq .sentiment_votes_up_percentage)"
                local current_ts="$(date +%s)"
                local timestamp_padded="$(printf %-19s "$current_ts" | tr ' ' 0)"

                if [ "$debug" == "true" ]; then
                    echo 'writing crypto,coin_id='"$coin_id"' price='"$coin_price"',volume='"$coin_volume"',market_cap='"$coin_market_cap"',sentiment='"$coin_sentiment"' '"$timestamp_padded"''
                fi

                curl --request POST \
                "http://$influx_host:$influx_port/api/v2/write?org=$influx_org&bucket=$influx_bucket&precision=ns" \
                --header "Authorization: Token $influx_token" \
                --header "Content-Type: text/plain; charset=utf-8" \
                --header "Accept: application/json" \
                --data-binary 'crypto,coin_id='"$coin_id"' price='"$coin_price"',volume='"$coin_volume"',market_cap='"$coin_market_cap"',sentiment='"$coin_sentiment"' '"$timestamp_padded"''
            ) & 
        done
        wait
        sleep "$sleep_interval"
    done
}

load_historical
update_coins
