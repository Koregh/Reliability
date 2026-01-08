--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Factory = require(script.Parent.NetworkFactory)

-- IMPORTANTE: Pasta onde ficam todos os seus módulos de Serde (CFrame, Vector3, etc)
local SerdeFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Serdes")

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

-- Configurações de Engenharia
local LOOK_UP_THRESHOLD = 24
local DEFAULT_RATE_LIMIT = 0.1 -- 10 chamadas por segundo

local NetworkService = {}

-- Tabelas de Estado e Cache de Serdes
local RateLimitMap: { [Player]: { [string]: number } } = {}
local Serdes: { [string]: any } = {}

-- Carregamento Automático de Camadas de Serialização (Middlewares)
for _, module in SerdeFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		Serdes[module.Name] = require(module)
	end
end

-- Limpeza de memória (Prevenção de Memory Leak)
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

--- @private Processa argumentos brutos e converte Buffers usando Serdes carregados
function NetworkService._processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Aqui o sistema tenta reconstruir o dado. 
			-- Exemplo: Se tiver CFrameSerde na pasta, ele aplica ao buffer.
			if Serdes.CFrameSerde then
				args[i] = Serdes.CFrameSerde.Deserialize(nil, v)
			end
			-- Você pode expandir aqui para detectar IDs de tipo dentro do buffer
		end
	end
	return args
end

--- @public Valida se os tipos de argumentos são os esperados (Anti-Exploit)
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

--- @public Cria uma rede completa a partir de um dicionário (Bridge pattern)
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""
	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end
	return network
end

--- @public Conecta a um RemoteEvent com Anti-Spam e Deserialização automática de Buffers
function NetworkService.onEvent(remoteName: string, remoteType: RemoteType, callback: (Player, ...any) -> (), customLimit: number?): RBXScriptConnection
	local remote = NetworkService.getRemote(remoteName, remoteType) :: RemoteEvent
	
	return remote.OnServerEvent:Connect(function(player, ...)
		-- Verifica Spam
		if NetworkService._isSpamming(player, remoteName, customLimit) then return end
		
		-- Converte Buffers em dados legíveis (CFrame, etc)
		local processedArgs = NetworkService._processIncomingArgs({...})
		
		-- Executa a lógica do jogo
		callback(player, unpack(processedArgs))
	end)
end

--- @public Transmissão otimizada O(1) para grandes volumes de jogadores
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

--- @public Atalho seguro para FireClient
function NetworkService.fire(remote: RemoteEvent | UnreliableRemoteEvent, player: Player, ...: any)
	if not (remote and player) then return end
	remote:FireClient(player, ...)
end

--- @public Atalho seguro para FireAllClients (Broadcast)
function NetworkService.fireAll(remote: RemoteEvent | UnreliableRemoteEvent, ...: any)
	if not remote then return end
	remote:FireAllClients(...)
end

return NetworkService
