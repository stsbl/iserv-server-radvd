#!/bin/bash

. /usr/lib/iserv/cfg

# GNU uniq seems to handle input from two commands stupid
perl_uniq() {
  perl -e 'print sort keys %{{ map { $_ => 1 } <STDIN> }};'
}

# Determine internet interface
DEFIF="$(LC_ALL=C ip -6 route show default | awk '$1=="default" {print $5}' | 
  sed 's/^ppp[0-9]\+/ppp+/')"

# advert lan routes on all wan interfaces + default interfaces
[ -z "$DEFIF" ] || (for i in $( (netquery6 --global --uniquelocal --wan --format nic \
    --interface "$DEFIF"; \
    netquery6 --global --uniquelocal --format nic --interface "$DEFIF") | perl_uniq)
do
  echo "interface $i {"
  echo "  AdvSendAdvert on;"
  echo "  AdvDefaultLifetime 0;"
  echo
  echo "  MinRtrAdvInterval 3;"
  echo "  MaxRtrAdvInterval 10;"
  echo
  # advert all routes from routing table except the one on own interface
  for h in $(ip -6 route | grep -vE "(dev $i|^default|^local|^fe80)" | awk '{ print $1 }')
  do
    # make advertise to nat64 prefix on lan interface switchable
    if [ "$h" = "64:ff9b::/96" ]
    then
      [ $AdverstiseNAT64 ] || continue
    fi

    # append prefix 128 if none given
    # default to /128 prefix
    suffix=""
    if ! [[ $h =~ /[0-9]{1,3}$ ]]
    then
      suffix="/128"
    fi

    echo "  route $h$suffix {"
    echo "  };"
    echo
  done
  echo "};"
  echo
done)

IFs=($( (netquery6 --global --format nic --lan; netquery6 --uniquelocal --format nic --lan) | perl_uniq ))

if [[ ${#IFs[@]} -gt 0 ]]
then
  for i in ${IFs[@]}
  do
    # do not advert on default interface
    [ "$i" = "$DEFIF" ] && continue
    echo "interface $i {"
    echo "  AdvSendAdvert on;"
    echo
    echo "  AdvManagedFlag $(if [ $UseDHCPv6 ]; then echo "on"; else echo "off"; fi);"
    echo "  AdvOtherConfigFlag $(if [ $UseDHCPv6 ]; then echo "on"; else echo "off"; fi);"
    echo
    echo "  MinRtrAdvInterval 3;"
    echo "  MaxRtrAdvInterval 10;"
    echo
    echo "  AdvLinkMTU 1492;"
    echo
    for h in $(netquery6 -gl -f "prefix/length" -i "$i" | uniq)
    do
      echo "  prefix $h {"
      echo "    AdvOnLink on;"
      echo "    AdvAutonomous on;"
      echo "    DeprecatePrefix on;"
      # only adveriste route address if server it self has a default route
      echo -n "    AdvRouterAddr "
      if [ ! -z "$DEFIF" ]; then echo "on;"; else echo "off;"; fi      
      echo "  };"
      echo
    done
    for h in $(netquery6 -ul -f "prefix/length" -i "$i" | uniq)
    do
      echo "  prefix $h {"
      echo "    AdvOnLink on;"
      echo "    AdvAutonomous off;"
      # only adveriste route address if server it self has a default route
      echo -n "    AdvRouterAddr "
      if [ ! -z "$DEFIF" ]; then echo "on;"; else echo "off;"; fi
      echo "  };"
      echo
    done
    for d in $( (netquery6 --global --lan --format "ip" --interface "$i"; \
        netquery6 --uniquelocal --lan --format "ip" --interface "$i") )
    do
      echo "  RDNSS $d {"
      echo "    AdvRDNSSLifetime 10;"
      echo "  };"
      echo
    done
    echo "};"
    echo
  done
fi
