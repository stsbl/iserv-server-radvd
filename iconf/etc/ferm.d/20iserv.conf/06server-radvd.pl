#!/usr/bin/perl -CSDAL

use warnings;
use strict;

print "domain (ip6) {\n";
print "  table raw {\n";
print "    chain prerouting_linklocal {\n";
print "      # Prevent reading of our own route advertisements by dumb daemons like rdnssd\n";
for (split /\n/, qx(netquery6 -p -f "ip\tnic"))
{
  my ($ip, $nic) = split /\t/;
  print "     proto ipv6-icmp icmpv6-type (133 134) saddr \@ipfilter($ip) ".
      "interface $nic jump DROP;\n";
}
print "    }\n";
print "  }\n";
print "}\n";
print "\n";

