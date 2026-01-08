--!strict
-- NetworkBridge.lua

export type RemoteType = "Reliable" | "Unreliable" | "Function"

-- Definimos a estrutura de cada sistema do jogo
local NetworkBridge = {
    -- Sistema de Combate (exemplo)
    Combat = {
        Attack = "Unreliable" :: RemoteType, -- Alta frequência (VFX/Som)
        TakeDamage = "Reliable" :: RemoteType, -- Importante (Cálculo de vida)
        BlockRequest = "Function" :: RemoteType -- Requer resposta (Server -> Client)
    },
    
    -- Sistema de Inventário (exemplo)
    Inventory = {
        EquipItem = "Reliable" :: RemoteType,
        DropItem = "Reliable" :: RemoteType,
        SortInventory = "Unreliable" :: RemoteType
    },
    
    -- Sistema de Dados/Sessão (exemplo)
    Data = {
        SyncStats = "Reliable" :: RemoteType,
        GetPlayerProfile = "Function" :: RemoteType
    }
}

return NetworkBridge

