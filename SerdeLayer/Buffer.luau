--!native
local Types = require(script.Parent.Parent.Types)

export type PacketSerde = Types.PacketSerde

local BUFFER_ID = 11

local function Serialize(_, Buffer: buffer, has: boolean?): (buffer, number?)
    local BufferLength: number = buffer.len(Buffer)
    
    -- Se for raiz, +1 byte para o ID. Sempre +2 bytes para o tamanho (u16).
    local headerOffset = has and 0 or 1
    local Size: number = BufferLength + headerOffset + 2

    local NewBuffer: buffer = buffer.create(Size)
    local Cursor = 0

    if not has then
        buffer.writeu8(NewBuffer, Cursor, BUFFER_ID)
        Cursor += 1
    end

    buffer.writeu16(NewBuffer, Cursor, BufferLength)
    buffer.copy(NewBuffer, Cursor + 2, Buffer)

    return NewBuffer, Size
end

local function Deserialize(_, Buffer: buffer, Cursor: number?, has: boolean?): (buffer, number?)
    local LocalCursor: number = Cursor or 0

    if not has then
        LocalCursor += 1 -- Pula o ID 11
    end

    local BufferLength: number = buffer.readu16(Buffer, LocalCursor)
    local NewBuffer: buffer = buffer.create(BufferLength)

    LocalCursor += 2
    buffer.copy(NewBuffer, 0, Buffer, LocalCursor, BufferLength)

    return NewBuffer, LocalCursor + BufferLength
end

return {
    Serialize = Serialize;
    Deserialize = Deserialize;
} :: PacketSerde
