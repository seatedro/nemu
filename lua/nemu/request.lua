-- =============================================================================
--  Nemu: Request Handler
-- =============================================================================
local curl = require("plenary.curl")
local Job = require("plenary.job")
local panel = require("nemu.panel")
local config = require("nemu.config")
local log = require("nemu.log")

local M = {}

-- internal state
M.current_provider = nil
M.message_history = {}

local function get_provider()
	if not M.current_provider then
		local provider_name = config.options.provider
		M.current_provider = require("nemu.providers")[provider_name]
		if not M.current_provider then
			log.error("Invalid provider: " .. provider_name, { notify = true })
			return nil
		end
	end
	return M.current_provider
end

local function handle_stream(chunk, provider)
	log.debug("Received chunk: " .. vim.inspect(chunk))

	local handlers = {
		on_chunk = function(text)
			log.debug("Processing chunk: " .. text)
			panel.stream_to_last_message(text)
		end,
		on_complete = function(_)
			vim.schedule(function()
				panel.enable_input()
			end)
		end,
	}

	local ok, err = pcall(function()
		provider.parse_response(chunk, nil, handlers)
	end)

	if not ok then
		log.error("Failed to parse response: " .. err, { notify = true })
	end
end

function M.send_message(content, opts)
	opts = opts or {}
	local provider = get_provider()
	if not provider then
		return
	end

	table.insert(M.message_history, {
		role = "user",
		content = content,
	})

	local request_opts = {
		messages = M.message_history,
		system_prompt = config.options.system_prompt,
	}

	local ok, curl_args = pcall(provider.parse_curl_args, provider, request_opts)
	if not ok then
		log.error("Failed to parse curl args: " .. curl_args, { notify = true })
		return
	end

	log.debug("Curl args: " .. vim.inspect(curl_args))

	local job = Job:new({
		command = "curl",
		args = {
			"--no-buffer",
			"-N", -- disable buffering
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-H",
			"Authorization: Bearer " .. provider.parse_api_key(),
			"--data-raw",
			vim.json.encode(curl_args.body),
			curl_args.url,
		},
		on_stdout = function(_, chunk)
			if chunk and chunk ~= "" then
				vim.schedule(function()
					handle_stream(chunk, provider)
				end)
			end
		end,
		on_stderr = function(_, chunk)
			-- fuck it, fuck the logs dawg.
			-- if chunk:match("^[%d%s%-/:%%]+$") then
			-- 	return -- Ignore progress lines
			-- end
			-- if chunk and chunk ~= "" then
			-- 	log.error("Curl error: " .. chunk, { notify = true })
			-- end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				log.error("Request failed with code: " .. code, { notify = true })
			end
		end,
	})

	panel.append_message("assistant", "")
	panel.disable_input()

	job:start()
end

-- inline completion request
---@param text string selected text
---@param prompt string user prompt
function M.request_completion(text, prompt)
	local provider = get_provider()
	if not provider then
		return
	end

	-- prepare request
	local request_opts = {
		messages = {
			{
				role = "user",
				content = string.format(
					[[
Context:
%s

Instructions:
%s
]],
					text,
					prompt
				),
			},
		},
		system_prompt = "You are a coding assistant. Provide direct code improvements or completions.",
	}

	local ok, curl_args = pcall(provider.parse_curl_args, provider, request_opts)
	if not ok then
		log.error("Failed to parse curl args: " .. curl_args, { notify = true })
		return
	end

	-- start streaming request
	local job = Job:new({
		command = "curl",
		args = {
			"--no-buffer",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-H",
			"Authorization: Bearer" .. provider.parse_api_key(),
			vim.json.encode(curl_args.body),
			curl_args.url,
		},
		on_stdout = function(_, chunk)
			if chunk and chunk ~= "" then
				vim.schedule(function()
					-- stream to diff view instead of panel
					require("nemu.diff").stream_chunk(chunk)
				end)
			end
		end,
		on_stderr = function(_, chunk)
			if chunk and chunk ~= "" then
				vim.schedule(function()
					vim.notify("Error: " .. chunk, vim.log.levels.ERROR)
				end)
			end
		end,
	})

	job:start()
end

-- helper to clear conversation history
function M.clear_history()
	M.message_history = {}
	-- also clear panel
	panel.clear()
end

-- switch provider
---@param name string provider name
function M.switch_provider(name)
	if config.options[name] then
		config.options.provider = name
		M.current_provider = nil
	else
		vim.notify("Invalid provider: " .. name, vim.log.levels.ERROR)
	end
end

return M
