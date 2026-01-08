--!strict
local Factory = require(script.Parent.NetworkFactory)

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}

--- @public Obtém um Remote específico (Aguarda se necessário)
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	return Factory.waitForRemote(name, remoteType)
end

--- @public Constrói uma rede completa no cliente
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""

	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end

	return network
end

return NetworkService

