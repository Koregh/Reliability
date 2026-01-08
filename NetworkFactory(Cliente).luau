--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteType = "Reliable" | "Unreliable" | "Function"

local NetworkFactory = {}

-- Localização da infraestrutura (Aguarda a replicação do servidor)
local Storage = ReplicatedStorage:WaitForChild("ReliabilityStorage")

local Folders = {
	Reliable = Storage:WaitForChild("Reliables"),
	Unreliable = Storage:WaitForChild("Unreliables"),
	Function = Storage:WaitForChild("Functions"),
}

--- @public Localiza um remote de forma segura
function NetworkFactory.waitForRemote(name: string, remoteType: RemoteType): Instance
	local folder = Folders[remoteType]
	local remote = folder:WaitForChild(name, 10) -- Timeout de 10s para evitar travamento infinito
	
	if not remote then
		error(`[NetworkFactory] Timeout: Remote '{name}' não replicou do servidor.`)
	end
	
	return remote
end

return NetworkFactory

