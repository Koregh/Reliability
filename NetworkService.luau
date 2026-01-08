--!strict
local Players = game:GetService("Players")
local Factory = require(script.Parent.NetworkFactory)

-- 

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

-- Configurações
local LOOK_UP_THRESHOLD = 24
local DEFAULT_RATE_LIMIT = 0.1 -- 10 chamadas por segundo

local NetworkService = {}

-- Tabelas de Estado Internas (Privadas)
local RateLimitMap: { [Player]: { [string]: number } } = {}

-- 

-- Prevenção de Memory Leak: Limpa dados quando o jogador sai
Players.PlayerRemoving:Connect(function(player)
	RateLimitMap[player] = nil
end)

--- @private Lógica interna de controle de fluxo (Anti-Spam)
function NetworkService._isSpamming(player: Player, remoteName: string, customLimit: number?): boolean
	local now = os.clock()
	local limit = customLimit or DEFAULT_RATE_LIMIT
	
	if not RateLimitMap[player] then RateLimitMap[player] = {} end
	
	local lastCall = RateLimitMap[player][remoteName] or 0
	if (now - lastCall) < limit then
		warn(`[SECURITY] {player.Name} bloqueado por spam no Remote: {remoteName}`)
		return true 
	end
	
	RateLimitMap[player][remoteName] = now
	return false
end

--- @public Valida se os argumentos enviados pelo cliente são seguros
function NetworkService.validate(args: {any}, expectedTypes: {string}): boolean
	for i, expectedType in expectedTypes do
		if typeof(args[i]) ~= expectedType then
			warn(`[Security] Tipo inválido no argumento {i}. Esperado {expectedType}, recebido {typeof(args[i])}`)
			return false
		end
	end
	return true
end

--- @public Obtém ou cria dinamicamente um Remote via Factory
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	local existing = Factory.getExisting(name, remoteType)
	if existing then return existing end
	return Factory.create(name, remoteType)
end

--- @public Cria uma rede completa a partir de uma estrutura de dicionário
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""
	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end
	return network
end

--- @public Conecta a um RemoteEvent com proteção Anti-Spam automática integrada
function NetworkService.onEvent(remoteName: string, remoteType: RemoteType, callback: (Player, ...any) -> (), customLimit: number?): RBXScriptConnection
	local remote = NetworkService.getRemote(remoteName, remoteType) :: RemoteEvent
	
	return remote.OnServerEvent:Connect(function(player, ...)
		if NetworkService._isSpamming(player, remoteName, customLimit) then return end
		callback(player, ...)
	end)
end

--- @public Transmissão otimizada para todos, exceto uma lista específica (Algoritmo O(1)/O(n))
function NetworkService.fireExcept(remote: RemoteEvent | UnreliableRemoteEvent, except: {Player}, ...: any)
	assert(remote, "[NetworkService] Remote não definido")
	local allPlayers = Players:GetPlayers()
	
	if #except > LOOK_UP_THRESHOLD then
		-- Uso de Hashmap para grandes volumes de exceção
		local lookup = {}
		for _, p in except do lookup[p] = true end
		for _, p in allPlayers do
			if not lookup[p] then remote:FireClient(p, ...) end
		end
	else
		-- Busca linear eficiente para pequenos volumes
		for _, p in allPlayers do
			if not table.find(except, p) then remote:FireClient(p, ...) end
		end
	end
end

--- @public Atalho seguro para FireClient
function NetworkService.fire(remote: RemoteEvent | UnreliableRemoteEvent, player: Player, ...: any)
	if not (remote and player) then return end
	remote:FireClient(player, ...)
end

--- @public Atalho seguro para FireAllClients
function NetworkService.fireAll(remote: RemoteEvent | UnreliableRemoteEvent, ...: any)
	if not remote then return end
	remote:FireAllClients(...)
end

return NetworkService
