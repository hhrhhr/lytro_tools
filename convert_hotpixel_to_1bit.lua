assert(_VERSION == "Lua 5.3")

if arg[3] == nil then print([[

usage:

    lua convert_hotpixel_to_1bit.lua filename width height [negative]
    
    filename : path to hotPixelRef.bin
    negative : white bacground
]])
os.exit()
end

local filename  = arg[1]
local width     = arg[2]
local height    = arg[3]
local negative  = arg[4] or false -- black background


local color1 = negative and 0 or 1
local color2 = negative and 1 or 0


print("allocate...")
local pbm = {}
for y = 1, height do
    pbm[y] = {}
    for x = 1, width do
        pbm[y][x] = color1
    end
end


print("read hot pixels...")
local r = assert(io.open(filename, "rb"), "\n\nERROR: file open failed\n")
local count = string.unpack("<I", r:read(4))

local x = {}
for i = 1, count do
    x[i] = string.unpack("<h", r:read(2))+1
end

local y = {}
for i = 1, count do
    y[i] = string.unpack("<h", r:read(2))+1
end

r:close()


print("update map...")
for i = 1, count do
    pbm[y[i]][x[i]] = color2
end
x, y = nil, nil


print("save...")
filename = filename:gsub(".bin", ".pbm")
local w = assert(io.open(filename, "w+b"), "\n\nERROR: file open failed\n")

w:write(("P4\n%d\n%d\n"):format(width, height))

for y = 1, height do
    local str = {}
    for x = 1, width, 8 do
        local i8 =
        (pbm[y][x+0] << 7) |
        (pbm[y][x+1] << 6) |
        (pbm[y][x+2] << 5) |
        (pbm[y][x+3] << 4) |
        (pbm[y][x+4] << 3) |
        (pbm[y][x+5] << 2) |
        (pbm[y][x+6] << 1) |
        (pbm[y][x+7] << 0)

        table.insert(str, string.char(i8))
    end
    w:write(table.concat(str))
end

w:close()

print("done.")
