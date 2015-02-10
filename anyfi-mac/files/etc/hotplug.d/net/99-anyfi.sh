#!/bin/sh
#
# Copyright (C) 2015 Anyfi Networks AB
#
# This configuration script is licensed under the MIT License.
# See /LICENSE for more information.
#

# Only process add/remove events for WLAN interfaces
[ "$DEVTYPE" = wlan ] || exit 0

# Process the event
case "$ACTION" in
	add)
		TYPE=$(uci -q get anyfi.$INTERFACE)
		if [ "$TYPE" = radio ] || [ "$TYPE" = service ]; then
			/sbin/anyfi start $INTERFACE
		fi
		;;

	remove)
		/sbin/anyfi stop $INTERFACE
		;;
esac
