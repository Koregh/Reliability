--!strict
-- NetworkService.lua (Servidor)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

--- @private DESERIALIZAÇÃO DINÂMICA (Lê o ID do Byte 0)
function NetworkService._processIncomingArgs(args: {any}, contract: {string}?)
	local processed = {}
	
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Busca o compressor correto pelo ID gravado no buffer
			local compressor = SerdeLayer.getCompressorFromBuffer(v)
			
			if compressor then
				local data = compressor.Deserialize(nil, v)
				
				-- VALIDAÇÃO DE CONTRATO (Anti-Exploit)
				if contract and contract[i] then
					if typeof(data) ~= contract[i] then
						Logger.Error("Security", `Contrato violado! Pos {i} esperava {contract[i]}, recebeu {typeof(data)}`)
						return nil -- Aborta se o tipo for malicioso
					end
				end
				
				table.insert(processed, data)
			else
				Logger.Warn("Network", "Recebi um buffer com ID não mapeado no SerdeLayer!")
			end
		else
			-- Dados que não são buffer (ex: strings puras ou números)
			if contract and contract[i] and typeof(v) ~= contract[i] then
				Logger.Error("Security", `Tipo puro inválido! Pos {i} esperava {contract[i]}`)
				return nil
			end
			table.insert(processed, v)
		end
	end
	
	return processed
end

--- @private SERIALIZAÇÃO AUTOMÁTICA (Para enviar ao Cliente)
function NetworkService._processOutgoingArgs(args: {any})
	local processed = {}
	for i, v in args do
		local typeName = typeof(v)
		local compressor = SerdeLayer[typeName] -- Busca por nome: "Vector3", "CFrame"
		
		if compressor and compressor.Serialize then
			table.insert(processed, compressor.Serialize(nil, v))
		else
			table.insert(processed, v)
		end
	end
	return processed
end

--- @public Ouvinte de Eventos com Suporte a Contrato
function NetworkService.onEvent(remoteName: string, remoteType: RemoteType, callback: (Player, ...any) -> (), customLimit: number?, contract: {string}?): RBXScriptConnection
	local remote = NetworkService.getRemote(remoteName, remoteType) :: RemoteEvent
	
	return remote.OnServerEvent:Connect(function(player, ...)
		if NetworkService._isSpamming(player, remoteName, customLimit) then return end
		
		-- Processa e Valida os argumentos
		local processedArgs = NetworkService._processIncomingArgs({...}, contract)
		
		-- Se a validação falhou, não executa o callback
		if not processedArgs then return end
		
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
