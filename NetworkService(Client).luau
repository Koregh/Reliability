--!strict
-- NetworkService (Client)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Factory = require(script.Parent.NetworkFactory)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Promise = require(ReplicatedStorage.Shared.Packages.Promise)
local SerdeLayer = require(ReplicatedStorage.Shared.SerdeLayer) 

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}
local NetworkCache: { [string]: any } = {}

--- @private SERIALIZAÇÃO (Cliente -> Servidor)
-- Transforma tipos complexos em Buffers com ID no Byte 0
local function _processOutgoingArgs(args: {any})
	local processed = {}
	for i, v in args do
		local t = typeof(v)
		local compressor = SerdeLayer[t]
		
		if compressor and compressor.Serialize then
			-- O Serialize de cada módulo já deve incluir o ID no Byte 0
			table.insert(processed, compressor.Serialize(nil, v))
		else
			table.insert(processed, v)
		end
	end
	return processed
end

--- @private DESERIALIZAÇÃO (Servidor -> Cliente)
-- Identifica o tipo do dado pelo ID gravado no buffer
local function _processIncomingArgs(args: {any})
	local processed = {}
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Usa a lógica de ID para encontrar o Serde correto
			local compressor = SerdeLayer.getCompressorFromBuffer(v)
			
			if compressor then
				table.insert(processed, compressor.Deserialize(nil, v))
			else
				Logger.Warn("Network", "Recebi um buffer do servidor com ID desconhecido.")
				table.insert(processed, v)
			end
		else
			table.insert(processed, v)
		end
	end
	return processed
end

function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	if NetworkCache[name] then return NetworkCache[name] end
	local remote = Factory.waitForRemote(name, remoteType)
	
	if not remote then
		Logger.Error("Network", `Remote timeout: {name}`)
		return nil
	end
	
	NetworkCache[name] = remote
	return remote
end

--- @public Envia dados ao servidor (Com compressão binária)
function NetworkService.send(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType)
	if not remote then return end
	
	local args = _processOutgoingArgs({...})
	remote:FireServer(unpack(args))
end

--- @public Requisita um dado do servidor (Via Promise)
function NetworkService.request(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType) :: RemoteFunction
	if not remote then return Promise.reject("Remote not found") end
	
	local args = _processOutgoingArgs({...})
	
	return Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
		
		if success then
			-- Deserializa o retorno do servidor caso seja um buffer
			resolve(_processIncomingArgs({result})[1])
		else
			Logger.Error("Network", `Request failed: {name}`)
			reject(result)
		end
	end)
end

--- @public Escuta eventos vindos do servidor
function NetworkService.onEvent(remote: RemoteEvent | UnreliableRemoteEvent, callback: (...any) -> ()): RBXScriptConnection
	return remote.OnClientEvent:Connect(function(...)
		local args = _processIncomingArgs({...})
		task.spawn(function()
			local success, err = pcall(callback, unpack(args))
			if not success then 
				Logger.Error("Execution", `UI Callback Error: {err}`) 
			end
		end)
	end)
end

return NetworkService
