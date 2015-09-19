local filename = assert(arg[1], "\n\nERROR: filename is missing\n")
local outdir = arg[2] or "."

local r

local function read_uint32(big_endian)
    local u32 = 0
    if big_endian then
        u32 = string.unpack(">I", r:read(4))
    else
        u32 = string.unpack("<I", r:read(4))
    end
    return u32
end

local function clear_zero(str)
    local zero_start = string.find(str, "\x00")
    str = string.sub(str, 1, zero_start-1)
    return str
end

-- main -----------------------------------------------------------------------

r = assert(io.open(filename, "rb"), "\n\nERROR: file open failed\n")

local size = r:seek("end")
r:seek("set")
assert(size > 16, "\n\nERROR: file to small\n")

local lf = {}

print("\nparse...\n")

local pos = r:seek()
while pos < size do
    local magic = r:read(3)
    assert("\x89\x4C\x46" == magic,
        "\n\nERROR: magic not match - " .. magic .. "\n")

    local typ = r:read(1)

    magic = r:read(4)
    assert("\x0D\x0A\x1A\x0A" == magic,
        "\n\nERROR: magic not match - " .. magic .. "\n")

    local ver = read_uint32(1)
    local size = read_uint32(1)
    local name = ""

    if size > 0 then
        name = clear_zero(r:read(80))
        pos = r:seek()
        r:seek("cur", size)                     -- skip data
        r:seek("cur", 15 - ((r:seek()-1) % 16)) -- 16 byte alignment
    end
    print(("0x%08x %s %d %8d %s"):format(pos, typ, ver, size, name))

    local t = {off = pos, typ = typ, ver = ver, size = size, name = name}
    table.insert(lf, t)

    pos = r:seek()
end
print()

-------------------------------------------------------------------------------

local mt = {}
local ext = {
    ["aberrationCorrectionRef"]         = ".json",
    ["aberrationCorrectionMetadataRef"] = ".json",
--    ["depthMap"]                        = ".map",
    ["exposureHistogramRef"]            = ".expo",
    ["geometryCorrectionRef"]           = ".geom",
    ["imageRef"]                        = ".bin",
    ["hotPixelRef"]                     = ".bin",
    ["metadata"]                        = ".json",
    ["metadataRef"]                     = ".json",
    ["modulationDataRef"]               = ".bin",
    ["modulationDataMetadataRef"]       = ".json",
    ["privateMetadataRef"]              = ".json",
    ["reconstructionFilterRef"]         = ".png",
    ["reconstructionFilterMetadataRef"] = ".json",
--    ["thumbnail"]                       = "",
--    [""] = ".json",
--    [""] = ".json",
--    [""] = ".json",
}

--[[ find metadata ]]--
local metadata
for i = 1, #lf do
    local l = lf[i]
    if l.typ == "M" then
        mt[l.name] = "metadata"
        r:seek("set", l.off)
        metadata = r:read(l.size)
        break
    end
end

if metadata then
    print("[+] metadata")

    local JSON = (loadfile "JSON.lua")()
    metadata = JSON:decode(metadata)

--[[ try to rename all blocks ]]--
    local frame
    if     metadata["picture"] 
    and metadata["picture"]["frameArray"]
    and metadata["picture"]["frameArray"][1] then
        -- model 1
        frame = metadata["picture"]["frameArray"][1]["frame"]
    elseif metadata["frames"] 
    and metadata["frames"][1] then
        -- model 2 (illum)
        frame = metadata["frames"][1]["frame"]
    else
        -- unknown model
    end

    if frame then
        print("[+] frameArray")
        for k, v in pairs(frame) do
            mt[v] = k
        end
    else
        print("[-] frameArray")
    end

--[[ try to find thumbnail ]]--
    local thumb = metadata["thumbnails"]
    if thumb then
        print("[+] thumbnail")
        mt[thumb[1]["imageRef"]] = "thumbnail." .. thumb[1]["representation"]
    else
        print("[-] thumbnail")
    end

--[[ try to find views, depthmap, perspective images ]]--
    local view = metadata["views"]
    if view then
        print("[+] views")

        local depthmap
        if  view[1]
        and view[1]["accelerations"] 
        and view[1]["accelerations"][1] then
            depthmap = view[1]["accelerations"][1]["depthMap"]
        end
        if depthmap then
            print("[+] depthMap")
            local w = depthmap["width"]
            local h = depthmap["height"]
            mt[depthmap["imageRef"]] = ("depthMap_%dx%d.map"):format(w, h)
        else
            print("[-] depthMap")
        end

        local perImage_ext
        if  view[1]
        and view[1]["accelerations"]
        and view[1]["accelerations"][1] then
            perImage_ext = view[1]["accelerations"][1]["representation"]
        end

        local perImage
        if  view[1]
        and view[1]["accelerations"]
        and view[1]["accelerations"][1] then
            perImage = view[1]["accelerations"][1]["perImage"]
        end
        if perImage then
            print("[+] perspective")
            for i, t in ipairs(perImage) do
                local pimg = "perImage_%d.%s" --_u(%.2f)_v(%.2f.%s)"
--                local u = t["perspective"]["u"]
--                local v = t["perspective"]["v"]
                pimg = pimg:format(i, perImage_ext or "")
                mt[t["imageRef"]] = pimg
            end
        else
            print("[-] perspective images")
        end
    else
        print("[-] views")
    end
--    print()
--    for k, v in pairs(mt) do print(k, v) end
else
    print("[-] metadata")
end

--goto skip
-------------------------------------------------------------------------------

print("\nsplit...")

for i = 1, #lf do
    local l = lf[i]
    if l.size > 0 then
        local n = l.name
        local name = outdir .. "\\"
        name = name .. (mt[n] or n)
        name = name .. (ext[mt[n]] or "")
--        print(name)

        r:seek("set", l.off)
        local w = assert(io.open(name, "w+b"))
        w:write(r:read(l.size))
        w:close()    
    end
end

-------------------------------------------------------------------------------
print("\ndone.")

::skip::

r:close()
