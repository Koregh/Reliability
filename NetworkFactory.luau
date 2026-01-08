--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteType = "Reliable" | "Unreliable" | "Function"

local NetworkFactory = {}

-- Configuração de Infraestrutura
local ReliabilityStorage = ReplicatedStorage:FindFirstChild("ReliabilityStorage") or Instance.new("Folder")
ReliabilityStorage.Name = "ReliabilityStorage"
ReliabilityStorage.Parent = ReplicatedStorage

local Folders: { [RemoteType]: Folder } = {
	Reliable = (ReliabilityStorage:FindFirstChild("Reliables") or Instance.new("Folder", ReliabilityStorage)) :: Folder,
	Unreliable = (ReliabilityStorage:FindFirstChild("Unreliables") or Instance.new("Folder", ReliabilityStorage)) :: Folder,
	Function = (ReliabilityStorage:FindFirstChild("Functions") or Instance.new("Folder", ReliabilityStorage)) :: Folder,
}

Folders.Reliable.Name = "Reliables"
Folders.Unreliable.Name = "Unreliables"
Folders.Function.Name = "Functions"

-- Função pura de criação
function NetworkFactory.create(name: string, remoteType: RemoteType): Instance
	local instance: Instance
	
	if remoteType == "Function" then
		instance = Instance.new("RemoteFunction")
	else
		instance = Instance.new((remoteType == "Unreliable" and "Unreliable" or "") .. "RemoteEvent")
	end
	
	instance.Name = name
	instance.Parent = Folders[remoteType]
	return instance
end

function NetworkFactory.getExisting(name: string, remoteType: RemoteType): Instance?
	return Folders[remoteType]:FindFirstChild(name)
end

return NetworkFactory

