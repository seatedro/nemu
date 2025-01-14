-- =============================================================================
--  Nemu: Inline Assistant with Floating Prompt
-- =============================================================================
local config = require("nemu.config")
local diff = require("nemu.diff")

-- AI providers
local providers = {
    openai = require("nemu.providers.openai"),
    claude = require("nemu.providers.anthropic"),
    gemini = require("nemu.providers.gemini"),
}

local M = {}

-- Internal variables to store state
local selected_text_cache = nil

-- -----------------------------------------------------------------------------
--  Utility: Get the current provider
-- -----------------------------------------------------------------------------
local function get_provider()
    local provider_name = config.options.provider
    local provider = providers[provider_name]
    return provider or nil
end

-- -----------------------------------------------------------------------------
--  1. open_floating_prompt()
--  Captures the selected text, then opens a floating textbox for the user prompt
-- -----------------------------------------------------------------------------
function M.open_floating_prompt()
    -- Make sure the user has visual selection
    local mode = vim.fn.mode()
    if mode ~= "v" and mode ~= "V" and mode ~= "\x16" then
        vim.notify("[Nemu] Please select text in visual mode first.", vim.log.levels.ERROR)
        return
    end

    -- Grab selected text
    local start_line, start_col = unpack(vim.fn.getpos("v"), 2, 3)
    local end_line, end_col = unpack(vim.fn.getpos("."), 2, 3)
    if start_line > end_line or (start_line == end_line and start_col > end_col) then
        -- Swap if user selected backward
        start_line, end_line = end_line, start_line
        start_col, end_col = end_col, start_col
    end

    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    if #lines == 0 then
        vim.notify("[Nemu] No text selected.", vim.log.levels.ERROR)
        return
    end

    -- Trim lines to the exact selection
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
    lines[1] = string.sub(lines[1], start_col)
    selected_text_cache = table.concat(lines, "\n")

    -- Now open a floating window to let the user modify or add a prompt
    M.create_prompt_window()
end

-- -----------------------------------------------------------------------------
--  2. create_prompt_window()
--  Actually create a floating buffer for user input
-- -----------------------------------------------------------------------------
function M.create_prompt_window()
    -- If there's already a prompt window open, do nothing (or you can close & re-open).
    if M.prompt_win and vim.api.nvim_win_is_valid(M.prompt_win) then
        vim.notify("[Nemu] Prompt window is already open.")
        return
    end

    -- Create a scratch buffer
    M.prompt_buf = vim.api.nvim_create_buf(false, true)
    if not M.prompt_buf then
        vim.notify("[Nemu] Failed to create prompt buffer.", vim.log.levels.ERROR)
        return
    end

    -- Dimensions for the floating window
    local width = math.floor(vim.o.columns * 0.5)
    local height = 6
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    M.prompt_win = vim.api.nvim_open_win(M.prompt_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        zindex = 100,
    })

    -- Set buffer options
    vim.api.nvim_buf_set_name(M.prompt_buf, "NemuPrompt")
    vim.api.nvim_buf_set_option(M.prompt_buf, "filetype", "NemuPrompt")
    vim.api.nvim_buf_set_option(M.prompt_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(M.prompt_buf, "buftype", "prompt")
    vim.fn.prompt_setprompt(M.prompt_buf, "Enter your AI prompt (Press <CR> to confirm): ")

    -- Pre-fill the buffer with a small hint or the selected text if you want
    vim.api.nvim_buf_set_lines(M.prompt_buf, 0, -1, false, {
        "",
        "-- Selected code context is stored internally. Type your additional prompt below --",
        "",
    })

    -- Map <CR> in insert mode (and normal mode if you like) to confirm the prompt
    vim.api.nvim_buf_set_keymap(
        M.prompt_buf,
        "i",
        "<CR>",
        "<ESC>:lua require('nemu.assistant').confirm_prompt()<CR>",
        { nowait = true, noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        M.prompt_buf,
        "n",
        "<CR>",
        ":lua require('nemu.assistant').confirm_prompt()<CR>",
        { nowait = true, noremap = true, silent = true }
    )
end

-- -----------------------------------------------------------------------------
--  3. confirm_prompt()
--  Triggered when user presses <CR> in the floating prompt
-- -----------------------------------------------------------------------------
function M.confirm_prompt()
    if not (M.prompt_buf and vim.api.nvim_buf_is_valid(M.prompt_buf)) then
        vim.notify("[Nemu] No valid prompt buffer to confirm.", vim.log.levels.ERROR)
        return
    end

    -- Collect lines from the prompt buffer
    local lines = vim.api.nvim_buf_get_lines(M.prompt_buf, 0, -1, false)
    local user_prompt = table.concat(lines, "\n")

    -- Close the floating window
    vim.api.nvim_win_close(M.prompt_win, true)
    M.prompt_win = nil
    M.prompt_buf = nil

    -- Combine user prompt + selected context if desired
    local final_prompt = ""
    if selected_text_cache and selected_text_cache ~= "" then
        final_prompt = "Selected Code:\n" .. selected_text_cache .. "\n\nUser Prompt:\n" .. user_prompt
    else
        final_prompt = user_prompt
    end

    -- Now we can send the final prompt to the AI
    M.send_prompt_to_ai(final_prompt)
end

-- -----------------------------------------------------------------------------
--  4. send_prompt_to_ai(prompt)
--  Actually dispatch prompt to the configured AI provider and show streaming diff
-- -----------------------------------------------------------------------------
function M.send_prompt_to_ai(prompt)
    local provider = get_provider()
    if not provider then
        vim.notify("[Nemu] No valid AI provider found in config.", vim.log.levels.ERROR)
        return
    end

    -- Initialize diff view
    local bufnr = vim.api.nvim_get_current_buf()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    require("nemu.diff").init_diff(
        bufnr,
        start_pos[2], -- start line
        end_pos[2],   -- end line
        selected_text_cache or ""
    )

    -- Send to provider
    provider.stream_request(prompt, {
        on_chunk = function(chunk)
            require("nemu.diff").stream_chunk(chunk)
        end,
        on_complete = function()
            require("nemu.diff").end_stream()
        end,
        on_error = function(err)
            vim.notify("[Nemu] Error: " .. err, vim.log.levels.ERROR)
            require("nemu.diff").reset()
        end
    })
end

return M
