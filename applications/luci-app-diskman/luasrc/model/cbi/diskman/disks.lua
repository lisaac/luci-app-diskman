--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <https://github.com/lisaac/luci-app-diskman>
]]--

require "luci.util"
require("luci.tools.webadmin")
local dm = require "luci.model.diskman"

-- Use (non-UCI) SimpleForm since we have no related config file
m = SimpleForm("diskman", translate("DiskMan"), translate("Manage Disks over LuCI."))
m.template = "diskman/cbi/xsimpleform"
m:append(Template("diskman/disk_info"))
-- disable submit and reset button
m.submit = false
m.reset = false
-- rescan disks
rescan = m:section(SimpleSection)
rescan_button = rescan:option(Button, "_rescan")
rescan_button.inputtitle= translate("Rescan Disks")
rescan_button.template = "diskman/cbi/inlinebutton"
rescan_button.inputstyle = "add"
rescan_button.forcewrite = true
rescan_button.write = function(self, section, value)
  luci.util.exec("echo '- - -' | tee /sys/class/scsi_host/host*/scan > /dev/null")
  if dm.command.mdadm then
    luci.util.exec(dm.command.mdadm .. " --assemble --scan")
  end
  luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman"))
end

-- disks
local disks = dm.list_devices()

-- ==================== eMMC 优化显示补丁开始 ====================
if disks then
  for dev, info in pairs(disks) do
--    if dev:match("^mmcblk") then
      -- 1. 优化显示 eMMC 型号 (Model)
      if not info.model or info.model == "" or info.model == "-" then
        local name = luci.util.exec("cat /sys/block/" .. dev .. "/device/name 2>/dev/null"):gsub("%s+", "")
        local type_str = luci.util.exec("cat /sys/block/" .. dev .. "/device/type 2>/dev/null"):gsub("%s+", "")
        if name ~= "" then
          info.model = (type_str ~= "" and type_str or "eMMC") .. " " .. name
        else
          info.model = "eMMC Flash Drive"
        end
      end

      -- 2. 优化显示序列号 (Serial Number)
      if not info.sn or info.sn == "" or info.sn == "-" then
        local serial = luci.util.exec("cat /sys/block/" .. dev .. "/device/serial 2>/dev/null"):gsub("%s+", "")
        if serial ~= "" then info.sn = serial end
      end

      -- 3. 优化显示温度 (Temp)
      if dev:match("^mmcblk") or (not string.match(info.model,"USB")) then
      if not info.temp or info.temp == "" or info.temp == "-" then
        local thermal = luci.util.exec("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
        if thermal and thermal ~= "" then
          local t = tonumber(thermal)
          info.temp = t and string.format("%.1f °C", t / 1000) or "N/A"
        else
          info.temp = "N/A"
        end
      end
      end
      -- 4. 优化显示健康状态 (Health Status)
      if not info.health_status or info.health_status == "" or info.health_status == "-" then
        local life = luci.util.exec("cat /sys/block/" .. dev .. "/device/life_time 2>/dev/null"):gsub("[\r\n]", "")
        local eol = luci.util.exec("cat /sys/block/" .. dev .. "/device/pre_eol_info 2>/dev/null"):gsub("%s+", "")
        
        local status = "Normal"
        if eol == "0x02" or eol == "2" then
          status = "Warning (Consuming)"
        elseif eol == "0x03" or eol == "3" then
          status = "Urgent (Replace)"
        end
        
        if life ~= "" then
          local ta, tb = life:match("([0x%x]+)%s+([0x%x]+)")
          if ta and tb then
            local a_pct = (tonumber(ta) or 0) * 10
           -- local b_pct = (tonumber(tb) or 0) * 10
           -- status = string.format("%s (Est. Used A:%d%%, B:%d%%)", status, a_pct > 100 and 100 or a_pct, b_pct > 100 and 100 or b_pct)
            status = string.format("%s (Used A:%d%%)", status, a_pct > 100 and 100 or a_pct)
	   end
        end
        info.health_status = status
      end

    -- 5. 补全分区表类型显示
    -- if not info.p_table or info.p_table == "" or info.p_table == "-" then
    --   info.p_table = "N/A"
    --  end
      if not info.p_table or info.p_table == "" or info.p_table == "-" then
        local handle = io.popen("parted /dev/" .. dev .. " print 2>/dev/null | grep 'Partition Table'")
        local result = handle:read("*l")
        handle:close()
            if result then
                local ptype = result:match("Partition Table: (%S+)")
      --        local pTable = luci.util.exec("cat /sys/block/" .. dev .. "/device/life_time 2>/dev/null"):gsub("[\r\n]", "")
                info.p_table = ptype
            end
      end
      -- 6. EMMC没有sata信息
      if dev:match("^mmcblk") or string.match(info.model,"USB") then
        info.sata_ver = "-"
      end
  end
end
-- ==================== eMMC 优化显示补丁结束 ====================
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
d:option(DummyValue, "health_status", translate("Health") .. "<br/>" .. translate("Status"))
-- d:option(DummyValue, "status", translate("Status"))

-- local btn_eject = d:option(Button, "_eject")
-- btn_eject.template = "diskman/cbi/disabled_button"
-- btn_eject.inputstyle = "remove"
-- btn_eject.inputtitle = translate("Eject")
-- btn_eject.forcewrite = true
-- btn_eject.write = function(self, section, value)
--   local dev = section
--   local disk_info = dm.get_disk_info(dev, true)
--  if disk_info.p_table:match("Raid") or disk_info.model:match("MMC") then
--    m.errmessage = translate("Unsupported raid and MMC reject!")
--     return
--   end
--   for i, p in ipairs(disk_info.partitions) do
--     if p.mount_point ~= "-" then
--       m.errmessage = p.name .. translate("is in use! please unmount it first!")
--       return
--     end
--   end
--   if disk_info.type:match("md") then
--     luci.util.exec(dm.command.mdadm .. " --stop /dev/" .. dev)
--     luci.util.exec(dm.command.mdadm .. " --remove /dev/" .. dev)
--     for _, disk in ipairs(disk_info.members) do
--       luci.util.exec(dm.command.mdadm .. " --zero-superblock " .. disk)
--     end
--     dm.gen_mdadm_config()
--   else
--     luci.util.exec("echo 1 > /sys/block/" .. dev .. "/device/delete")
--   end
--   luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman"))
-- end

d.extedit = luci.dispatcher.build_url("admin/system/diskman/partition/%s")

-- raid devices
if dm.command.mdadm then
  local raid_devices = dm.list_raid_devices()
  -- raid_devices = diskmanager.getRAIDdevices()
  if next(raid_devices) ~= nil then
    local r = m:section(Table, raid_devices, translate("RAID Devices"))
    r.config = "_raid"
    r:option(DummyValue, "path", translate("Path"))
    r:option(DummyValue, "level", translate("RAID mode"))
    r:option(DummyValue, "size_formated", translate("Size"))
    r:option(DummyValue, "p_table", translate("Partition Table"))
    r:option(DummyValue, "status", translate("Status"))
    r:option(DummyValue, "members_str", translate("Members"))
    r:option(DummyValue, "active", translate("Active"))
    r.extedit  = luci.dispatcher.build_url("admin/system/diskman/partition/%s")
  end
end

-- btrfs devices
if dm.command.btrfs then
  btrfs_devices = dm.list_btrfs_devices()
  if next(btrfs_devices) ~= nil then
    local table_btrfs = m:section(Table, btrfs_devices, translate("Btrfs"))
    table_btrfs:option(DummyValue, "uuid", translate("UUID"))
    table_btrfs:option(DummyValue, "label", translate("Label"))
    table_btrfs:option(DummyValue, "members", translate("Members"))
    -- sieze is error, since there is RAID
    -- table_btrfs:option(DummyValue, "size_formated", translate("Size"))
    table_btrfs:option(DummyValue, "used_formated", translate("Usage"))
    table_btrfs.extedit  = luci.dispatcher.build_url("admin/system/diskman/btrfs/%s")
  end
end

-- mount point
local mount_point = dm.get_mount_points()
local _mount_point = {}
table.insert( mount_point, { device = 0 } )
local table_mp = m:section(Table, mount_point, translate("Mount Point"))
local v_device = table_mp:option(Value, "device", translate("Device"))
v_device.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self.forcewrite = true
    for dev, info in pairs(disks) do
      for i, v in ipairs(info.partitions) do
        self:value("/dev/".. v.name, "/dev/".. v.name .. " ".. v.size_formated)
      end
    end
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
v_device.write = function(self, section, value)
  _mount_point.device = value and value:gsub("%s+", "") or ""
end
local v_fs = table_mp:option(Value, "fs", translate("File System"))
v_fs.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self:value("auto", "auto")
    self.default = "auto"
    self.forcewrite = true
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    DummyValue.render(self, section, scope)
  end
end
v_fs.write = function(self, section, value)
  _mount_point.fs = value and value:gsub("%s+", "") or ""
end
local v_mount_option = table_mp:option(Value, "mount_options", translate("Mount Options"))
v_mount_option.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self.placeholder = "rw,noauto"
    self.forcewrite = true
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    local mp = mount_point[section].mount_options
    mount_point[section].mount_options = nil
    local length = 0
    for k in mp:gmatch("([^,]+)") do
      mount_point[section].mount_options = mount_point[section].mount_options and (mount_point[section].mount_options .. ",") or ""
      if length > 20 then
        mount_point[section].mount_options = mount_point[section].mount_options.. " <br>"
        length = 0
      end
      mount_point[section].mount_options = mount_point[section].mount_options .. k
      length = length + #k
    end
    self.rawhtml = true
    -- mount_point[section].mount_options = #mount_point[section].mount_options > 50 and mount_point[section].mount_options:sub(1,50) .. "..." or mount_point[section].mount_options
    DummyValue.render(self, section, scope)
  end
end
v_mount_option.write = function(self, section, value)
  _mount_point.mount_options = value and value:gsub("%s+", "") or ""
end
local v_mount_point = table_mp:option(Value, "mount_point", translate("Mount Point"))
v_mount_point.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.template = "cbi/value"
    self.placeholder = "/media/diskX"
    self.forcewrite = true
    Value.render(self, section, scope)
  else
    self.template = "cbi/dvalue"
    local new_mp = ""
    local v_mp_d
    for v_mp_d in self["section"]["data"][section]["mount_point"]:gmatch('[^/]+') do
      if #v_mp_d > 12 then
        new_mp = new_mp .. "/" .. v_mp_d:sub(1,7) .. ".." .. v_mp_d:sub(-4)
      else
        new_mp = new_mp .."/".. v_mp_d
      end
    end
    self["section"]["data"][section]["mount_point"] = '<span title="'..self["section"]["data"][section]["mount_point"] .. '" >'..new_mp..'</span>'
    self.rawhtml = true
    DummyValue.render(self, section, scope)
  end
end
v_mount_point.write = function(self, section, value)
  _mount_point.mount_point = value
end
local btn_umount = table_mp:option(Button, "_mount", translate("Mount"))
btn_umount.forcewrite = true
btn_umount.render = function(self, section, scope)
  if mount_point[section].device == 0 then
    self.inputtitle = translate("Mount")
    btn_umount.inputstyle = "add"
  else
    self.inputtitle = translate("Umount")
    btn_umount.inputstyle = "remove"
  end
  Button.render(self, section, scope)
end
btn_umount.write = function(self, section, value)
  local res
  if value == translate("Mount") then
    if not _mount_point.mount_point or not _mount_point.device then return end
    luci.util.exec("mkdir -p ".. _mount_point.mount_point)
    res = luci.util.exec(dm.command.mount .. " ".. _mount_point.device .. (_mount_point.fs and (" -t ".. _mount_point.fs )or "") .. (_mount_point.mount_options and (" -o " .. _mount_point.mount_options.. " ") or  " ").._mount_point.mount_point .. " 2>&1")
  elseif value == translate("Umount") then
    res = luci.util.exec(dm.command.umount .. " "..mount_point[section].mount_point .. " 2>&1")
  end
  if res:match("^mount:") or res:match("^umount:") then
    m.errmessage = luci.util.pcdata(res)
  else
    luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman"))
  end
end

if dm.command.mdadm or dm.command.btrfs then
local creation_section = m:section(TypedSection, "_creation")
creation_section.cfgsections=function()
  return {translate("Creation")}
end
creation_section:tab("raid",  translate("RAID"), translate("RAID Creation"))
creation_section:tab("btrfs", translate("Btrfs"), translate("Multiple Devices Btrfs Creation"))

-- raid functions
if dm.command.mdadm then

  local rname, rmembers, rlevel
  local r_name = creation_section:taboption("raid", Value, "_rname", translate("Raid Name"))
  r_name.placeholder = dm.find_free_md_device()
  r_name.write = function(self, section, value)
    rname = value
  end
  local r_level = creation_section:taboption("raid", ListValue, "_rlevel", translate("Raid Level"))
  local valid_raid = luci.util.exec("grep -m1 'Personalities :' /proc/mdstat")
  if valid_raid:match("%[linear%]") then
    r_level:value("linear", "Linear")
  end
  if valid_raid:match("%[raid5%]") then
    r_level:value("5", "Raid 5")
  end
  if valid_raid:match("%[raid6%]") then
    r_level:value("6", "Raid 6")
  end
  if valid_raid:match("%[raid1%]") then
    r_level:value("1", "Raid 1")
  end
  if valid_raid:match("%[raid0%]") then
    r_level:value("0", "Raid 0")
  end
  if valid_raid:match("%[raid10%]") then
    r_level:value("10", "Raid 10")
  end
  r_level.write = function(self, section, value)
    rlevel = value
  end
  local r_member = creation_section:taboption("raid", DynamicList, "_rmember", translate("Raid Member"))
  for dev, info in pairs(disks) do
    if not info.inuse and  #info.partitions == 0  then
        r_member:value(info.path, info.path.. " ".. info.size_formated)
    end
    for i, v in ipairs(info.partitions) do
      if not v.inuse then
        r_member:value("/dev/".. v.name, "/dev/".. v.name .. " ".. v.size_formated)
      end
    end
  end
  r_member.write = function(self, section, value)
    rmembers = value
  end
  local r_create = creation_section:taboption("raid", Button, "_rcreate")
  r_create.render = function(self, section, scope)
    self.title = " "
    self.inputtitle = translate("Create Raid")
    self.inputstyle = "add"
    Button.render(self, section, scope)
  end
  r_create.write = function(self, section, value)
    -- mdadm --create --verbose /dev/md0 --level=stripe --raid-devices=2 /dev/sdb6 /dev/sdc5
    local res = dm.create_raid(rname, rlevel, rmembers)
    if res and res:match("^ERR") then
      m.errmessage = luci.util.pcdata(res)
      return
    end
    dm.gen_mdadm_config()
    luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman"))
  end
end

-- btrfs
if dm.command.btrfs then
  local blabel, bmembers, blevel
  local btrfs_label = creation_section:taboption("btrfs", Value, "_blabel", translate("Btrfs Label"))
  btrfs_label.write = function(self, section, value)
    blabel = value
  end
  local btrfs_level = creation_section:taboption("btrfs", ListValue, "_blevel", translate("Btrfs Raid Level"))
  btrfs_level:value("single", "Single")
  btrfs_level:value("raid0", "Raid 0")
  btrfs_level:value("raid1", "Raid 1")
  btrfs_level:value("raid10", "Raid 10")
  btrfs_level.write = function(self, section, value)
    blevel = value
  end

  local btrfs_member = creation_section:taboption("btrfs", DynamicList, "_bmember", translate("Btrfs Member"))
  for dev, info in pairs(disks) do
    if not info.inuse and  #info.partitions == 0  then
      btrfs_member:value(info.path, info.path.. " ".. info.size_formated)
    end
    for i, v in ipairs(info.partitions) do
      if not v.inuse then
        btrfs_member:value("/dev/".. v.name, "/dev/".. v.name .. " ".. v.size_formated)
      end
    end
  end
  btrfs_member.write = function(self, section, value)
    bmembers = value
  end
  local btrfs_create = creation_section:taboption("btrfs", Button, "_bcreate")
  btrfs_create.render = function(self, section, scope)
    self.title = " "
    self.inputtitle = translate("Create Btrfs")
    self.inputstyle = "add"
    Button.render(self, section, scope)
  end
  btrfs_create.write = function(self, section, value)
    -- mkfs.btrfs -L label -d blevel /dev/sda /dev/sdb
    local res = dm.create_btrfs(blabel, blevel, bmembers)
    if res and res:match("^ERR") then
      m.errmessage = luci.util.pcdata(res)
      return
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/system/diskman"))
  end
end
end

return m
