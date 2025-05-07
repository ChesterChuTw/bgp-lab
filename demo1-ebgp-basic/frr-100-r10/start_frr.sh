#!/bin/bash
# sysctl -w net.ipv4.ip_forward=1
/usr/lib/frr/frrinit.sh start
tail -f /dev/null