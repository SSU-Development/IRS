#!/bin/bash
archi=$(uname -m)

cp -r /irs/binaries/$archi/* /
chmod +x /bin/*
chmod +x /sbin/*
# KVS
chmod +x /opt/kvs/bin/*