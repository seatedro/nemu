-- =============================================================================
--  Nemu: Gemini / Custom Provider
-- =============================================================================
local config = require("nemu.config")

local M = {}

function M.send_request(prompt, callback)
  -- Placeholder for custom or local model integration.
  local opts = config.options.gemini
  local base_url = opts.base_url or "http://localhost:1234"

  -- Example command (not real):
  local cmd = string.format("echo 'Gemini local response to: %s'", prompt)
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()
    callback(result, nil)
  else
    callback(nil, "Failed to get response from Gemini.")
  end
end

return M
