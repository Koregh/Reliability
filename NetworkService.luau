--!strict
-- NetworkService.lua (Servidor)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REFERÊNCIAS
local Factory = require(script.Parent.NetworkFactory)
local Logger = require(ReplicatedStorage.Shared.Logger)
local SerdeLayer = require(ReplicatedStorage.Shared.SerdeLayer) 

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

-- Configurações
local LOOK_UP_THRESHOLD = 24
local DEFAULT_RATE_LIMIT = 0.1 

local NetworkService = {}

-- Tabelas de Estado
local RateLimitMap: { [number]: { [string]: number } } = {}

-- Limpeza de memória
Players.PlayerRemoving:Connect(function(player)
	RateLimitMap[player.UserId] = nil
end)

-- MÉTODOS PRIVADOS --

--- @private Lógica de Anti-Spam
function NetworkService._isSpamming(player: Player, remoteName: string, customLimit: number?): boolean
	local now = os.clock()
	local limit = customLimit or DEFAULT_RATE_LIMIT
	local pId = player.UserId
	
	if not RateLimitMap[pId] then RateLimitMap[pId] = {} end
	
	local lastCall = RateLimitMap[pId][remoteName] or 0
	if (now - lastCall) < limit then
		Logger.Warn("Security", `Rate Limit: {player.Name} em '{remoteName}'`)
		return true 
	end
	
	RateLimitMap[pId][remoteName] = now
	return false
end

--- @private DESERIALIZAÇÃO AUTOMÁTICA
function NetworkService._processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Se for buffer, tentamos o CFrame por padrão ou o tipo definido no contrato
			-- Em um sistema avançado, você pode ler o primeiro byte do buffer para saber o tipo
			if SerdeLayer.CFrame then
				args[i] = SerdeLayer.CFrame.Deserialize(nil, v)
			end
		end
	end
	return args
end

--- @private SERIALIZAÇÃO AUTOMÁTICA
function NetworkService._processOutgoingArgs(args: {any})
	for i, v in args do
		local typeName = typeof(v)
		local compressor = SerdeLayer[typeName]
		
		if compressor and compressor.Serialize then
			args[i] = compressor.Serialize(nil, v)
		end
	end
	return args
end

-- MÉTODOS PÚBLICOS --

function NetworkService.onEvent(remoteName: string, remoteType: RemoteType, callback: (Player, ...any) -> (), customLimit: number?): RBXScriptConnection
	local remote = NetworkService.getRemote(remoteName, remoteType) :: RemoteEvent
	
	return remote.OnServerEvent:Connect(function(player, ...)
		if NetworkService._isSpamming(player, remoteName, customLimit) then return end
		
		local processedArgs = NetworkService._processIncomingArgs({...})
		
		task.spawn(function()
			local success, err = pcall(callback, player, unpack(processedArgs))
			if not success then
				Logger.Error("Execution", `Erro no callback '{remoteName}': {err}`)
			end
		end)
	end)
end

function NetworkService.fire(remote: RemoteEvent | UnreliableRemoteEvent, player: Player, ...: any)
	if not (remote and player) then return end
	local args = NetworkService._processOutgoingArgs({...})
	remote:FireClient(player, unpack(args))
end

function NetworkService.fireAll(remote: RemoteEvent | UnreliableRemoteEvent, ...: any)
	if not remote then return end
	local args = NetworkService._processOutgoingArgs({...})
	remote:FireAllClients(unpack(args))
end

--- @public Obtém ou cria via Factory
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	local existing = Factory.getExisting(name, remoteType)
	if existing then return existing end
	return Factory.create(name, remoteType)
end

--- @public Bridge Generator
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""
	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end
	return network
end

return NetworkService
