--!strict
-- NetworkService.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REFERÊNCIAS 
local Factory = require(script.Parent.NetworkFactory)
local Logger = require(ReplicatedStorage.Shared.Logger)

-- IMPORTANTE
local SerdeFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Serdes")

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

-- Configurações
local LOOK_UP_THRESHOLD = 24
local DEFAULT_RATE_LIMIT = 0.1 -- 100ms entre disparos

local NetworkService = {}

-- Tabelas de Estado e Cache de Serdes
local RateLimitMap: { [number]: { [string]: number } } = {} -- Usando UserId para estabilidade
local Serdes: { [string]: any } = {}

--  Carregamento de Camadas de Serialização
for _, module in SerdeFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		Serdes[module.Name] = require(module)
	end
end

-- Limpeza de memória (Prevenção de Memory Leak)
Players.PlayerRemoving:Connect(function(player)
	RateLimitMap[player.UserId] = nil
end)

-- MÉTODOS PRIVADOS --

--- @private Lógica de controle de fluxo com Logger integrado
function NetworkService._isSpamming(player: Player, remoteName: string, customLimit: number?): boolean
	local now = os.clock()
	local limit = customLimit or DEFAULT_RATE_LIMIT
	local pId = player.UserId
	
	if not RateLimitMap[pId] then RateLimitMap[pId] = {} end
	
	local lastCall = RateLimitMap[pId][remoteName] or 0
	if (now - lastCall) < limit then
		Logger.Warn("Security", `Rate Limit atingido: {player.Name} no Remote: {remoteName}`)
		return true 
	end
	
	RateLimitMap[pId][remoteName] = now
	return false
end

--- @private Processa Buffers usando a lógica binária organizada
function NetworkService._processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Tenta encontrar um Serde compatível (Ex: CFrameSerde)
			if Serdes.CFrameSerde then
				args[i] = Serdes.CFrameSerde.Deserialize(nil, v)
			end
		end
	end
	return args
end

--  MÉTODOS PÚBLICOS --

--- @public Valida tipos de argumentos (Anti-Exploit)
function NetworkService.validate(args: {any}, expectedTypes: {string}): boolean
	for i, expectedType in expectedTypes do
		if typeof(args[i]) ~= expectedType then
			Logger.Error("Security", `Contrato violado! Pos {i} esperava {expectedType}, recebeu {typeof(args[i])}`)
			return false
		end
	end
	return true
end

--- @public Obtém ou cria dinamicamente um Remote via Factory
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	local existing = Factory.getExisting(name, remoteType)
	if existing then return existing end
	
	Logger.Info("Network", `Criando novo Remote: {name} ({remoteType})`)
	return Factory.create(name, remoteType)
end

--- @public [BRIDGE PATTERN]: Gera uma tabela de remotes pronta para uso
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""
	
	Logger.Debug("Network", "Gerando Bridge de rede...")
	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end
	
	return network
end

--- @public Ouvinte de eventos com todas as camadas de proteção ativas
function NetworkService.onEvent(remoteName: string, remoteType: RemoteType, callback: (Player, ...any) -> (), customLimit: number?): RBXScriptConnection
	local remote = NetworkService.getRemote(remoteName, remoteType) :: RemoteEvent
	
	return remote.OnServerEvent:Connect(function(player, ...)
		-- Anti-Spam
		if NetworkService._isSpamming(player, remoteName, customLimit) then return end
		
		-- Deserialização (SerdeLayer)
		local processedArgs = NetworkService._processIncomingArgs({...})
		
		-- Execução Protegida
		task.spawn(function()
			local success, err = pcall(callback, player, unpack(processedArgs))
			if not success then
				Logger.Error("Execution", `Erro no Remote {remoteName}: {err}`)
			end
		end)
	end)
end

-- TRANSMISSÃO (FIRE) --

function NetworkService.fire(remote: RemoteEvent | UnreliableRemoteEvent, player: Player, ...: any)
	if not (remote and player) then 
		Logger.Warn("Network", "Tentativa de FireClient em Remote/Player nulo")
		return 
	end
	remote:FireClient(player, ...)
end

function NetworkService.fireAll(remote: RemoteEvent | UnreliableRemoteEvent, ...: any)
	if not remote then return end
	remote:FireAllClients(...)
end

--- @public Transmissão otimizada para exclusão de jogadores
function NetworkService.fireExcept(remote: RemoteEvent | UnreliableRemoteEvent, except: {Player}, ...: any)
	if not remote then return end
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

return NetworkService
