--!strict
local Players = game:GetService("Players")
local Factory = require(script.Parent.NetworkFactory)

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

-- Configurações de Segurança
local LOOK_UP_THRESHOLD = 24
local DEFAULT_RATE_LIMIT = 0.1 -- 10 chamadas por segundo

local NetworkService = {}

-- Tabelas de Estado (Privadas)
local RateLimitMap: { [Player]: { [string]: number } } = {}

-- Limpeza de memória (Memory Leak Prevention)
Players.PlayerRemoving:Connect(function(player)
	RateLimitMap[player] = nil
end)

--- @private Verifica se o disparo é abusivo
function NetworkService.isSpamming(player: Player, remoteName: string, customLimit: number?): boolean
	local now = os.clock()
	local limit = customLimit or DEFAULT_RATE_LIMIT
	
	if not RateLimitMap[player] then RateLimitMap[player] = {} end
	
	local lastCall = RateLimitMap[player][remoteName] or 0
	if (now - lastCall) < limit then
		return true 
	end
	
	RateLimitMap[player][remoteName] = now
	return false
end

--- @public Valida tipos de argumentos enviados pelo Cliente (Anti-Exploit)
-- Uso: if not NetworkService.validate(args, {"string", "number"}) then return end
function NetworkService.validate(args: {any}, expectedTypes: {string}): boolean
	for i, expectedType in expectedTypes do
		if typeof(args[i]) ~= expectedType then
			warn(`[Security] Tipo inválido no argumento {i}. Esperado {expectedType}, recebido {typeof(args[i])}`)
			return false
		end
	end
	return true
end

--- @public Obtém ou Cria um Remote
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

--- @public Disparo Otimizado com Lookup Table
function NetworkService.fireExcept(remote: RemoteEvent | UnreliableRemoteEvent, except: {Player}, ...: any)
	assert(remote, "[NetworkService] Remote não definido")
	local allPlayers = Players:GetPlayers()
	
	if #except > LOOK_UP_THRESHOLD then
		local lookup = {}
		for _, p in except do lookup[p] = true end
		for _, p in allPlayers do
			if not lookup[p] then remote:FireClient(p, ...) end
		end
	else
		for _, p in allPlayers do
			if not table.find(except, p) then remote:FireClient(p, ...) end
		end
	end
end

--- @public Disparo Seguro para selecionados
function NetworkService.fireSelected(remote: RemoteEvent | UnreliableRemoteEvent, selected: {Player}, ...: any)
	assert(remote, "[NetworkService] Remote não definido")
	for _, player in selected do
		remote:FireClient(player, ...)
	end
end

return NetworkService
