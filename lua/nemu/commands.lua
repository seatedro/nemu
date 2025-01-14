-- =============================================================================
--  Nemu: Slash Commands
-- =============================================================================
local config = require("nemu.config")

local M = {}

-- Example slash commands
M.slash_commands = {
  {
    title = "/now",
    description = "Insert current date/time.",
    handler = function()
      return os.date("%Y-%m-%d %H:%M:%S")
    end,
  },
  {
    title = "/symbols",
    description = "Insert common symbols.",
    handler = function()
      return "{}, [], (), <>"
    end,
  },
  {
    title = "/file",
    description = "Insert current file path.",
    handler = function()
      return vim.fn.expand("%:p")
    end,
  },
  {
    title = "/prompt",
    description = "Insert saved prompts (example).",
    handler = function()
      return "Placeholder for user-defined prompt"
    end,
  },
  {
    title = "/tab",
    description = "List open buffers/tabs.",
    handler = function()
      -- Simple example
      local buflist = vim.api.nvim_list_bufs()
      local result = {}
      for _, b in ipairs(buflist) do
        table.insert(result, vim.api.nvim_buf_get_name(b))
      end
      return table.concat(result, "\n")
    end,
  },
}

-- -----------------------------------------------------------------------------
--  Telescope Integration
-- -----------------------------------------------------------------------------
function M.setup()
  local has_telescope, telescope = pcall(require, "telescope")
  if not has_telescope then
    vim.notify("[Nemu] Telescope not found. Slash command picker will be disabled.")
    return
  end

  telescope.setup({}) -- your telescope config, if needed
  telescope.load_extension("fzf") -- if you have fzf extension, etc.
end

function M.open_slash_picker()
  local has_telescope, _ = pcall(require, "telescope.builtin")
  if not has_telescope then
    vim.notify("[Nemu] Telescope not found.", vim.log.levels.ERROR)
    return
  end

  local pick_items = {}
  for _, cmd in ipairs(M.slash_commands) do
    table.insert(pick_items, {
      display = cmd.title .. " – " .. cmd.description,
      value = cmd,
    })
  end

  require("telescope.pickers").new({}, {
    prompt_title = "Nemu Slash Commands",
    finder = require("telescope.finders").new_table({
      results = pick_items,
      entry_maker = function(item)
        return {
          value = item.value,
          display = item.display,
          ordinal = item.display,
        }
      end,
    }),
    sorter = require("telescope.config").values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      local run_command = function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection and selection.value and selection.value.handler then
          local result = selection.value.handler()
          -- Insert result into current buffer or panel
          vim.api.nvim_put({ result }, "c", true, true)
        end
      end

      map("i", "<CR>", run_command)
      map("n", "<CR>", run_command)
      return true
    end,
  }):find()
end

return M
