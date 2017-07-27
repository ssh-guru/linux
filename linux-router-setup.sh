#!/bin/bash

###########################
###### COMMENT PART #######
###########################

# Linux Router deployment cript for Debian, Redhat and Arch based ditributions
# Created by Vlku 27/7/2017 - vlku@null.net

# This script will work on all distributions based on Debian, Redhat or Arch
# (Ubuntu, Fedora, Manjaro, Mint, Gentoo, Kubuntu, Zorin, RemixOS etc.)
# IT is not bulletproof but it will probably work if you simply want to setup a
# routing for your environment on your Linux box. Script will work on both
# physical and virtual machines. It has been designed to be as unobtrusive and
# universal as possible.

# This script requires two active ethernet adapters. One of which should have
# access to the Internet (may be NATed - in that case supply the privite NAT IP
# as WAN IP later on), while the other can be disconnected while the script starts.

###########################
##### MAIN CODE PART ######
###########################

# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit 1
fi

# Check if script was run with sudo or root account
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 2
fi

# Try to get our IP from the system and fallback to the Internet.
# I do this to make the script compatible with NATed servers (lowendspirit.com)
# and to avoid getting an IPv6.
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
		IP=$(wget -4qO- "http://whatismyip.akamai.com/")
fi

# Getting info required for installation
clear
	echo 'Welcome to Linux Router deployment script by Vlku - bitbucket.org/vlku'
	echo 'Any questions, please email me at vlku@null.net'
	echo ""
	# Public IP interface and address
	echo "I need to ask you a few questions before starting the setup"
	echo "You can leave the default options and just press enter if you are ok with them"
	echo ""
	echo "First I need to know the IPv4 address of the WAN interface"
	read -p "IP address: " -e -i $IP IP
  echo ""
  echo "Which ethernet port should act as WAN interface?"
	read -p "Interface [examples: eth0, ens32]: " -e -i eth0 WANinterface
    if [[(ip link "$WANinterface") == *"does not exist."*]]
      echo "Interface name incorrect. The script will now exit."
      exit
    fi
  echo ""
  echo "Which ethernet port should act as LAN interface and default gateway for"
  echo "the clients?"
	read -p "Interface [examples: eth1, ens64]: " -e -i eth1 LANinterface
  if [[(ip link "$LANinterface") == *"does not exist."*]]
    echo "Interface name incorrect. The script will now exit."
    exit
  fi
  echo ""

# Setting up the interface addressing with the gathered information
rm /etc/network/interfaces
touch /etc/network/interfaces
echo "# The loopback network interface
auto lo eth0
iface lo inet loopback

pre-up iptables-restore < /etc/iptables.rules

# The external WAN interface
allow-hotplug "$WANinterface"
iface eth0 inet statis
  address "$IP"

# The internal LAN interface (eth1)
allow-hotplug "$LANinterface"
iface eth1 inet static
   address 172.18.0.1
   netmask 255.255.255.0
   network 172.18.0.0
   broadcast 172.18.0.255" > /etc/network/interfaces

# DNS configuration
echo "nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.conf

echo "Do you want this router to also act as DHCP server for the network?"
read -p "''y' - yes; 'n' - no: " -e -i y DNS
if [[ "$DNS" == "y" ]]; then
  # Detects package manager
  declare -A osInfo;
  osInfo[/etc/redhat-release]="yum -y install"
  osInfo[/etc/arch-release]="yes | pacman -S"
  osInfo[/etc/debian_version]="apt-get install -y"

  # Installs DNSmasq (DHCP server)
  for f in ${!osInfo[@]}
  do
      if [[ -f $f ]];then
          ${osInfo[$f]} dnsmasq
      fi
  done

  # Configures DNSmasq
  echo "interface="$LANinterface"
  listen-address=127.0.0.1
  dhcp-range=172.18.0.100,172.18.0.200,12h" > /etc/dnsmasq.conf
fi

# Enables IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Configures default iptables rules in a backup file
echo "*nat
# NAT
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT

*filter
# Firewall
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i eth0 -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -i eth0 -j DROP
COMMIT" > /etc/iptables.rules

# Activates the default iptables rules
iptables-restore < /etc/iptables.rules
