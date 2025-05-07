#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
/etc/init.d/frr start
tail -f /dev/null
