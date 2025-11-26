#!/bin/bash

. /usr/lib/iserv/cfg

# Determine internet interface
DEFIF="$(. /usr/lib/iserv/ipv6_defif)"

# advertise lan routes on all wan interfaces + default interfaces
! [ "$RadvdAdvertiseOnDefIf" ] || [ -z "$DEFIF" ] || (for i in $(netquery6 -i "$DEFIF" -ug nic | sort | uniq)
do
  echo "interface $i {"
  echo "  AdvSendAdvert on;"
  echo "  AdvDefaultLifetime 0;"
  echo
  echo "  MinRtrAdvInterval 3;"
  echo "  MaxRtrAdvInterval 10;"
  echo

  ROUTES=($(ip -6 route | grep -vE "(^none |dev $i |dev lo |^default|^local|^fe80)" | awk '{ print $1 }'))

  # advertise all routes from routing table except the one on own interface
  for h in "${ROUTES[@]}"
  do
    # make advertise to nat64 prefix on lan interface switchable
    if [ "$h" = "64:ff9b::/96" ]
    then
      [ "$AdverstiseNAT64" ] || continue
    fi

    # append prefix 128 if none given
    # default to /128 prefix
    suffix=""
    if ! [[ "$h" =~ /[0-9]{1,3}$ ]]
    then
      suffix="/128"
    fi

    echo "  route $h$suffix {"
    echo "    RemoveRoute on;"
    echo "    AdvRouteLifetime 60;"
    echo "  };"
    echo
  done
  echo "};"
  echo
done)

IFs=($(netquery6 -gul nic | sort | uniq))

if [[ "${#IFs[@]}" -gt 0 ]]
then
  for i in "${IFs[@]}"
  do
    # do not advert on default interface
    [ "$i" = "$DEFIF" ] && continue
    cat <<EOT
interface $i {
  AdvSendAdvert on;
  # Default lifetime must be at least one hour (default value would be
  # MaxRtrAdvInterval) or Android does not set announced default route
  AdvDefaultLifetime 3630;

  AdvManagedFlag on;
  AdvOtherConfigFlag on;

  MinRtrAdvInterval 3;
  MaxRtrAdvInterval 10;

  AdvLinkMTU 1492;

EOT
    if netquery6 -i "$i" -gulq
    then
      cat <<EOT
  # Note: This causes the warning "invalid all-zeros prefix in /etc/radvd.conf"
  # which can be safetly ignored due to false positive:
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=891324
  prefix ::/64 {
    AdvOnLink on;
    AdvAutonomous on;
    DeprecatePrefix on;
    AdvRouterAddr $(
      if [ -n "$DEFIF" ]
      then
        echo -n "on"
      else
        echo -n "off"
      fi);

    # Minimum allowed lifetime (2h) according to RFC 4862, Section 5.5.3 plus
    # 30 seconds
    AdvValidLifetime 7230;
    AdvPreferredLifetime 60;
  };

EOT
      echo "};"
      echo
    fi
  done
fi
