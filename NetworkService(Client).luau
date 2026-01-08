--!strict
-- NetworkService (Client)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REFERÊNCIAS
local Factory = require(script.Parent.NetworkFactory)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Promise = require(ReplicatedStorage.Shared.Packages.Promise)

-- PASTA DE SERIALIZAÇÃO
local SerdeFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Serdes")

export type RemoteType = Factory.RemoteType
export type NetworkStructure = { [string]: RemoteType }

local NetworkService = {}

-- Cache e Carregamento de Serdes
local NetworkCache: { [string]: any } = {}
local Serdes: { [string]: any } = {}

-- [INICIALIZAÇÃO]: Carrega todos os compressores (CFrame, Vector3, etc)
for _, module in SerdeFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		Serdes[module.Name] = require(module)
	end
end

-- MÉTODOS PRIVADOS --

--- @private Converte tipos pesados em Buffers (Otimização de Banda)
local function _processOutgoingArgs(args: {any})
	for i, v in args do
		-- Exemplo: Se enviar CFrame e houver compressor, vira buffer
		if typeof(v) == "CFrame" and Serdes.CFrameSerde then
			args[i] = Serdes.CFrameSerde.Serialize(nil, v)
		elseif typeof(v) == "table" and Serdes.ArraySerde then
			args[i] = Serdes.ArraySerde.Serialize(nil, v)
		end
	end
	return args
end

--- @private Converte Buffers recebidos do servidor em dados legíveis
local function _processIncomingArgs(args: {any})
	for i, v in args do
		if typeof(v) == "buffer" then
			-- Detecta o tipo pelo Serde disponível (Expanda conforme necessário)
			if Serdes.CFrameSerde then
				args[i] = Serdes.CFrameSerde.Deserialize(nil, v)
			end
		end
	end
	return args
end

-- MÉTODOS PÚBLICOS --

--- @public Obtém um Remote com proteção de Cache e Log
function NetworkService.getRemote(name: string, remoteType: RemoteType): any
	if NetworkCache[name] then return NetworkCache[name] end

	Logger.Debug("Network", `Aguardando Remote: {name}`)
	local remote = Factory.waitForRemote(name, remoteType)
	
	if not remote then
		Logger.Error("Network", `Tempo esgotado ao esperar por: {name}`)
		return nil
	end
	
	NetworkCache[name] = remote
	return remote
end

--- @public Envia um sinal ao servidor com compressão automática
function NetworkService.send(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType) :: RemoteEvent
	if not remote then return end
	
	local processedArgs = _processOutgoingArgs({...})
	remote:FireServer(unpack(processedArgs))
end

--- @public [PROMISE] Faz uma requisição assíncrona (Substitui o Invoke)
function NetworkService.request(name: string, remoteType: RemoteType, ...: any)
	local remote = NetworkService.getRemote(name, remoteType) :: RemoteFunction
	local processedArgs = _processOutgoingArgs({...})
	
	return Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return remote:InvokeServer(unpack(processedArgs))
		end)
		
		if success then
			resolve(_processIncomingArgs({result})[1])
		else
			Logger.Error("Network", `Falha no Request '{name}': {result}`)
			reject(result)
		end
	end)
end

--- @public [BRIDGE] Constrói uma rede completa via estrutura
function NetworkService.getNetwork(structure: NetworkStructure, prefix: string?): { [string]: any }
	local network = {}
	local remotePrefix = prefix or ""

	Logger.Info("Network", "Sincronizando Bridge no Cliente...")
	for name, remoteType in structure do
		network[name] = NetworkService.getRemote(remotePrefix .. name, remoteType)
	end

	return network
end

--- @public Listener com Deserialização Automática integrada
function NetworkService.onEvent(remote: RemoteEvent | UnreliableRemoteEvent, callback: (...any) -> ()): RBXScriptConnection
	return remote.OnClientEvent:Connect(function(...)
		local processedArgs = _processIncomingArgs({...})
		
		-- Execução protegida no cliente para não quebrar o listener
		task.spawn(function()
			local success, err = pcall(callback, unpack(processedArgs))
			if not success then
				Logger.Error("Execution", `Erro no callback do cliente: {err}`)
			end
		end)
	end)
end

return NetworkService
