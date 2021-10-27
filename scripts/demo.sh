#!/usr/bin/env bash

docker build -t page-fault-in-nonpaged-area/crypto-exporter:latest -f build/docker-demo-crypto/Dockerfile .
docker build -t page-fault-in-nonpaged-area/sysinfo-exporter:latest -f build/docker-demo-sysinfo/Dockerfile .
cd deploy/compose-local-demo && docker-compose up -d #--force-recreate
