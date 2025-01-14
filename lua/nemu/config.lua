-- =============================================================================
--  Nemu: Configuration
-- =============================================================================
local M = {}

-- Default configuration
M.options = {
    -- AI model providers
    provider = "openai", -- or "claude", "gemini", etc.

    openai = {
        api_key = "YOUR_OPENAI_API_KEY",
        model = "gpt-3.5-turbo",
        temperature = 0.7,
    },
    claude = {
        api_key = "YOUR_ANTHROPIC_API_KEY",
        model = "claude-v1",
    },
    gemini = {
        base_url = "http://localhost:port",
        -- ...other config
    },

    -- Additional configuration
    diff = {
        highlight_group_added = "DiffAdd",
        highlight_group_removed = "DiffDelete",
        highlight_group_changed = "DiffChange",
    },

    panel = {
        width = "30%",
        position = "right",
        border = "rounded",
    },
}

-- -----------------------------------------------------------------------------
--  Setup
-- -----------------------------------------------------------------------------
function M.setup(opts)
    if opts then
        M.options = vim.tbl_deep_extend("force", M.options, opts)
    end
end

return M
