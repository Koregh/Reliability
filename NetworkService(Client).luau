--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Factory = require(script.Parent.NetworkFactory)

-- IMPORTANTE: Pasta onde ficam todos os Serdes (Shared)
local SerdeFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Serdes")

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}

-- Cache e Carregamento de Serdes
local NetworkCache: { [string]: any } = {}
local Serdes: { [string]: any } = {}

for _, module in SerdeFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		Serdes[module.Name] = require(module)
	end
end

--- @private Transforma dados em Buffers antes do envio (CFrame, Array, etc)
local function _processOutgoingArgs(args: {any})
	for i, v in args do
		-- Se for CFrame e você tiver o Serde, converte para buffer automaticamente
		if typeof(v) == "CFrame" and Serdes.CFrame then
			args[i] = Serdes.CFrame.Serialize(nil, v)
		elseif typeof(v) == "table" and Serdes.Array then
			args[i] = Serdes.Array.Serialize(nil, v)
		end
	end
	return args
end

--- @private Deserializa buffers recebidos do servidor
local function _processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			if Serdes.CFrame then
				args[i] = Serdes.CFrame.Deserialize(nil, v)
			end
		end
	end
	return args
end

--- @public Obtém um Remote com proteção de Cache e Timeout
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	if NetworkCache[name] then
		return NetworkCache[name]
	end

	local remote = Factory.waitForRemote(name, remoteType)
	NetworkCache[name] = remote
	
	return remote
end

--- @public Envia um evento para o servidor com compressão automática
function NetworkService.send(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType) :: RemoteEvent
	local processedArgs = _processOutgoingArgs({...})
	
	remote:FireServer(unpack(processedArgs))
end

--- @public Constrói uma rede completa
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""

	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end

	return network
end

--- @public Listener Seguro com Deserialização Automática
function NetworkService.onEvent(remote: RemoteEvent | UnreliableRemoteEvent, callback: (...any) -> ()): RBXScriptConnection
	return remote.OnClientEvent:Connect(function(...)
		-- Se o servidor enviar um buffer, o cliente converte de volta para CFrame/Array
		local processedArgs = _processIncomingArgs({...})
		callback(unpack(processedArgs))
	end)
end

return NetworkService
