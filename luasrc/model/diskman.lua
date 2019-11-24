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
local host_mounts = nixio.fs.readfile("/hostproc/mounts") or ""
local mounts = nixio.fs.readfile("/proc/mounts") or ""
local swaps = nixio.fs.readfile("/proc/swaps") or ""
local df = luci.sys.exec("df") or ""

-- Check if it contains nas partition (LABEL=nasetc)
local isSystemMMC = function(device)
  if not device:match("/dev/mmcblk%S+") then return false end

  local ls = io.popen("ls "..device.."p*", "r")
  for partition in ls:lines() do
    local blkid = io.popen("blkid -s LABEL -o value "..partition, "r")
    local label = blkid:read("*all"):gsub("([^\n+])\n", "%1")
    blkid:close()
    if label == "nasetc" then
      ls:close()
      return true
    end
  end
  ls:close()
  return false
end

function byte_format(byte)
	local suff = {"B", "KB", "MB", "GB", "TB"}
	for i=1, 5 do
		if byte > 1024 and i < 5 then
			byte = byte / 1024
		else
			return string.format("%.2f %s", byte, suff[i]) 
		end 
	end
end

local get_smart_info = function(device)
  local section
  local smart_info = {}
  for _, line in ipairs(luci.util.execl("smartctl -H -A -i -n standby -f brief /dev/" .. device)) do
    local attrib, val
    if section == 1 then
        attrib, val = line:match "^(.-):%s-(.+)"
    elseif section == 2 then
      attrib, val = line:match("^([0-9 ]*) [^ ]* * [POSRCK-]* *[0-9-]* *[0-9-]* *[0-9-]* *[0-9-]* *([0-9-]*)")
      if not smart_info.health then smart_info.health = line:match(".-overall%-health.-: (.+)") end
    else
      attrib = line:match "^=== START OF (.*) SECTION ==="
      if attrib == "INFORMATION" then
        section = 1
      elseif attrib == "READ SMART DATA" then
        section = 2
      elseif smart_info.status == "-" then
        val = line:match "^Device is in (.*) mode"
        if val then smart_info.status = val:lower() end
      end
    end

    if not attrib then
      if section ~= 2 then section = 0 end
    elseif (attrib == "Power mode is") or
      (attrib == "Power mode was") then
        smart_info.status = val:match("(%S+)")
    -- elseif attrib == "Sector Sizes" then
    --   -- 512 bytes logical, 4096 bytes physical
    --   smart_info.phy_sec = val:match "([0-9]*) bytes physical"
    --   smart_info.logic_sec = val:match "([0-9]*) bytes logical"
    -- elseif attrib == "Sector Size" then
    --   -- 512 bytes logical/physical
    --   smart_info.phy_sec = val:match "([0-9]*)"
    --   smart_info.logic_sec = smart_info.phy_sec
    elseif attrib == "Serial Number" then
      smart_info.sn = val
    elseif attrib == "194" then
      smart_info.temp = val .. "°C"
    elseif attrib == "Rotation Rate" then
      smart_info.rota_rate = val
    elseif attrib == "SATA Version is" then
      smart_info.sata_ver = val
    end
  end
  return smart_info
end

local parse_parted_info = function(keys, line)
  -- parse the output of parted command (machine parseable format)
  -- /dev/sda:5860533168s:scsi:512:4096:gpt:ATA ST3000DM001-1ER1:;
  -- 1:34s:2047s:2014s:free;
  -- 1:2048s:1073743872s:1073741825s:ext4:primary:;
  local result = {}
  local values = {}

  for value in line:gmatch("(.-)[:;]") do table.insert(values, value) end
  for i = 1,#keys do
    result[keys[i]] = values[i] or ""
  end
  return result
end

local get_mount_point = function(partition)
  -- if use luci-in-dokcer, using parameter "-v /proc:/hostproc" to get the host mount information
  local mount_point
  for m in host_mounts:gmatch("/dev/"..partition.." ([^ ]*)") do
    mount_point = (mount_point and (mount_point .. " ")  or "") .. m
  end
  if mount_point then return mount_point end
  -- if nixio.fs.access("/hostproc/mounts") then
  --   result = luci.sys.exec('cat /hostproc/mounts | awk \'{if($1=="/dev/'.. partition ..'") print $2}\'')
  --   if result ~= "" then return result end
  -- end
  for m in mounts:gmatch("/dev/"..partition.." ([^ ]*)") do
    mount_point = (mount_point and (mount_point .. " ")  or "") .. m
  end
  if mount_point then return mount_point end
  -- result = luci.sys.exec('cat /proc/mounts | awk \'{if($1=="/dev/'.. partition ..'") print $2}\'')
  -- if result ~= "" then return result end

  if swaps:match("\n/dev/" .. partition) then return "swap" end
  -- result = luci.sys.exec("cat /proc/swaps | grep /dev/" .. partition)
  -- if result ~= "" then return "swap" end

  -- check if used as raid partition
  if nixio.fs.access("/proc/mdstat") then
    result = luci.sys.exec("grep md /proc/mdstat | cut -d ':' -f 2 | grep " .. partition)
    if result ~= "" then return true end
  end
  return false
end

local get_partition_useage = function(partition)
  if not nixio.fs.access("/dev/"..partition) then return false end
  local useage = df:match("\n/dev/" .. partition .. "%s+%d+%s+%d+%s+%d+%s+([0-9]+)%%%s")
  useage = useage and (useage .. "%") or false
  return useage
end

local get_parted_info = function(device)
  if not device then return end
  local parted_info = {partition_info={},device_info={}}
  local device_info_keys = { "path", "size", "type", "logic_sec", "phy_sec", "p_table", "model", "flags" }
  local partition_info_keys = { "number", "sec_start", "sec_end", "size", "fs", "type", "flags" }
  local temp_parted_info = {}
  for _, line in ipairs(luci.util.execl("/usr/sbin/parted -s -m /dev/" .. device .. " unit s print free", "r")) do
    if line:find("^/dev/"..device..":.+") then
      parted_info["device_info"] = parse_parted_info(device_info_keys, line)
      if parted_info["device_info"]["size"] then
        local length = parted_info["device_info"]["size"]:gsub("^(%d+)s$", "%1")
        local newsize = tostring(tonumber(length)*tonumber(parted_info["device_info"]["logic_sec"]))
        parted_info["device_info"]["size"] = newsize
        if parted_info["device_info"]["p_table"] == "msdos" then
          parted_info["device_info"]["p_table"] = "MBR"
        else
          parted_info["device_info"]["p_table"] = parted_info["device_info"]["p_table"]:upper()
        end
      end
    elseif line:find("^%d-:.+") then
      temp_parted_info = parse_parted_info(partition_info_keys, line)
      -- use human-readable form instead of sector number
      if temp_parted_info["size"] then
        local length = temp_parted_info["size"]:gsub("^(%d+)s$", "%1")
        local newsize = (tonumber(length) * tonumber(parted_info["device_info"]["logic_sec"]))
        temp_parted_info["size"] = newsize
        temp_parted_info["size_formated"] = byte_format(newsize)
      end
      if temp_parted_info["fs"] == "free" then
        temp_parted_info["number"] = "-"
        temp_parted_info["fs"] = "Free Space"
        temp_parted_info["name"] = "-"
      elseif device:match("sd") or device:match("sata") then
        temp_parted_info["name"] = device..temp_parted_info["number"]
      elseif device:match("mmcblk") or device:match("md") then
        temp_parted_info["name"] = device.."p"..temp_parted_info["number"]
      end
      temp_parted_info["fs"] = temp_parted_info["fs"] == "" and "raw" or temp_parted_info["fs"]
      temp_parted_info["sec_start"] = temp_parted_info["sec_start"] and temp_parted_info["sec_start"]:sub(1,-2)
      temp_parted_info["sec_end"] = temp_parted_info["sec_end"] and temp_parted_info["sec_end"]:sub(1,-2)
      temp_parted_info["mount_point"] = temp_parted_info["name"]~="-" and get_mount_point(temp_parted_info["name"]) or "-"
      temp_parted_info["useage"] = temp_parted_info["mount_point"]~="-" and get_partition_useage(temp_parted_info["name"]) or "-"
      table.insert(parted_info["partition_info"], temp_parted_info)
      -- parted_info["partition_info"][temp_parted_info["name"]]=temp_parted_info
    end
  end
  return parted_info
end

local d = {}

--[[ return:
{
  device_info={ path,model,sn,size,flag,temp,p_table,logic_sec,phy_sec,sata_ver,rota_rate,status,health },
  partition_info={
    { number, name, sec_start, sec_end, size, fs, flags },
    sda1={ number, name, sec_start, sec_end, size, fs, flags, mount_point },
    ...
  }
}
--]]
d.get_device_info = function(device)
  if not device then return end
  local d_info = get_parted_info(device)
  local smart_info = get_smart_info(device)
  for k, v in pairs(smart_info) do
    d_info["device_info"][k] = v
  end
  d_info["device_info"]["sec_size"] = d_info["device_info"]["logic_sec"] .. "/" .. d_info["device_info"]["phy_sec"]
  d_info["device_info"]["size_formated"] = byte_format(tonumber(d_info["device_info"]["size"]))
  return d_info
end

-- Collect Devices information
d.list_devices = function()
  local fs = require "nixio.fs"

  -- get all device names (sdX and mmcblkX)
  local target_devnames = {}
  for dev in fs.dir("/dev") do
    if dev:match("sd[a-z]$")
      or dev:match("mmcblk%d+$")
      or dev:match("sata[a-z]$")
      then
      table.insert(target_devnames, dev)
    end
  end

  local devices = {}
  for i, bname in pairs(target_devnames) do

    local device_info = {}
    local device = "/dev/" .. bname
    -- luci.util.perror(bname)
    local size = tonumber(fs.readfile(string.format("/sys/class/block/%s/size", bname)))
    local ss = tonumber(fs.readfile(string.format("/sys/class/block/%s/queue/logical_block_size", bname)))
    local model = fs.readfile(string.format("/sys/class/block/%s/device/model", bname))

    if not isSystemMMC(device) and size > 0 then
      device_info["path"] = device
      device_info["size_formated"] = byte_format(size*ss)
      device_info["model"] = model

      local udevinfo = {}
      if luci.sys.exec("which udevadm") ~= "" then
        local udevadm = io.popen("udevadm info --query=property --name="..device)
        for attr in udevadm:lines() do
          local k, v = attr:match("(%S+)=(%S+)")
          udevinfo[k] = v
        end
        udevadm:close()

        device_info["info"] = udevinfo
        if udevinfo["ID_MODEL"] then device_info["model"] = udevinfo["ID_MODEL"] end
      end
      devices[bname] = device_info
    end
  end
  return devices
end

-- get formart cmd
d.get_format_cmd = function()
  local AVAILABLE_FMTS = {
    ext2 = { cmd = "mkfs.ext2", option = "-F -E lazy_itable_init=1" },
    ext3 = { cmd = "mkfs.ext3", option = "-F -E lazy_itable_init=1" },
    ext4 = { cmd = "mkfs.ext4", option = "-F -E lazy_itable_init=1" },
    fat32 = { cmd = "mkfs.fat", option = "-F 32 -I" },
    exfat = { cmd = "mkexfat", option = "-f" },
    hfsplus = { cmd = "mkhfs", option = "-f" },
    ntfs = { cmd = "mkntfs", option = "-f" },
    swap = { cmd = "mkswap", option = "-f" },
    btrfs = { cmd = "mkfs.btrfs", option = "-f" }
  }
  result = {}
  for fmt, obj in pairs(AVAILABLE_FMTS) do
    local cmd = luci.sys.exec("/usr/bin/which " .. obj["cmd"])
    if cmd:match(obj["cmd"]) then
      result[fmt] = { cmd = cmd:sub(1,-2) ,option = obj["option"] }
    end
  end
  return result
end

return d
