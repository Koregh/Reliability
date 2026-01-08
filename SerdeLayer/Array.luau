--!native
local Types = require(script.Parent.Parent.Types)

type PacketSerde = Types.PacketSerde
export type ArraySerde = Types.ArraySerde

local ARRAY_ID = 9

local function Serialize(self: ArraySerde, Data: {any}, has: boolean?): (buffer, number?)
    local Buffers: {buffer} = {}
    local BufferLengths: {number} = {}
    
    -- Se for o pacote raiz (has = nil/false), reserva 1 byte para o ID 9
    local headerOffset = has and 0 or 1
    local TotalSize: number = headerOffset + 2 -- Header do ID + 2 bytes do tamanho (u16)

    for _, Value: any in Data do
        -- Chamamos o Serde interno com 'has = true' para ele não repetir o ID em cada item
        local Buffer: buffer, Size: number? = self._Serde:Serialize(Value, true)

        TotalSize += Size :: number

        table.insert(BufferLengths, Size :: number)
        table.insert(Buffers, Buffer)
    end

    local FinalBuffer: buffer = buffer.create(TotalSize)
    local Cursor: number = 0

    if not has then
        buffer.writeu8(FinalBuffer, Cursor, ARRAY_ID)
        Cursor += 1
    end

    -- Escreve o tamanho da carga útil (Total menos o cabeçalho)
    buffer.writeu16(FinalBuffer, Cursor, TotalSize - (headerOffset + 2))
    Cursor += 2

    for Index: number, Buffer in Buffers do
        buffer.copy(FinalBuffer, Cursor, Buffer, 0)
        Cursor += BufferLengths[Index]
    end

    return FinalBuffer, TotalSize
end

local function Deserialize(self: ArraySerde, Data: buffer, Cursor: number?, has: boolean?): ({any}, number?)
    local LocalCursor: number = Cursor or 0
    local SerializedTable: {any} = {}

    if not has then
        LocalCursor += 1 -- Pula o ID 9 se for o início do pacote
    end

    local BufferLength: number = buffer.readu16(Data, LocalCursor)
    LocalCursor += 2

    local InitialCursor: number = LocalCursor
    
    -- Loop de segurança baseado no tamanho do buffer do array
    while LocalCursor - InitialCursor < BufferLength do
        local SerializedData: any, NewCursor: number? = self._Serde:Deserialize(Data, LocalCursor, true)
        
        table.insert(SerializedTable, SerializedData)
        LocalCursor = NewCursor :: number
    end

    return SerializedTable, LocalCursor
end

return function(Serde: PacketSerde): ArraySerde
    return {
        Serialize = Serialize;
        Deserialize = Deserialize;
        _Serde = Serde;
    }
end
