--!native
--!strict

local Types = require(script:WaitForChild("Types"))
export type PacketSerde = Types.PacketSerde

local Serde = {
	--  MAPEAMENTO DE IDS ÚNICOS 
	-- NÃO mude a ordem depois que o jogo estiver em produção.
	IDs = {
		[1]  = "UInt8",
		[2]  = "UInt16",
		[3]  = "UInt32",
		[4]  = "FInt64",
		[5]  = "String",
		[6]  = "Vector3",
		[7]  = "CFrame",
		[8]  = "Dict",
		[9]  = "Array",
		[10] = "Tuple",
		[11] = "Buffer",
	}
}

-- Tabela interna para busca rápida
local Modules: { [number | string]: any } = {}


-- Este loop carrega todos os seus ModuleScripts e os vincula aos IDs
for id, name in Serde.IDs do
	local module = script:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local required = require(module)
		Modules[id] = required   -- Permite busca por ID: SerdeLayer[6]
		Modules[name] = required -- Permite busca por Nome: SerdeLayer.Vector3
	else
		warn(`[SerdeLayer]: Módulo {name} (ID {id}) não encontrado na pasta!`)
	end
end


-- Permite que você faça require(SerdeLayer).Vector3 ou require(SerdeLayer)[6]
setmetatable(Serde, {
	__index = function(_, key)
		return Modules[key]
	end
})


--- @public Identifica o compressor lendo o Byte 0 do buffer
function Serde.getCompressorFromBuffer(buf: buffer): PacketSerde?
	if buffer.len(buf) == 0 then return nil end
	local typeId = buffer.readu8(buf, 0)
	return Modules[typeId]
end

--- @public Retorna o ID associado a um tipo (usado no Serialize)
function Serde.getTypeID(typeName: string): number?
	for id, name in Serde.IDs do
		if name == typeName then return id end
	end
	return nil
end

return Serde
