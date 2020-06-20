#!/bin/sh

sleep 5

while true; do
    server=`ps | grep -e "ipt2socks[[:space:]]" | grep -v grep`
    if [ ! "$server" ]; then
        /etc/storage/ipt2socks/ipt2socks -s 192.168.1.10 -p 12345 -b 0.0.0.0 -l 12345 -j4 -4 -r -R -T > /dev/null 2>&1 &
    fi
    sleep 30
done
