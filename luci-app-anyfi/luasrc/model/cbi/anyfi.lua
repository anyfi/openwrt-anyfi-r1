-- Copyright (C) 2015 Anyfi Networks AB
--
-- This file is licensed under the MIT License.
-- See /LICENSE for more information.

m = Map("anyfi", "Anyfi.net",
	translate("Here you can configure Anyfi.net global settings. The " ..
		  "SDWN Controller manages the Anyfi.net software and is " ..
		  "required for guest access and remote access."))

function m.on_commit(map)
	luci.sys.call("/sbin/anyfi start")
end

-- Controller configuration
s = m:section(NamedSection, "controller", "sdwn", "SDWN Controller")
s.anonymous = true

o = s:option(Value, "hostname", translate("Hostname or IP address"))
o.datatype = "host"
o.placeholder = "demo.anyfi.net"
o.rmempty = true

o = s:option(Value, "key", translate("Controller key"))
o.datatype = "and(hexkey,minlength(16))"
o.rmempty = true

-- Optimizer configuration
s = m:section(NamedSection, "optimizer", "sdwn", "SDWN Optimizer")
s.anonymous = true

o = s:option(Value, "key", "Optimizer key")
o.datatype = "and(hexkey,minlength(16))"
o.rmempty = true

return m