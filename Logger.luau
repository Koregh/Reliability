--!strict
local Logger = {}

-- CONFIGURAÇÃO

local DEBUG_MODE = true

-- NÍVEIS DE LOG
export type LogLevel = "DEBUG" | "INFO" | "SUCCESS" | "WARNING" | "ERROR"

local Levels = {
	DEBUG   = { prefix = "[DEBUG]",   color = "Grey" },
	INFO    = { prefix = "[INFO]",    color = "Blue" },
	SUCCESS = { prefix = "[SUCCESS]", color = "Green" },
	WARNING = { prefix = "[WARNING]", color = "Yellow" },
	ERROR   = { prefix = "[ERROR]",   color = "Red" }
}

-- FUNÇÃO CORE
local function _write(level: LogLevel, category: string, message: string)
	if level == "DEBUG" and not DEBUG_MODE then return end

	local timestamp = os.date("%H:%M:%S")
	local config = Levels[level]

	local output = string.format("%s %s [%s]: %s", 
		timestamp, 
		config.prefix, 
		category:upper(), 
		message
	)

	if level == "ERROR" then
		error(output) 
	elseif level == "WARNING" then
		warn(output)
	else
		print(output)
	end
end

function Logger.Debug(category: string, message: string)
	_write("DEBUG", category, message)
end

function Logger.Info(category: string, message: string)
	_write("INFO", category, message)
end

function Logger.Success(category: string, message: string)
	_write("SUCCESS", category, message)
end

function Logger.Warn(category: string, message: string)
	_write("WARNING", category, message)
end

function Logger.Error(category: string, message: string)
	_write("ERROR", category, message)
end

return Logger
