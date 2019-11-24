--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <https://github.com/lisaac/luci-app-diskman>
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
  http://www.apache.org/licenses/LICENSE-2.0
$Id$
]]--
require "luci.util"
require("luci.tools.webadmin")
local dm = require "luci.model.diskman"
local dev = arg[1]

if not dev then
  return
elseif not nixio.fs.access("/dev/"..dev) then
  return
end

m = SimpleForm("partition", translate("Partition Management"), translate("Partition Disk over LuCI."))
m.redirect = luci.dispatcher.build_url("admin/system/diskman")
-- disable submit and reset button
m.submit = false
m.reset = false

local d_info = dm.get_device_info(dev)
local format_cmd = dm.get_format_cmd()

s = m:section(Table, d_info, translate("Device Info"))
-- s:option(DummyValue, "key")
-- s:option(DummyValue, "value")
s:option(DummyValue, "path", translate("Path"))
s:option(DummyValue, "model", translate("Model"))
s:option(DummyValue, "sn", translate("Serial Number"))
s:option(DummyValue, "size_formated", translate("Size"))
s:option(DummyValue, "temp", translate("Temp"))
s:option(DummyValue, "sec_size", translate("Sector Size "))
s:option(DummyValue, "p_table", translate("Partition Table"))
s:option(DummyValue, "sata_ver", translate("SATA Version"))
s:option(DummyValue, "rota_rate", translate("Rotation Rate"))
s:option(DummyValue, "health", translate("Health"))
s:option(DummyValue, "status", translate("Status"))

s_partition_table = m:section(Table, d_info.partition_info, translate("Partitions Info"), translate("Default 2048 sector alignment, support +size{b,k,m,g,t} in End Sector"))

s_partition_table:option(DummyValue, "number", translate("Number"))
s_partition_table:option(DummyValue, "name", translate("Name"))
local val_sec_start = s_partition_table:option(Value, "sec_start", translate("Start Sector"))
val_sec_start.render = function(self, section, scope)
  -- could create new partition
  if d_info.partition_info[section].number == "-" and d_info.partition_info[section].size > 1 * 1024 * 1024 then
    self.template = "cbi/value"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
local val_sec_end = s_partition_table:option(Value, "sec_end", translate("End Sector"))
val_sec_end.render = function(self, section, scope)
  -- could create new partition
  if d_info.partition_info[section].number == "-" and d_info.partition_info[section].size > 1 * 1024 * 1024 then
    self.template = "cbi/value"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
val_sec_start.forcewrite = true
val_sec_start.write = function(self, section, value)
  d_info.partition_info[section]._sec_start = value
end
val_sec_end.forcewrite = true
val_sec_end.write = function(self, section, value)
  d_info.partition_info[section]._sec_end = value
end
s_partition_table:option(DummyValue, "size_formated", translate("Size"))
s_partition_table:option(DummyValue, "useage", translate("Useage"))
s_partition_table:option(DummyValue, "mount_point", translate("Mount Point"))
local val_fs = s_partition_table:option(Value, "fs", translate("File System"))
val_fs.forcewrite = true
val_fs.write = function(self, section, value)
  d_info.partition_info[section]._fs = value
end
val_fs.render = function(self, section, scope)
  -- use listvalue when partition not mounted
  if d_info.partition_info[section].mount_point == "-" and d_info.partition_info[section].number ~= "-" then
    self.template = "cbi/value"
    self:reset_values()
    self.keylist = {}
    self.vallist = {}
    for k, v in pairs(format_cmd) do
      self:value(k,k)
    end
    -- self.default = d_info.partition_info[section].fs
  else
    self:reset_values()
    self.keylist = {}
    self.vallist = {}
    self.template = "cbi/dvalue"
  end
  DummyValue.render(self, section, scope)
end
btn_format = s_partition_table:option(Button, "_format")
btn_format.render = function(self, section, scope)
  if d_info.partition_info[section].mount_point == "-" and d_info.partition_info[section].number ~= "-" then
    self.inputtitle = "Format"
    self.template = "cbi/disabled_button"
    self.view_disabled = false
    self.inputstyle = "reset"
    for k, v in pairs(format_cmd) do
      self:depends("val_fs", "k")
    end
  -- elseif d_info.partition_info[section].mount_point ~= "-" and d_info.partition_info[section].number ~= "-" then
  --   self.inputtitle = "Format"
  --   self.template = "cbi/disabled_button"
  --   self.view_disabled = true
  --   self.inputstyle = "reset"
  else
    self.inputtitle = ""
    self.template = "cbi/dvalue"
  end
  Button.render(self, section, scope)
end
btn_format.forcewrite = true
btn_format.write = function(self, section, value)
  local partition_name = "/dev/".. d_info.partition_info[section].name
  if not nixio.fs.access(partition_name) then
    m.message = "Partition NOT found!"
    return
  end
  local fs = d_info.partition_info[section]._fs
  if not format_cmd[fs] then
    m.message = "Filesystem NOT support!"
    return
  end
  local cmd = format_cmd[fs].cmd .. " " .. format_cmd[fs].option .. " " .. partition_name
  -- luci.util.perror(cmd)
  local res = luci.sys.exec(cmd)
  luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman/partition/" .. dev))
end

local btn_action = s_partition_table:option(Button, "_action", translate("Action"))
btn_action.forcewrite = true
btn_action.template = "cbi/disabled_button"
btn_action.render = function(self, section, scope)
  -- if partition is mounted or the size < 1mb, then disable the action
  if d_info.partition_info[section].mount_point ~= "-" or d_info.partition_info[section].size < 1 * 1024 * 1024 then
    self.view_disabled = true
    -- self.inputtitle = ""
    -- self.template = "cbi/dvalue"
  else
    -- self.template = "cbi/disabled_button"
    self.view_disabled = false
  end
  if d_info.partition_info[section].number ~= "-" then
    self.inputtitle = translate("Remove")
    self.inputstyle = "remove"
  else
    self.inputtitle = translate("New")
    self.inputstyle = "add"
  end
  Button.render(self, section, scope)
end
btn_action.write = function(self, section, value)
  -- luci.util.perror(value)
  if value == "New" then
    local start_sec = d_info.partition_info[section]._sec_start and tonumber(d_info.partition_info[section]._sec_start) or tonumber(d_info.partition_info[section].sec_start)
    local end_sec = d_info.partition_info[section]._sec_end

    if start_sec then
      -- for sector alignment
      local align = tonumber(d_info.device_info.phy_sec) / tonumber(d_info.device_info.logic_sec)
      align = (align < 2048) and 2048
      if start_sec < 2048 then
        start_sec = "2048" .. "s"
      elseif math.fmod( start_sec, align ) ~= 0 then
        start_sec = tostring(start_sec + align - math.fmod( start_sec, align )) .. "s"
      else
        start_sec = start_sec .. "s"
      end
    else
      m.message = "Invalid Start Sector!"
      return
    end
    -- support +size format for End sector
    local end_size, end_unit = end_sec:match("^+(%d-)([bkmgtsBKMGTS])$")
    if tonumber(end_size) and end_unit then
      local unit ={
        B=1,
        S=512,
        K=1024,
        M=1048576,
        G=1073741824,
        T=1099511627776
      }
      end_unit = end_unit:upper()
      end_sec = tostring(tonumber(end_size) * unit[end_unit] / unit["S"] + tonumber(start_sec:sub(1,-2)) - 1 ) .. "s"
    elseif tonumber(end_sec) then
      end_sec = end_sec .. "s"
    else
      m.message = "Invalid End Sector!"
      return
    end
    -- create partition table if no partition table
    if d_info.device_info.p_table == "UNKNOWN" then 
      local cmd = "/usr/sbin/parted -s /dev/" .. dev .. " mktable gpt"
    end
    -- partiton
    local cmd = "/usr/sbin/parted -s -a optimal /dev/" .. dev .. " mkpart primary " .. start_sec .. " " .. end_sec
    -- luci.util.perror(cmd)
    local res = luci.util.exec(cmd)
    if res:match("Error.+") then
      m.message = res
    else
      luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman/partition/" .. dev))
    end
  elseif value == "Remove" then
    -- remove partition
    local number = tostring(d_info.partition_info[section].number)
    if (not number) or (number == "") then
      m.message = "Partition not exists!"
      return
    end
    local cmd = "parted -s /dev/" .. dev .. " rm " .. number
    local res = luci.util.exec(cmd)
    if res:match("Error.+") then
      m.message = res
    else
      luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman/partition/" .. dev))
    end
  end
end

return m