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

-- Use (non-UCI) SimpleForm since we have no related config file
m = SimpleForm("diskman", translate("DiskMan"), translate("Manage Disks over LuCI."))
-- m:append(Template("diskman/disk_info"))
-- disable submit and reset button
m.submit = false
m.reset = false

-- disks
local disks = dm.list_devices()
d = m:section(Table, disks, translate("Disks"))
d.config = "disk"
-- option(type, id(key of table), text)
d:option(DummyValue, "path", translate("Path"))
d:option(DummyValue, "model", translate("Model"))
d:option(DummyValue, "sn", translate("Serial Number"))
d:option(DummyValue, "size_formated", translate("Size"))
d:option(DummyValue, "temp", translate("Temp"))
-- d:option(DummyValue, "sec_size", translate("Sector Size "))
d:option(DummyValue, "p_table", translate("Partition Table"))
d:option(DummyValue, "sata_ver", translate("SATA Version"))
-- d:option(DummyValue, "rota_rate", translate("Rotation Rate"))
d:option(DummyValue, "health", translate("Health"))
d:option(DummyValue, "status", translate("Status"))

-- edit = d:option(Button, "partition", translate("Edit Partition"))
-- edit.inputstyle = "edit"
-- edit.inputtitle = "Edit"
-- -- overwrite write function to add click event function
-- -- however, this function will be executed after built-in submit function finishes
-- edit.write = function(self, section)
--   local url = luci.dispatcher.build_url("admin/system/disk/partition")
--   url = url .. "/" .. devices[section].path:match("/dev/(.+)")
--   luci.http.redirect(url)
-- end
d.extedit = luci.dispatcher.build_url("admin/system/diskman/partition/%s")

tab_section = m:section(SimpleSection)
tab_section.template="diskman/raid_tab"

-- mount point
local mount_point = {}
local _mount_point = { device = 0}
table.insert( mount_point, _mount_point )
local table_mp = m:section(Table, mount_point, translate("Mount Point"))

local v_device = table_mp:option(Value, "device", translate("Device"))
v_device.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
local v_fs = table_mp:option(Value, "fs", translate("File System"))
v_fs.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self:value("auto", "auto")
    self.default = "auto"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
local v_mount_option = table_mp:option(Value, "mount_options", translate("Mount Options"))
v_mount_option.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self.placeholder = "rw,noauto"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
local v_mount_point = table_mp:option(Value, "mount_point", translate("Mount Point"))
v_mount_point.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self.placeholder = "/media/diskX"
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
table_mp:option(DummyValue, "useage", translate("Useage"))
local btn_umount = table_mp:option(Button, "_umount", translate("Umount"))
table_mp.config = "mount_point"

-- mount point
local raid_devices = {}
-- raid_devices = diskmanager.getRAIDdevices()
r = m:section(Table, raid_devices, translate("RAID Devices"))
r.config = "raid"
path = r:option(DummyValue, "path", translate("Path"))
level = r:option(DummyValue, "level", translate("RAID mode"))
size = r:option(DummyValue, "size", translate("Size"))
status = r:option(DummyValue, "status", translate("Status"))
members = r:option(DummyValue, "members_str", translate("Members"))
remove = r:option(Button, "remove", translate("Remove"))
remove.inputstyle = "remove"
remove.write = function(self, section)
  sys.call("/usr/bin/disk-raid-helper.sh remove "..raid_devices[section].path.." &> /dev/null")
  luci.http.redirect(luci.dispatcher.build_url("admin/system/disk"))
end
-- redit = r:option(Button, "rpartition", translate("Edit Partition"))
-- redit.inputstyle = "edit"
-- redit.inputtitle = "Edit"
-- redit.write = function(self, section)
--   local url = luci.dispatcher.build_url("admin/system/disk/partition")
--   url = url .. "/" .. raid_devices[section].path:match("/dev/(.+)")
--   luci.http.redirect(url)
-- end
r.extedit  = luci.dispatcher.build_url("admin/system/disk/partition/%s")

-- btrfs
local btrfs_devices = {}
local table_btrfs = m:section(Table, btrfs_devices, translate("Btrfs"))
table_btrfs.config = "btrfs"

return m

