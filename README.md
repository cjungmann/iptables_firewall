# IPTables Firewall Project

After having used a DIY firewall I put together in around
2007, circumstances (COVID-19 social-distancing) have provided
an opportunity to rething my firewall.

This project will provide a much better environment for managing
my firewall.  If there is no other improvement, having the IPTables
rules under source control will increase the safety of experimenting
with different IPTables ideas.

I expect that the scripts will be BASH scripts, as it's the most
direct way to interact with the CLI interface of IPTables.

## Requirements

The firewall will also be a DHCP server.  I will include a link
to a page that seems helpful now, and I may add additional pages
if needed and they merit.

[Raspberry PI DHCP Server](http://www.noveldevices.co.uk/rp-dhcp-server)

## IPTables NAT

In an older NAT installation, one added a '1' to the *ip_forward*
and *ip_dynaddr* files in */proc/sys/net/ipv4* directory.  Newer
instructions, found in these [quick tips](https://www.revsys.com/writings/quicktips/nat.html)
informed me that I have to make changes in the
*/etc/sysctl.conf* file.  Look in *new_iptables* for the
*sed* script that makes the changes.