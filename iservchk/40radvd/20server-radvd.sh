#!/bin/bash

# check if we have routes to announce
if [ "$(netquery6 -gul nic | sort | uniq | wc -l)" -gt 0 ]
then
  echo "Check /etc/radvd.conf"
  echo "Start radvd radvd"
else
  echo "Remove /etc/radvd.conf"
  echo "Stop radvd radvd"
fi
