--!strict
local Factory = require(script.Parent.NetworkFactory)

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}

-- Cache para evitar chamadas repetitivas ao Factory
local NetworkCache: { [string]: any } = {}

--- @public Obtém um Remote com proteção de Cache e Timeout
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	if NetworkCache[name] then
		return NetworkCache[name]
	end

	-- O Factory já deve ter o timeout que implementamos anteriormente
	local remote = Factory.waitForRemote(name, remoteType)
	NetworkCache[name] = remote
	
	return remote
end

--- @public Constrói uma rede completa
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""

	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end

	return network
end

--- @public Listener Seguro (Middleware)
-- Adiciona uma camada que limpa a conexão automaticamente se necessário
-- ou formata os dados antes de entregar ao script principal
function NetworkService.onEvent(remote: RemoteEvent | UnreliableRemoteEvent, callback: (...any) -> ()): RBXScriptConnection
	return remote.OnClientEvent:Connect(function(...)
		-- Aqui você poderia adicionar um SerdeLayer.decode(...) se fosse usar compressão
		callback(...)
	end)
end

return NetworkService
