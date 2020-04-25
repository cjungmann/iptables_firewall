#!/bin/bash

# 2020-04-25
# While trying to create a program for generating an IPTABLEs
# script, I needed to get one working for Matthew (so he would
# stop hijacking the firewall).  This new script is the result
# of that effort.

# 2015-07-19
# Starting with good_basic_iptables.sh, this script is
# adding the function update_namecheap() immediately following,
# and, at the end, a comparison of this to previous external
# IP addresses.  If a change is detected, we will call update_namecheap
# change the registered IP address.

source nif_info


# Get password from NameCheap by going to Modify Domain, clicking on
# "Dynamic DNS" near bottom of left column, then "Enable" or "Re-enable"
# Dynamic DNS to get a new password.  The new password should be recorded
# below:
domain=cpjsoft.com
password=7230674874b34d1380323ee221da4aea

function update_namecheap()
{
    host=$1
    if [ -n ${host} ]
    then
        wget https://dynamicdns.park-your-domain.com/update?host=${host}&domain=${domain}&password=${password}
    fi
}

is_root() { [ "$USER" = "root" ]; }

# Start of what is in good_basic_iptables.sh:

IPTABLES=/sbin/iptables
MODPROBE=/sbin/modprobe

lamphost=192.168.0.18

INT_NET=192.168.0.0/255.255.255.0
ETH_INT=lan
ETH_OUT=wan

prepare_iptables()
{
    ### flush existing rules
    $IPTABLES -F
    $IPTABLES -F -t nat
    $IPTABLES -F -t raw
    $IPTABLES -X
    $IPTABLES -P INPUT DROP
    $IPTABLES -P OUTPUT DROP
    $IPTABLES -P FORWARD DROP

    ### Connection tracking modules
    # $MODPROBE ip_conntrack
    # $MODPROBE ip_conntrack_ftp
    $MODPROBE nf_conntrack

    $MODPROBE iptable_nat
    $MODPROBE ip_nat_ftp
    $MODPROBE ipt_iprange

    #########################
    ###### INPUT CHAIN ######
    #########################

    # Accept SSH requests from the LAN-facing interface
    $IPTABLES -A INPUT -p tcp --dporpt 22 -i $ETH_INT -j ACCEPT

    # Log and drop invalid packets
    $IPTABLES -A INPUT -m state --state INVALID -j LOG --log-prefix "IPT DROP INVALID INVALID " --log-ip-options --log-tcp-options
    $IPTABLES -A INPUT -m state --state INVALID -j DROP

    # Accept packet from established connections
    $IPTABLES -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    ## anti-spoofing rules
    $IPTABLES -A INPUT -i $ETH_INT ! -s $INT_NET -j LOG --log-prefix "IPT DROP SPOOFED INPUT "
    $IPTABLES -A INPUT -i $ETH_INT ! -s $INT_NET -j DROP

    # Accept all new connections from LAN-facing interface
    $IPTABLES -A INPUT -i $ETH_INT -s $INT_NET --syn -m state --state NEW -j ACCEPT

    ##########################
    ###### OUTPUT CHAIN ######
    ##########################

    ## state tracking rules
    $IPTABLES -A OUTPUT -m state --state INVALID -j LOG --log-prefix "IPT DROP INVALID OUTPUT " --log-ip-options --log-tcp-options
    $IPTABLES -A OUTPUT -m state --state INVALID -j DROP
    $IPTABLES -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT



    ###########################
    ###### FORWARD CHAIN ######
    ###########################

    ## Log and drop invalid packets
    $IPTABLES -A FORWARD -m state --state INVALID -j LOG --log-prefix "IPT DROP INVALID FORWARD " --log-ip-options --log-tcp-options
    $IPTABLES -A FORWARD -m state --state INVALID -j DROP

    # Accept packets from established connections
    $IPTABLES -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

    ## anti-spoofing rules
    $IPTABLES -A FORWARD -i $ETH_INT ! -s $INT_NET -j LOG --log-prefix "IPT DROP SPOOFED FORWARD "
    $IPTABLES -A FORWARD -i $ETH_INT ! -s $INT_NET -j DROP


    ###### NAT Rules ######
    # Make the firewall look like it's the outside/internet:
    $IPTABLES -t nat -A POSTROUTING -s $INT_NET -o $ETH_OUT -j MASQUERADE

    # Route HTTP requests to lamphost:
    $IPTABLES -t nat -A PREROUTING -p tcp --dport 80 -i $ETH_OUT -j DNAT --to $lamphost:80

    # enable ip forwarding and dynamic addressing:
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv4/ip_dynaddr

}

if ! ETH_OUT=$( nif_find_external_name ); then
    echo "Failed to discern an external interface."
    exit 1
fi

if ! ETH_INT=$( nif_find_first_internal_name ); then
    echo "Failed to discern an internal interface."
    exit 1
fi

echo "ETH_OUT is $ETH_OUT"
echo "ETH_INT is $ETH_INT"

if ! is_root; then
    echo "You must be 'root' to run this script."
    exit 1
fi

