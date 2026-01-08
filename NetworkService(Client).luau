--!strict
-- NetworkService (Client)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REFERÊNCIAS
local Factory = require(script.Parent.NetworkFactory)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Promise = require(ReplicatedStorage.Shared.Packages.Promise)
local SerdeLayer = require(ReplicatedStorage.Shared.SerdeLayer) 

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}
local NetworkCache: { [string]: any } = {}

-- MÉTODOS PRIVADOS --

--- @private Mapeamento automático via SerdeLayer
local function _processOutgoingArgs(args: {any})
	for i, v in args do
		local t = typeof(v)
		-- Se o SerdeLayer tiver um módulo com o nome do tipo (ex: CFrame, Vector3)
		if SerdeLayer[t] and SerdeLayer[t].Serialize then
			args[i] = SerdeLayer[t].Serialize(nil, v)
		elseif t == "table" and SerdeLayer.Dict then
			args[i] = SerdeLayer.Dict.Serialize(nil, v)
		end
	end
	return args
end

--- @private Deserialização automática
local function _processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Aqui você pode implementar uma lógica de Header se o SerdeLayer suportar
			-- Por padrão, tentamos o CFrame ou o que for esperado pelo contrato
			if SerdeLayer.CFrame then
				args[i] = SerdeLayer.CFrame.Deserialize(nil, v)
			end
		end
	end
	return args
end

-- MÉTODOS PÚBLICOS --

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

function NetworkService.send(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType)
	if not remote then return end
	remote:FireServer(unpack(_processOutgoingArgs({...})))
end

function NetworkService.request(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType) :: RemoteFunction
	local args = _processOutgoingArgs({...})
	
	return Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
		
		if success then
			resolve(_processIncomingArgs({result})[1])
		else
			Logger.Error("Network", `Request failed: {name}`)
			reject(result)
		end
	end)
end

function NetworkService.onEvent(remote: RemoteEvent | UnreliableRemoteEvent, callback: (...any) -> ()): RBXScriptConnection
	return remote.OnClientEvent:Connect(function(...)
		local args = _processIncomingArgs({...})
		task.spawn(function()
			local success, err = pcall(callback, unpack(args))
			if not success then Logger.Error("Execution", `UI Callback Error: {err}`) end
		end)
	end)
end

return NetworkService
