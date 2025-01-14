-- =============================================================================
--  Nemu: Assistant Panel (Side Panel)
-- =============================================================================
local Popup = require("nui.popup")
local Layout = require("nui.layout")

local M = {}

-- message styles
M.message_styles = {
    system = { prefix = "󰋘 System", hl = "Comment" },
    user = { prefix = "󰭹 You", hl = "String" },
    assistant = { prefix = "󱙺 Assistant", hl = "Function" }
}

-- setup the panel
function M.setup()
    M.panel = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = " Nemu Assistant ",
                top_align = "left",
            },
        },
        buf_options = {
            modifiable = true,
            readonly = false,
        },
    })

    M.layout = Layout(
        {
            relative = "editor",
            position = {
                row = 0,
                col = "100%"
            },
            size = {
                width = "30%",
                height = "100%"
            },
        },
        Layout.Box({
            Layout.Box(M.panel, { size = "100%" })
        })
    )

    local function send_message()
        if M.input_disabled then return end

        local lines = vim.api.nvim_buf_get_lines(M.panel.bufnr, 0, -1, false)
        local last_msg = ""
        local msg_start = #lines
        local in_message = false

        -- collect the current message
        for i = #lines, 1, -1 do
            local line = lines[i]
            -- if we hit a prefix, we've found our message bounds
            if line:match("^󰭹 You") or line:match("^󱙺 Assistant") then
                if not in_message then
                    msg_start = i + 1
                    break
                end
            end
            in_message = true
            last_msg = line .. "\n" .. last_msg
        end

        last_msg = last_msg:gsub("\n+$", "")   -- trim trailing newlines

        if last_msg:gsub("%s+", "") ~= "" then -- if message isn't empty
            -- clear any empty lines at the end
            vim.api.nvim_buf_set_lines(M.panel.bufnr, msg_start, #lines, false, {})
            -- add the cleaned up message
            vim.api.nvim_buf_set_lines(M.panel.bufnr, msg_start - 1, msg_start - 1, false,
                vim.split(last_msg, "\n"))
            require("nemu.request").send_message(last_msg)
        end
    end

    -- ctrl+enter or ctrl+s sends the message
    M.panel:map('i', '<C-s>', send_message, { noremap = true })
    M.panel:map('n', '<C-s>', send_message, { noremap = true })
end

-- start a new user message
function M.start_new_message()
    if not M.panel or not M.panel.bufnr then return end

    local bufnr = M.panel.bufnr
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

    -- get current lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- add newline if buffer isn't empty
    if #lines > 0 and lines[#lines] ~= "" then
        table.insert(lines, "")
    end

    -- add user prefix
    table.insert(lines, M.message_styles.user.prefix)
    -- add empty line for typing
    table.insert(lines, "")

    -- update buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- highlight the prefix
    local header_line = #lines - 1
    vim.api.nvim_buf_add_highlight(bufnr, -1, M.message_styles.user.hl, header_line - 1, 0, -1)

    -- move cursor to the empty line we added
    if M.panel.winid then
        vim.api.nvim_win_set_cursor(M.panel.winid, { #lines, 0 })
    end
end

-- append a message to the panel
function M.append_message(role, content)
    if not M.panel or not M.panel.bufnr then return end

    local bufnr = M.panel.bufnr
    local style = M.message_styles[role]

    -- get current lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- add newline if buffer isn't empty
    if #lines > 0 and lines[#lines] ~= "" then
        table.insert(lines, "")
    end

    -- add role prefix
    -- table.insert(lines, style.prefix)

    -- split content into lines and add them
    if content and content ~= "" then
        for _, line in ipairs(vim.split(content, "\n")) do
            table.insert(lines, line)
        end
    end

    -- update buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- highlight prefix
    local prefix_line = #lines - (content and #vim.split(content, "\n") or 0) - 1
    vim.api.nvim_buf_add_highlight(bufnr, -1, style.hl, prefix_line, 0, -1)

    -- move cursor to end
    vim.api.nvim_win_set_cursor(M.panel.winid, { #lines, 0 })
end

-- stream content to the last message
function M.stream_to_last_message(content)
    if not M.panel or not M.panel.bufnr then return end

    local bufnr = M.panel.bufnr
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

    -- get current lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- find the last assistant message
    local last_assistant_line = 0
    for i = #lines, 1, -1 do
        if lines[i]:match("^󱙺 Assistant") then
            last_assistant_line = i
            break
        end
    end

    -- if no assistant message exists, create one
    if last_assistant_line == 0 then
        M.append_message("assistant", "")
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        last_assistant_line = #lines - 1
    end

    -- append content to the last assistant message
    local current_line = lines[last_assistant_line]
    local new_content = current_line .. content

    -- update the line
    lines[last_assistant_line] = new_content
    vim.api.nvim_buf_set_lines(bufnr, last_assistant_line - 1, last_assistant_line, false, { new_content })

    -- move cursor to end
    vim.api.nvim_win_set_cursor(M.panel.winid, { #lines, 0 })
end

-- show the panel
function M.show()
    if not M.layout then
        M.setup()
    end
    M.layout:mount()

    -- ensure we have a window before starting new message
    vim.schedule(function()
        if M.panel.winid then
            M.start_new_message()
        end
    end)
end

-- hide the panel
function M.hide()
    if M.layout then
        M.layout:unmount()
    end
end

-- toggle the panel
function M.toggle()
    if M.layout and M.layout.winid then
        M.hide()
    else
        M.show()
    end
end

-- clear the panel
function M.clear()
    if not M.panel or not M.panel.bufnr then return end
    vim.api.nvim_buf_set_lines(M.panel.bufnr, 0, -1, false, {})
end

function M.disable_input()
    if not M.panel or not M.panel.bufnr then return end
    M.input_disabled = true
    vim.api.nvim_buf_set_option(M.panel.bufnr, "modifiable", false)
end

-- update enable_input() to start new message:
function M.enable_input()
    if not M.panel or not M.panel.bufnr then return end
    M.input_disabled = false
    vim.api.nvim_buf_set_option(M.panel.bufnr, "modifiable", true)
    M.start_new_message()
end

return M
