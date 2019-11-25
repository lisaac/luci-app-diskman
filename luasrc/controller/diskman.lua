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
module("luci.controller.diskman",package.seeall)

function index()
  -- check all used executables in disk management are existed
  local CMD = {"parted", "mdadm", "blkid", "smartctl"}
  local executables_all_existed = true
  for _, cmd in ipairs(CMD) do
    local command = luci.sys.exec("/usr/bin/which " .. cmd)
    if not command:match(cmd) then
      executables_all_existed = false
      break
    end
  end

  if executables_all_existed then
    -- entry(path, target, title, order)
    -- set leaf attr to true to pass argument throughe url (e.g. admin/system/disk/partition/sda)
    entry({"admin", "system", "diskman"}, alias("admin", "system", "diskman", "disks"), _("DiskMan"), 55)
    entry({"admin", "system", "diskman", "disks"}, form("diskman/disks"), nil).leaf = true
    entry({"admin", "system", "diskman", "partition"}, form("diskman/partition"), nil).leaf = true
    entry({"admin", "system", "diskman", "get_disk_info"}, call("get_disk_info"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "addpartition"}, call("action_addpartition"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "removepartition"}, call("action_removepartition"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "formatpartition"}, call("action_formatpartition"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "createraid"}, call("action_createraid"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "createpartitiontable"}, call("action_createpartitiontable"), nil).leaf = true
  --   entry({"admin", "system", "diskman", "removepartitiontable"}, call("action_removepartitiontable"), nil).leaf = true
  end
end

function get_disk_info(dev)
  if not dev then
    luci.http.status(500, "no device")
    luci.http.write_json("no device")
    return
  elseif not nixio.fs.access("/dev/"..dev) then
    luci.http.status(500, "no device")
    luci.http.write_json("no device")
    return
  end
  local dm = require "luci.model.diskman"
  local device_info = dm.get_disk_info(dev)
  luci.http.status(200, "ok")
  luci.http.prepare_content("application/json")
  luci.http.write_json(device_info)
end