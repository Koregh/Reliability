--!strict
local Players = game:GetService("Players")
local Factory = require(script.Parent.NetworkFactory)

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local LOOK_UP_THRESHOLD = 24

local NetworkService = {}

--- @public Obtém ou Cria um Remote com validação de tipo
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	local existing = Factory.getExisting(name, remoteType)
	if existing then return existing end
	
	return Factory.create(name, remoteType)
end

--- @public Cria uma rede mapeada 
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""

	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end

	return network
end

--- @public Disparo Seguro para selecionados
function NetworkService.fireSelected(remote: RemoteEvent | UnreliableRemoteEvent, selected: {Player}, ...: any)
	assert(remote, "[NetworkService] Remote não definido")
	for _, player in selected do
		remote:FireClient(player, ...)
	end
end

--- @public Disparo Otimizado com Lookup Table
function NetworkService.fireExcept(remote: RemoteEvent | UnreliableRemoteEvent, except: {Player}, ...: any)
	assert(remote, "[NetworkService] Remote não definido")
	
	local allPlayers = Players:GetPlayers()
	local exceptSize = #except

	if exceptSize > LOOK_UP_THRESHOLD then
		-- Otimização O(1) para grandes listas
		local lookup = {}
		for _, p in except do lookup[p] = true end
		
		for _, p in allPlayers do
			if not lookup[p] then
				remote:FireClient(p, ...)
			end
		end
	else
		-- Otimização para pequenas listas (evita criar tabela de lookup)
		for _, p in allPlayers do
			if not table.find(except, p) then
				remote:FireClient(p, ...)
			end
		end
	end
end

return NetworkService

