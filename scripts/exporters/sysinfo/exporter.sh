#!/usr/bin/env bash
# yes we know telegraf exists but this is way simpler YEET

CONFIG="config.yml"
influx_host="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Addr" -)"
influx_port="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Port" -)"
influx_token="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.AuthToken" -)"
influx_org="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Org" -)"
influx_bucket="$(cat $CONFIG | yq eval ".Exporter.InfluxHost.Bucket" -)"

sys_id="$(cat $CONFIG | yq eval ".Exporter.SysID" -)"
sleep_interval="$(cat $CONFIG | yq eval ".Exporter.Interval" -)"
epoch=0

echo "Starting cpu log.."
sar -u 5 > cpu.log &
sleep 2
echo "Starting disk log.."
# vda on mac, sda on linux
iostat -d sda 5 > disk.log &
sleep 2
echo "Starting network log.."
# wlp3s0 on physical
sar -n DEV --iface=eth0 5 > network.log &
sleep 6

while true; do

    raw_mem="$(free -m | tail -n 2 | head -n 1)"
    mem_arr=($(echo "$raw_mem" | tr ' ' '\n'))
    mem_used="${mem_arr[2]}"
    mem_free="${mem_arr[3]}"
    mem_avail="${mem_arr[6]}"
    mem_max="${mem_arr[1]}"

    raw_net="$(cat network.log | tail -n 1 | tr -d '\0')"
    net_arr=($(echo "$raw_net" | tr ' ' '\n'))
    net_in_rate="${net_arr[4]}"     # or 5
    net_out_rate="${net_arr[5]}"    # or 6

    # vda on mac, sda on linux
    raw_disk="$(cat disk.log | tail -n 2 | tr -d '\0')"
    disk_arr=($(echo "$raw_disk" | tr ' ' '\n'))
    disk_transaction_per_second="${disk_arr[1]}"
    disk_read_per_second="${disk_arr[2]}"
    disk_write_per_second="${disk_arr[3]}"

    if [ "$disk_transaction_per_second" == "tps" ]; then
        disk_transaction_per_second=0.0
    fi

    if [ "$disk_read_per_second" == "kB_read/s" ]; then
        disk_read_per_second=0.0
    fi

    if [ "$disk_write_per_second" == "kB_wrtn/s" ]; then
        disk_write_per_second=0.0
    fi

    raw_cpu="$(cat cpu.log | tail -n 1 | tr -d '\0')"
    cpu_arr=($(echo "$raw_cpu" | tr ' ' '\n'))
    cpu_user="${cpu_arr[2]}"    # or 3
    cpu_system="${cpu_arr[4]}"  # or 5
    cpu_idle="${cpu_arr[7]}"    # or 8

    # your device may vary
    # raw_df="$(df -h | grep sda3 | tr -d '%')"
    # docker demo = overlay
    raw_df="$(df -h | grep overlay | tr -d '%')"
    df_arr=($(echo "$raw_df" | tr ' ' '\n'))
    df_pct="${df_arr[4]}"

    uptime="$(echo "$(awk '{print $1}' /proc/uptime)" / 60 | bc)"

    current_ts="$(date +%s)"
    timestamp_padded="$(printf %-19s "$current_ts" | tr ' ' 0)"

    payload="$(printf '%s' \
        "sysinfo,sys_id=$sys_id " \
        "mem_used=$mem_used,mem_free=$mem_free,mem_max=$mem_max,mem_avail=$mem_avail," \
        "net_in_rate=$net_in_rate,net_out_rate=$net_out_rate," \
        "disk_tps=$disk_transaction_per_second,disk_rps=$disk_read_per_second,disk_wps=$disk_write_per_second," \
        "cpu_user=$cpu_user,cpu_system=$cpu_system,cpu_idle=$cpu_idle," \
        "df_pct=$df_pct," \
        "uptime=$uptime $timestamp_padded"
    )" 

    echo $payload

    curl --request POST \
        "http://$influx_host:$influx_port/api/v2/write?org=$influx_org&bucket=$influx_bucket&precision=ns" \
        --header "Authorization: Token $influx_token" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --header "Accept: application/json" \
        --data-binary "$payload"

    epoch=$((epoch+1))
    if [ $epoch -eq 100 ]; then
        truncate -s 0 cpu.log
        truncate -s 0 disk.log
        truncate -s 0 network.log
        epoch=0
    fi

    sleep "$sleep_interval"
done
