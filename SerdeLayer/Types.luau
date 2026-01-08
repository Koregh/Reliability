--!strict
-- Types.lua 

export type PacketSerde = {
    Serialize: (self: any, value: any) -> buffer,
    Deserialize: (self: any, buf: buffer) -> any,
    [any]: any -- Para permitir outras propriedades específicas de cada tipo
}

return nil

