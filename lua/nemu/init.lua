-- =============================================================================
--  Nemu: Main Plugin Entry
-- =============================================================================
local M = {}

-- Load our submodules
local config = require("nemu.config")
local commands = require("nemu.commands")
local assistant = require("nemu.assistant")
local panel = require("nemu.panel")
local diff = require("nemu.diff")

-- -----------------------------------------------------------------------------
--  Setup
-- -----------------------------------------------------------------------------
function M.setup(user_config)
    -- Merge user config with defaults
    config.setup(user_config)

    -- Initialize slash commands with Telescope integration
    commands.setup()

    -- Setup keymaps for inline assistant
    -- Instead of calling trigger_inline_assistant() directly, we open a floating textbox.
    vim.keymap.set("v", "<Leader>n", function()
        local mode = vim.fn.mode()
        if mode == 'v' or mode == 'V' or mode == '\22' then
            assistant.open_floating_prompt()
        else
            vim.notify("[Nemu] Please select text in visual mode first.", vim.log.levels.ERROR)
        end
    end, { noremap = true, silent = true })

    -- Create user commands
    vim.api.nvim_create_user_command(
        "NemuPanel",
        function() panel.toggle() end,
        { desc = "Toggle the Nemu assistant side panel." }
    )

    vim.api.nvim_create_user_command(
        "NemuSlash",
        function() commands.open_slash_picker() end,
        { desc = "Open the slash command picker (Telescope)." }
    )

    vim.api.nvim_create_user_command(
        "NemuAccept",
        function() diff.accept_live_patch() end,
        { desc = "Accept the currently streamed AI diff." }
    )

    vim.api.nvim_create_user_command(
        "NemuReject",
        function() diff.reject_live_patch() end,
        { desc = "Reject the currently streamed AI diff (Not fully implemented yet)." }
    )

    vim.keymap.set("n", "<Tab>", function()
        require("nemu.diff").cycle_suggestion("next")
    end, { desc = "Cycle to next suggestion" })

    vim.keymap.set("n", "<S-Tab>", function()
        require("nemu.diff").cycle_suggestion("prev")
    end, { desc = "Cycle to previous suggestion" })

    -- Quick accept/reject
    vim.keymap.set("n", "<Leader>a", function()
        require("nemu.diff").accept_current()
    end, { desc = "Accept current suggestion" })

    vim.keymap.set("n", "<Leader>r", function()
        require("nemu.diff").reject_all()
    end, { desc = "Reject all suggestions" })
end

return M
