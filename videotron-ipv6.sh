#!/bin/sh
# 6rd proof-of-concept for tomato-based firmware.
# Author: Alex Duchesne <alex@alexou.net>
# Homepage: http://blog.alexou.net/my-projects/videotron-ipv6-6rd-with-tomato/
# Tested only on toastman's miniipv6 builds
# Change Log:
# June 24, 2012 - Initial release
# August 16, 2013 - Support lower case in hexadecimal ip
# March 15, 2014  - Port to DD-WRT, simplification
#                   By Alexandre Blanchette <blanalex at gmail dot com>

set -v

wanif=`nvram get wan_ifname`

ip2bin() {
	if [ "${1#*.}" != "$1" ]; then # IPv4
		ip=$(printf '%02X%02X%02X%02X' $(echo $ip | tr . ' '))
		if [ $? -gt 0 ]; then
			return 1;
		fi
	else
		ip="$1"
	fi
	echo $ip | awk -v ORS="" '{ gsub(/./,"&\n") ; print toupper($0) }' | {
		buf=""
		while read char
		do
			case "$char" in 
			0) buf="${buf}0000" ;;
			1) buf="${buf}0001" ;;
			2) buf="${buf}0010" ;;
			3) buf="${buf}0011" ;;
			4) buf="${buf}0100" ;;
			5) buf="${buf}0101" ;;
			6) buf="${buf}0110" ;;
			7) buf="${buf}0111" ;;
			8) buf="${buf}1000" ;;
			9) buf="${buf}1001" ;;
			A) buf="${buf}1010" ;;
			B) buf="${buf}1011" ;;
			C) buf="${buf}1100" ;;
			D) buf="${buf}1101" ;;
			E) buf="${buf}1110" ;;
			F) buf="${buf}1111" ;;
			esac
		done

		if [ ${#buf} -eq 32 -o ${#buf} -eq 128 ]; then
			echo $buf
			return 0
		else
			return 2
		fi
	}
}

bin2ip() {
	echo $1 | awk -v ORS="" '{ gsub(/..../,"&\n") ; print }' | {
		pos=0
		buf=""
		while read char
		do
			if [ $(($pos % 4)) -eq 0 -a $pos -gt 0 ]; then
				buf="${buf}:"
			fi
			pos=$((pos+1))
			case "$char" in
				0000) buf="${buf}0" ;;
				0001) buf="${buf}1" ;;
				0010) buf="${buf}2" ;;
				0011) buf="${buf}3" ;;
				0100) buf="${buf}4" ;;
				0101) buf="${buf}5" ;;
				0110) buf="${buf}6" ;;
				0111) buf="${buf}7" ;;
				1000) buf="${buf}8" ;;
				1001) buf="${buf}9" ;;
				1010) buf="${buf}A" ;;
				1011) buf="${buf}B" ;;
				1100) buf="${buf}C" ;;
				1101) buf="${buf}D" ;;
				1110) buf="${buf}E" ;;
				1111) buf="${buf}F" ;;
			esac
		done

		echo $buf
		return 0
	}
}


# Someone decided it was a good idea to change the udhcpc patch in some firmware (toastman) and rename 
# the variable (and option name) ip6rd to 6rd, which is an illegal name... That's why we try both.

if [ -z "$interface" ]; then # Not called by udhcpc
	/sbin/udhcpc -fq -i $wanif -s $0 -O ip6rd
else #called by udhcpc
	if [ "$1" == "deconfig" ]; then
		echo "I'm working as expected!"
	elif [ "$1" == "bound" ]; then
		echo -n "Bound..."
		if [ -z "$ip6rd" ]; then 
			ip6rd=$(export | grep 'export 6rd='|sed "s/export 6rd='\(.*\)'[^']*$/\1/") 
		fi
		if [ -n "$ip6rd" ]; then
			echo "6rd :)"
			echo ip6rd "$ip6rd"
			echo ip6rd_ipv4masklen "${ip6rd_ipv4masklen=$(echo $ip6rd | awk '{print $1}')}"
			echo ip6rd_6rdprefixlen "${ip6rd_6rdprefixlen=$(echo $ip6rd | awk '{print $2}')}"
			echo ip6rd_6rdprefix "${ip6rd_6rdprefix=$(echo $ip6rd | awk '{print $3}')}"
			echo ip6rd_6rdbripv4address "${ip6rd_6rdbripv4address=$(echo $ip6rd | awk '{print $4}')}"
			echo --------------------------
			echo Calculating your settings:

			bin_ip6rd_6rdprefix=`ip2bin $ip6rd_6rdprefix`
			if [ $? -ne 0 ]; then
				echo "Unable to convert PREFIX IP to binary. Make sure it is in expanded form (::)" >&2
				exit 1
			fi
			
			echo bin_ip6rd_6rdprefix = [${bin_ip6rd_6rdprefix:0:$ip6rd_6rdprefixlen}]${bin_ip6rd_6rdprefix:$ip6rd_6rdprefixlen}
			
			bin_wanip=`ip2bin $ip`
			if [ $? -ne 0 ]; then
				echo "Unable to convert WAN IP to binary. Make sure it is in expanded form (::)" >&2
				exit 1
			fi
			
			echo bin_wanip = ${bin_wanip:0:$ip6rd_ipv4masklen}[${bin_wanip:$ip6rd_ipv4masklen}]
			
			bin_client_prefix="${bin_ip6rd_6rdprefix:0:$ip6rd_6rdprefixlen}${bin_wanip:$ip6rd_ipv4masklen}"
			
			echo bin_client_prefix = ${bin_client_prefix}
			
			client_prefix_length=${#bin_client_prefix}
			echo $client_prefix_length
			
			if [ $((${client_prefix_length} % 16)) -ne 0 ]; then
					client_prefix=`bin2ip $(printf "%-$((${client_prefix_length}+(16-(${client_prefix_length} % 16))))s" $bin_client_prefix|sed s/\ /0/g)`
					if [ ${#client_prefix} -lt 39 ]; then
                        client_prefix=${client_prefix}::
					fi
			fi
			
			echo --------------------------
			echo 6in4 static tunnel settings:

			echo "Assigned / Routed Prefix = ${client_prefix}"
			echo "Prefix Length = ${client_prefix_length}"
			echo "Router IPv6 Address = Default"
			echo "Enable Router Advertisements = yes"
			echo "Tunnel Remote Endpoint (IPv4 Address) = ${ip6rd_6rdbripv4address}"
			echo "Tunnel Client IPv6 Address = ${client_prefix} / $client_prefix_length"

			WANIP="$(ifconfig $wanif | sed -rn 's/.*r:([^ ]+) .*/\1/p')"
			if [ -n "$WANIP" ]; then 
				ip tunnel add tun6rd mode sit ttl 64 local $WANIP
				ip link set tun6rd mtu 1280
				ip link set tun6rd up
				ip addr add ${client_prefix}1/${ip6rd_6rdprefixlen} dev tun6rd
				ip addr add ${client_prefix}1/${client_prefix_length} dev br0
				ip -6 route add 2000::/3 via ::$ip6rd_6rdbripv4address dev tun6rd
				
                # router advertisements work better when the mask is a multiple of 8
                if [ $(($client_prefix_length % 8)) -ne 0 ] ; then
                    rounded_prefix_length=$((($client_prefix_length / 8 + 1) * 8))
                else
                    rounded_prefix_length=$client_prefix_length
                fi

				cat > /tmp/radvd.conf << EOF
interface br0 {
	MinRtrAdvInterval 3;
	MaxRtrAdvInterval 10;
	AdvLinkMTU 1280;
	AdvSendAdvert on;
	prefix $client_prefix/$rounded_prefix_length {
		AdvOnLink on;
		AdvAutonomous on;
		AdvValidLifetime 86400;
		AdvPreferredLifetime 86400;
	};
};
EOF
				radvd -C /tmp/radvd.conf
			fi
		else
			echo "but no 6rd :("
		fi
	else
		echo "Something strange happened: $1"
	fi
fi
