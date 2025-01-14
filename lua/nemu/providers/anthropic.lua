-- =============================================================================
--  Nemu: Anthropic Provider
-- =============================================================================
local M = {}

-- core config
M.api_key_name = "ANTHROPIC_API_KEY"
M.use_xml_format = true

-- role mapping
M.role_map = {
    user = "user",
    assistant = "assistant"
}

---@class ClaudeMessage
---@field role "user" | "assistant"
---@field content {type: "text", text: string}[]

-- parse messages for claude's format
---@param opts {messages: table, system_prompt: string}
---@return ClaudeMessage[]
function M.parse_messages(opts)
    local messages = {}

    -- handle system prompt
    if opts.system_prompt then
        table.insert(messages, {
            role = "system",
            content = {
                {
                    type = "text",
                    text = opts.system_prompt
                }
            }
        })
    end

    -- handle conversation messages
    for _, msg in ipairs(opts.messages) do
        table.insert(messages, {
            role = M.role_map[msg.role],
            content = {
                {
                    type = "text",
                    text = msg.content
                }
            }
        })
    end

    return messages
end

-- handle streaming responses
function M.parse_response(data_stream, event_state, opts)
    if event_state == nil then
        if data_stream:match('"content_block_delta"') then
            event_state = "content_block_delta"
        elseif data_stream:match('"message_stop"') then
            event_state = "message_stop"
        end
    end

    if event_state == "content_block_delta" then
        local ok, json = pcall(vim.json.decode, data_stream)
        if not ok then return end
        opts.on_chunk(json.delta.text)
    elseif event_state == "message_stop" then
        opts.on_complete(nil)
        return
    elseif event_state == "error" then
        opts.on_complete(vim.json.decode(data_stream))
    end
end

-- construct curl args for api calls
function M.parse_curl_args(provider, prompt_opts)
    local headers = {
        ["Content-Type"] = "application/json",
        ["anthropic-version"] = "2023-06-01",
        ["x-api-key"] = provider.parse_api_key()
    }

    local messages = M.parse_messages(prompt_opts)

    return {
        url = provider.endpoint .. "/v1/messages",
        proxy = provider.proxy,
        insecure = provider.allow_insecure,
        headers = headers,
        body = {
            model = provider.model or "claude-3.5-sonnet-20241022",
            messages = messages,
            stream = true,
            temperature = provider.temperature or 0.7,
            max_tokens = provider.max_tokens or 2048
        }
    }
end

-- error handling
function M.on_error(result)
    if not result.body then
        return vim.notify("API request failed with status " .. result.status, vim.log.levels.ERROR)
    end

    local ok, body = pcall(vim.json.decode, result.body)
    if not (ok and body and body.error) then
        return vim.notify("Failed to parse error response", vim.log.levels.ERROR)
    end

    local error_msg = body.error.message
    local error_type = body.error.type

    -- handle common errors
    if error_type == "insufficient_quota" then
        error_msg = "You've exceeded your quota. Please check your plan and billing details."
    elseif error_type == "invalid_request_error" then
        error_msg = "Invalid request: " .. error_msg
    end

    vim.notify(error_msg, vim.log.levels.ERROR)
end

-- optional: helper functions
function M.format_prompt(text)
    if M.use_xml_format then
        return "<prompt>" .. text .. "</prompt>"
    end
    return text
end

function M.validate_config(config)
    if not config.api_key then
        error("Claude API key not set. Please set ANTHROPIC_API_KEY")
    end
    if not config.model then
        config.model = "claude-3.5-sonnet-20241022" -- default model
    end
end

return M
