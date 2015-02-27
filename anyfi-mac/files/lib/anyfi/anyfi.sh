#!/bin/sh
#
# Copyright (C) 2013-2015 Anyfi Networks AB.
#
# This configuration script is licensed under the MIT License.
# See /LICENSE for more information.
#
#
# Overview of the integration
# ===========================
#
# Anyfi.net software consists of two user space daemons; the radio head daemon
# anyfid and the tunnel termination daemon myfid. They communicate with each
# other and an SDWN controller to orchestrate the seamless user experience.
#
# The radio head daemon anyfid listens on a monitor interface to detect when
# a mobile device has come within range, and dynamically allocates a virtual
# access point for that device. Any and all Wi-Fi traffic on the virtual access
# point is then relayed, through a Wi-Fi over IP tunnel, to the device's home
# network. The integration is responsible for creating the monitor interface
# and the pool of virtual access points; anyfid handles the rest.
#
# The tunnel termination daemon myfid sits on the other side of the Wi-Fi over
# IP tunnel, making it possible to connect remotely to the local Wi-Fi network.
# It is up to the integration to configure myfid to authenticate remote
# devices with the same credentials that are used to authenticate devices
# locally. This is key to the seamless user experience.
#
# Myfid is also responsible for registering in the controller the MAC address
# of devices that connect locally, so that they will automatically be offered
# remote access whenever they come close to an access point running anyfid.
# However, when the user changes the WPA passphrase all associations between
# previously connected devices and the local Wi-Fi network should be removed.
# The integration does so by starting myfid with the --reset flag in this case.
#
# Below is the integration logic in pseudo code. If you need to integrate
# Anyfi.net software in your own firmware build environment you can find step
# by step instructions at http://anyfi.net/integration.
#
# After enabling a Wi-Fi device:
#   IF a controller is configured AND Anyfi.net is not disabled
#     ALLOCATE monitor interface and virtual access point pool for anyfid
#     START anyfid on the Wi-Fi device
#
# After enabling a Wi-Fi interface:
#   IF a controller is configured AND Anyfi.net is not disabled
#     GENERATE a config file for myfid
#
#     IF the WPA passphrase has changed
#       ADD the --reset flag to myfid arguments
#
#     START myfid on the Wi-Fi interface
#
# After disabling a Wi-Fi device:
#   STOP anyfid on the Wi-Fi device
#
# After disabling a Wi-Fi interface:
#   STOP myfid on the Wi-Fi interface
#
# NOTE1: The integration provides remote access to all Wi-Fi interfaces on the
#        system that have anyfi.enabled set to 1. Each interface will have
#        its own myfid daemon. There should however only be one anyfid daemon
#        per radio.
#
# NOTE2: On concurrent dual band routers each radio should have its own anyfid
#        daemon.
#
#
# Anyfi.net UCI data model
# ========================
#
# Remote access Wi-Fi interfaces are designated by their interface name,
# i.e. the ifname option must be set in the wireless UCI config. Anyfi.net
# parameters are stored in the anyfi UCI config, with refrences to the
# wireless config via the ifname. Guest access on Wi-Fi devices is handled
# in the same way, but uses a monitor interface in the wireless UCI config
# instead.
#
# Anyfi.net global parameters: anyfi.*
#
#   Name                Value        Default         Description
#   controller.hostname IP or FQDN   -               Controller IP or FQDN
#   controller.key      string       -               Controller key fingerprint
#   optimizer.key       string       -               Optimizer key fingerprint
#
# Wi-Fi device parameters: anyfi.<monitorif>.*
#
#   Name             Value   Default  Description
#   disabled         boolean       -  Enable/disable guest access on this radio
#   wan_ifname       ifname        -  Bind anyfid to a WAN interface IP address
#   wan_port         number        -  Bind anyfid to a UDP port
#   floor            0-100         5  Min backhaul and spectrum allocation
#   ceiling          0-100        75  Max backhaul and spectrum allocation
#   wan_uplink_bps   integer       -  WAN uplink capacity in bits/s
#   wan_downlink_bps integer       -  WAN downlink capacity in bits/s
#   max_bssids       integer       -  Max number of virtual interfaces to use
#   max_clients      integer       -  Max number of concurrent guest users
#
# Wi-Fi interface parameters: anyfi.<ifname>.*
#
#   Name             Value   Default  Description
#   disabled         boolean       -  Enable remote access on this network
#   wan_ifname       ifname        -  Bind myfid to a WAN interface IP address
#   wan_port         port          -  Bind myfid to a UDP port
#

# Daemon run dir for temporary files.
RUNDIR=/var/run

# Config file dir for persistent configuration files.
CONFDIR=/etc

##### Common utilities #######################################################

# Stop an Anyfi.net daemon gracefully
# anyfi_stop_daemon <pidfile>
anyfi_stop_daemon() {
	local pidfile="$1"

	kill -TERM $(cat $pidfile)
	for t in $(seq 0 5); do
		[ -e $pidfile ] || return 0
		sleep 1
	done

	echo "Timeout waiting for daemon assocated with $pidfile to exit" 1>&2
	kill -KILL $(cat $pidfile)
	rm -f $pidfile
	return 1
}

# Get the Wi-Fi device for a monitor interface used by anyfid.
# anyfi_get_device <ifname>
anyfi_get_device() {
	local pid file
	for file in $(find $RUNDIR -name 'anyfid-*.pid'); do
		pid=$(cat $file)
		cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ')
		if echo "$cmd" | grep -q -o " $1 "; then
			echo $(basename $file .pid | cut -d- -f2)
			break
		fi
	done
}

# Get the Wi-Fi interface list for a WLAN device.
# anyfi_get_vifs <device> [mode...]
anyfi_get_vifs() {
        local device=$1
	local filter=$2
        local vifs=""
        local cfg

        for cfg in $CONFIG_SECTIONS; do
                if [ "$(config_get $cfg TYPE)" = wifi-iface ] && \
                   [ "$(config_get $cfg device)" = "$device" ] && \
                   [ "$(config_get $cfg disabled)" != 1 ]
		then
			local m mode="$(config_get $cfg mode)"
			for m in "${filter:-$mode}"; do
				if [ "$m" = "$mode" ]; then
					append vifs "$cfg"
					break
				fi
			done
                fi
        done
        echo "$vifs"
}

##### Wi-Fi device handling ##################################################

# Get the channel for Wi-Fi device.
# anyfi_dev_get_channel <device>
anyfi_dev_get_channel() {
	local device="$1"
	local hwmode=$(config_get $device hwmode)
	local channel=$(config_get $device channel)

	if [ "$channel" = auto -o "$channel" = 0 ]; then
		case "$hwmode" in
		auto)
			channel=auto
			;;

		*b*|*g*)
			channel=auto2
			;;

		*a*)
			channel=auto5
			;;
		esac
	fi
	echo "$channel"
}

# Start the Anyfi.net radio head daemon anyfid on a device.
# anyfi_dev_start <type> <device> <monitor> <controller> <controller_key>
anyfi_dev_start()
{
	local type="$1"
	local device="$2"
	local monitor="$3"
	local controller="$4"
	local controller_key="$5"
	local nvifs bssids monitor iflist

	# Determine how many virtual interfaces we should use
	bssids=$(uci -q get anyfi.$monitor.max_bssids)
	nvifs=$(anyfi_get_vifs "$device" ap wds mesh | wc -w)

	if [ -n "$bssids" ]; then
		# Limit the number of virtual interfaces to 32
		[ "$bssids" -lt 32 ] || bssids=32
	elif [ $nvifs -lt 4 ]; then
		# Don't use more that 8 interfaces in total if possible...
		bssids=$((8 - $nvifs))
	else
		# ...but try to allocate at least 4 interfaces for anyfid.
		bssids=4
	fi

	# ALLOCATE the monitor interface and a pool of virtual access points
	if iflist=$(anyfi_${type}_alloc_iflist "$device" $bssids); then
		local floor=$(uci -q get anyfi.$monitor.floor)
		local ceiling=$(uci -q get anyfi.$monitor.ceiling)
		local wanif=$(uci -q get anyfi.$monitor.wan_ifname)
		local port=$(uci -q get anyfi.$monitor.wan_port)
		local uplink=$(uci -q get anyfi.$monitor.wan_uplink_bps)
		local downlink=$(uci -q get anyfi.$monitor.wan_downlink_bps)
		local clients=$(uci -q get anyfi.$monitor.max_clients)
		local args=""

		# If there are no interfaces on this device then
		# anyfid controls channel
		if [ "$nvifs" -eq 0 ]; then
			args="$args --channel=$(anyfi_dev_get_channel $device)"
		fi

		[ -n "$wanif"    ] && args="$args --bind-if=$wanif"
		[ -n "$port"     ] && args="$args --bind-port=$port"
		[ -n "$floor"    ] && args="$args --floor=$floor"
		[ -n "$ceiling"  ] && args="$args --ceiling=$ceiling"
		[ -n "$uplink"   ] && args="$args --uplink=$uplink"
		[ -n "$downlink" ] && args="$args --downlink=$downlink"
		[ -n "$clients"  ] && args="$args --max-clients=$clients"
		[ -n "$controller_key" ] && \
			args="$args --controller-key=$controller_key"

		# START anyfid
		echo "$device: starting Anyfi.net radio head daemon anyfid"
		/usr/sbin/anyfid --accept-license -C "$controller" -B \
		             -P $RUNDIR/anyfid-$device.pid $args \
			     $monitor $iflist
	else
		echo "$device: failed to allocate anyfid interfaces" 1>&2
	fi
}

##### Wi-Fi interface handling ###############################################

# Generate the config file for myfid from UCI variables.
# anyfi_vif_gen_config <iface>
anyfi_vif_gen_config() {
	local iface="$1"
	local ifname="$(config_get $iface ifname)"
	local device="$(config_get $iface device)"
	local network="$(config_get $iface network)"
	local ssid="$(config_get $iface ssid)"
	local encryption="$(config_get $iface encryption)"
	local key="$(config_get $iface key)"
	local isolate="$(config_get $iface isolate)"

	# Check basic settings before proceeding
	[ -n "$network" ] || [ -n "$ssid" ] || return 1

	local auth_proto auth_mode auth_cache group_rekey
	local ciphers wpa_ciphers rsn_ciphers passphrase
	local auth_server auth_port auth_secret
	local acct_server acct_port acct_secret

	# Resolve explicit cipher overrides (tkip, ccmp or tkip+ccmp)
	case "$encryption" in
	*+tkip+ccmp|*+tkip+aes)
		ciphers=tkip+ccmp
		;;

	*+ccmp|*+aes)
		ciphers=ccmp
		;;

	*+tkip)
		ciphers=tkip
		;;
	esac

	# Resolve authentication protocol (WPA or WPA2)
	case "$encryption" in
	psk-mixed*|wpa-mixed*)
		auth_proto=wpa+rsn
		wpa_ciphers=$ciphers
		rsn_ciphers=$ciphers
		;;

	psk2*|wpa2*)
		auth_proto=rsn
		rsn_ciphers=$ciphers
		;;

	psk*|wpa*)
		auth_proto=wpa
		wpa_ciphers=$ciphers
		;;

	none)
		echo "$ifname: Anyfi.net does not provide remote access to open networks for security reasons" 1>&2
		return 1
		;;

	wep*)
		echo "$ifname: Anyfi.net does not provide remote access to WEP networks for security reasons" 1>&2
		return 1
		;;

	*)
		echo "$ifname: unrecognized encryption type $encryption" 1>&2
		return 1
		;;
	esac

	# Resolve authenticator mode (PSK or 802.1X)
	case "$encryption" in
	psk*)
		auth_mode=psk
		passphrase=$key
		[ -n "$passphrase"  ] || return 1
		;;

	wpa*)
		auth_mode=eap

		auth_server="$(config_get $iface auth_server)"
		auth_port="$(config_get $iface auth_port)"
		auth_secret="$(config_get $iface auth_secret)"

		acct_server="$(config_get $iface acct_server)"
		acct_port="$(config_get $iface acct_port)"
		acct_secret="$(config_get $iface acct_secret)"

		auth_cache="$(config_get $iface auth_cache)"
		group_rekey="$(config_get $iface wpa_group_rekey)"

		[ -n "$auth_server" ] || return 1
		;;

	none)
		;;

	*)
		echo "$name: Anyfi.net requires explicit 'encryption' configuration" 1>&2
		return 1
		;;
	esac

	# Generate common config file options
	cat <<EOF
ssid = '$ssid'
bridge = br-$network
auth_proto = $auth_proto
EOF

	# Generate dependent config file options
	[ "$isolate" = 1     ] && echo "isolation = 1"
	[ -n "$ifname"       ] && echo "local_ap = $ifname"
	[ -n "$auth_mode"    ] && echo "auth_mode = $auth_mode"
	[ -n "$auth_cache"   ] && echo "auth_cache = $auth_cache"
	[ -n "$rsn_ciphers"  ] && echo "rsn_ciphers = $rsn_ciphers"
	[ -n "$wpa_ciphers"  ] && echo "wpa_ciphers = $wpa_ciphers"
	[ -n "$group_rekey"  ] && echo "group_rekey = $group_rekey"
	[ -n "$passphrase"   ] && echo "passphrase = '$passphrase'"
	if [ -n "$auth_server" ]; then
		echo "radius_auth_server = $auth_server"
		echo "radius_auth_port = ${auth_port:-1812}"
		echo "radius_auth_secret = ${auth_secret:-$key}"
	fi
	if [ -n "$acct_server" ]; then
		echo "radius_acct_server = $acct_server"
		echo "radius_acct_port = ${acct_port:-1813}"
		echo "radius_acct_secret = ${acct_secret:-$key}"
	fi
	return 0
}

# Get the current value from a myfid configuration file.
# anyfi_vif_get_config <file> <config>
anyfi_vif_get_config() {
	local file="$1"
	local key="$2"

	[ -e "$file" ] || return 1

	# Assume the format is exactly "key = value",
	# where value may or may not be in ''
	grep "$key = " $file | cut -d '=' -f2- | cut -b2- | \
		               sed -e "/^'.*'$/s/^'\\(.*\\)'$/\\1/"
}

# Start the Anyfi.net tunnel-termination daemon myfid on an interface.
# anyfi_vif_start <iface> <controller> <controller_key> <optimizer_key>
anyfi_vif_start() {
	local iface="$1"
	local controller="$2"
	local controller_key="$3"
	local optimizer_key="$4"

	local ifname=$(config_get $iface ifname)
	local pid_file="$RUNDIR/myfid-$ifname.pid"
	local conf_file="$CONFDIR/myfid-$ifname.conf"
	local new_conf_file="$RUNDIR/myfid-$ifname.conf"

	# GENERATE a config file for myfid
	if (anyfi_vif_gen_config $iface) > $new_conf_file; then
		local wanif=$(uci -q get anyfi.$ifname.wan_ifname)
		local port=$(uci -q get anyfi.$ifname.wan_port)
		local args=""

		# ADD optional arguments
		[ -n "$wanif" ] && args="$args --bind-if=$wanif"
		[ -n "$port"  ] && args="$args --bind-port=$port"
		[ -n "$controller_key" ] && \
			args="$args --controller-key=$controller_key"
		[ -n "$optimizer_key" ] && \
			args="$args --optimizer-key=$optimizer_key"

		# ADD the --reset flag to myfid arguments if the passphrase
		# has changed or myfid is started for the first time
		local new_key="$(config_get $iface key)"
		local old_key="$(anyfi_vif_get_config $conf_file passphrase)"
		[ "$new_key" == "$old_key" ] || args="$args --reset"

		# Update the myfid config file in flash only if needed
		if ! cmp -s $new_conf_file $conf_file; then
			mv $new_conf_file $conf_file
		else
			rm -f $new_conf_file
		fi

		# START myfid
		echo "$ifname: starting Anyfi.net tunnel-termination daemon myfid"
		/usr/sbin/myfid --accept-license -C "$controller" -B -P $pid_file \
		            $args $conf_file
	fi
}

##### Main start/stop functions ##############################################

# Start Anyfi.net guest access on a Wi-Fi device. The config handle
# is an UCI config section for the monitor interface to use.
# anyfi_enable_device <config> <controller> <controller_key>
anyfi_start_radio() {
	local device=$(config_get $1 device)
	local ifname=$(config_get $1 ifname)
	local type=$(config_get $device type)

	if [ "$(config_get $device disabled)" = 1 ]; then
		echo "$device: not starting Anyfi.net on disabled device"
        elif [ -e /lib/anyfi/anyfi_$type.sh ]; then
		anyfi_dev_start $type $device $ifname $2 $3
	else
		echo "Anyfi.net is not supported by the $type driver" 1>&2
	fi
}

# Start Anyfi.net remote access on a Wi-Fi interface. The config handle
# is an UCI config section for the Wi-Fi interface to replicate.
# anyfi_enable_device <config> <controller> <controller_key> <optimizer_key>
anyfi_start_service() {
	local device=$(config_get $1 device)
	local ifname=$(config_get $1 ifname)

	if [ "$(config_get $device disabled)" = 1 ] ||
	   [ "$(config_get $ifname disabled)" = 1 ]
	then
		echo "$ifname: not starting Anyfi.net on disabled interface"
	else
		anyfi_vif_start "$@"
	fi
}

# Stop Anyfi.net guest access on a Wi-Fi device.
# anyfi_stop_radio <monitor>
anyfi_stop_radio() {
	local device=$(anyfi_get_device $1)
	local type=$(config_get $device type)

	if [ -n "$device" ]; then
		echo "$device: stopping Anyfi.net radio head daemon anyfid"
		anyfi_stop_daemon $RUNDIR/anyfid-$device.pid
		anyfi_${type}_release_iflist $device
	fi
}

# Stop Anyfi.net guest access on a Wi-Fi interface.
# anyfi_stop_service <ifname>
anyfi_stop_service() {
	local ifname=$1

	if [ -e $RUNDIR/myfid-$ifname.pid ]; then
		echo "$ifname: stopping Anyfi.net tunnel termination daemon myfid"
		anyfi_stop_daemon $RUNDIR/myfid-$ifname.pid
	fi
}

. /lib/anyfi/anyfi_*.sh
. /lib/functions.sh
config_load wireless
