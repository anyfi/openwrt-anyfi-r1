-- Copyright (C) 2015 Anyfi Networks AB
--
-- This file is licensed under the MIT License.
-- See /LICENSE for more information.

module("luci.controller.anyfi", package.seeall)

function index()
   entry({"admin", "system", "anyfi"},
	 cbi("anyfi"), "Anyfi.net", 30).dependent = false
end
