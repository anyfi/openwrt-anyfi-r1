#!/bin/sh
#
# Copyright (C) 2013-2015 Anyfi Networks AB
#
# This configuration script is licensed under the MIT License.
# See /LICENSE for more information.
#

# Get name of virtual Wi-Fi interface based on device and index number.
# anyfi_mac80211_name_iface <device> <index>
anyfi_mac80211_name_iface() {
	local device="$1"
	local idx="$2"

	# Map radioX => anyfiX-{0,1,2,3...}
	echo "$device" | sed "s/^.*\([0-9]\)\$/anyfi\1-$idx/"
}

# Get the mac80211 phy for a Wi-Fi device.
# anyfi_mac80211_get_phy <device>
anyfi_mac80211_get_phy() {
        local device=$1
	local path=$(config_get $device path)
        local cfg

        for cfg in $CONFIG_SECTIONS; do
		local ifname=$(config_get $cfg ifname)
		local phypath="/sys/devices/$path/net/$ifname/phy80211/name"

                if [ "$(config_get $cfg TYPE)" = wifi-iface ] && \
                   [ "$(config_get $cfg device)" = "$device" ] && \
		   [ -e "$phypath" ]
		then
			cat $phypath
			break
                fi
        done
}

# Allocate virtual Wi-Fi interfaces for anyfid.
# anyfi_mac80211_alloc_iflist <device> <bssids>
anyfi_mac80211_alloc_iflist() {
	local device="$1"
	local bssids="$2"
	local phy="$(anyfi_mac80211_get_phy $1)"
	local count=0
	local id

	if [ -z "$phy" ]; then
		echo "$device: failed to allocate interfaces on $phy" 1>&2
		return 1
	fi

	# Find the start value for the macidx global
	# variable used by mac80211_generate_mac()
	macidx=$(anyfi_get_vifs $device | wc -w)

	# Create interfaces and allocate MAC addresses
	for id in $(seq 0 $(($bssids - 1))); do
		local ifname mask mac

		ifname=$(anyfi_mac80211_name_iface "$device" $id)
		mac=$(mac80211_generate_mac $phy)

		iw phy $phy interface add $ifname type __ap || break
		ifconfig $ifname hw ether $mac || break
		macidx=$(($macidx + 1))
		count=$(($count + 1))
	done

	# Return the formatted iflist string
	[ "$count" -gt 0 ] && \
		echo $(anyfi_mac80211_name_iface "$device" 0)/$count
}

# Release virtual Wi-Fi interfaces allocated for anyfid.
# anyfi_mac80211_release_iflist <device>
anyfi_mac80211_release_iflist() {
	local ifbase=$(anyfi_mac80211_name_iface $1 "")
	local ifaces=$(ifconfig -a | grep -E -o '^[^ ]+' | grep $ifbase)
	local ifname

	# Remove our virtual interfaces
	for ifname in $ifaces; do
		ifconfig $ifname down
		iw dev $ifname del
	done
}

. /lib/netifd/wireless/mac80211.sh
