-- =============================================================================
--  Nemu: OpenAI Provider
-- =============================================================================
local curl = require("plenary.curl")
local M = {}

-- core config
M.api_key_name = "OPENAI_API_KEY"
M.endpoint = "https://api.openai.com/v1/chat/completions"

-- role mapping for openai format
M.role_map = {
    user = "user",
    assistant = "assistant",
    system = "system"
}

-- parse messages into openai format
function M.parse_messages(opts)
    local messages = {}

    -- add system prompt first if exists
    if opts.system_prompt then
        table.insert(messages, {
            role = "system",
            content = opts.system_prompt
        })
    end

    -- add conversation messages
    for _, msg in ipairs(opts.messages) do
        table.insert(messages, {
            role = M.role_map[msg.role],
            content = msg.content
        })
    end

    return messages
end

-- parse streaming response chunks
function M.parse_response(data_stream, _, opts)
    -- skip empty lines
    if data_stream == "" or data_stream == "data: [DONE]" then return end

    -- remove "data: " prefix
    data_stream = data_stream:gsub("^data: ", "")

    -- try to parse json
    local ok, parsed = pcall(vim.json.decode, data_stream)
    if not ok then return end

    -- extract content delta if exists
    if parsed.choices and parsed.choices[1].delta.content then
        opts.on_chunk(parsed.choices[1].delta.content)
    end

    -- check for finish reason
    if parsed.choices and parsed.choices[1].finish_reason then
        opts.on_complete()
    end
end

-- get api key from env
function M.parse_api_key()
    local key = vim.env[M.api_key_name]
    if not key then
        error("OpenAI API key not found. Please set " .. M.api_key_name)
    end
    return key
end

-- construct curl args for request
function M.parse_curl_args(provider, prompt_opts)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. M.parse_api_key()
    }

    local messages = M.parse_messages(prompt_opts)

    return {
        url = M.endpoint,
        headers = headers,
        body = {
            model = provider.model or "gpt-4o-mini",
            messages = messages,
            stream = true,
            temperature = provider.temperature or 0.7
        }
    }
end

return M
