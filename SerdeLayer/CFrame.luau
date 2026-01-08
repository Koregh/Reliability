--!native
local Types = require(script.Parent.Parent.Types)

export type PacketSerde = Types.PacketSerde
local DATA_SIZE: number = 24 -- 6 floats de 4 bytes
local CFRAME_ID: number = 7

local function Serialize(_, value: CFrame, has: boolean?): (buffer, number?)
    local headerOffset = has and 0 or 1
    local totalSize = DATA_SIZE + headerOffset
    
    local b = buffer.create(totalSize)
    local cursor = 0

    if not has then
        buffer.writeu8(b, 0, CFRAME_ID)
        cursor = 1
    end

    local rx, ry, rz = value:ToEulerAnglesXYZ()

    buffer.writef32(b, cursor, value.X)
    buffer.writef32(b, cursor + 4, value.Y)
    buffer.writef32(b, cursor + 8, value.Z)
    buffer.writef32(b, cursor + 12, rx)
    buffer.writef32(b, cursor + 16, ry)
    buffer.writef32(b, cursor + 20, rz)

    return b, totalSize
end

local function Deserialize(_, b: buffer, cursor: number?, has: boolean?): (CFrame, number?)
    local localCursor = cursor or 0

    if not has then
        localCursor += 1 -- Pula o ID 7
    end

    local x = buffer.readf32(b, localCursor)
    local y = buffer.readf32(b, localCursor + 4)
    local z = buffer.readf32(b, localCursor + 8)
    
    local rx = buffer.readf32(b, localCursor + 12)
    local ry = buffer.readf32(b, localCursor + 16)
    local rz = buffer.readf32(b, localCursor + 20)

    local builtCFrame = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)

    return builtCFrame, localCursor + DATA_SIZE
end

return {
    Serialize = Serialize;
    Deserialize = Deserialize;
} :: PacketSerde
