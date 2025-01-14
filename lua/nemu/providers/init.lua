local M = {}

-- internal state management for providers
local E = {
    cache = {},
    REQUEST_LOGIN_PATTERN = "NemuRequestLogin"
}

-- base provider interface
---@class NemuBaseProvider
---@field endpoint? string
---@field model? string
---@field local? boolean
---@field proxy? string
---@field timeout? integer
---@field api_key_name? string
---@field parse_response fun(data_stream: string, event_state: string, opts: table): nil
---@field parse_messages fun(opts: table): table
---@field parse_curl_args fun(provider: table, code_opts: table): table

-- implementations for each provider:
M.openai = require("nemu.providers.openai")
M.anthropic = require("nemu.providers.anthropic")
M.gemini = require("nemu.providers.gemini")

-- key features each provider needs:
-- 1. proper message parsing (user/assistant/system roles)
-- 2. streaming response handling
-- 3. curl args construction
-- 4. api key management
-- 5. error handling

-- helper utils for providers:
---@param provider NemuBaseProvider
function M.get_api_key(provider)
    -- handle api key fetching, caching, env vars
end

---@param provider NemuBaseProvider
---@param messages table
function M.stream_response(provider, messages)
    -- handle response streaming
end

---@param provider NemuBaseProvider
function M.validate_config(provider)
    -- validate provider config
end

return M
