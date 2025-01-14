local api = vim.api

local M = {}

---@class Suggestion
---@field text string
---@field index number
---@field total number

---@class DiffState
---@field original_text string
---@field suggestions Suggestion[]
---@field current_index number
---@field ns_id number
---@field buf_id number
---@field start_line number
---@field end_line number
---@field is_streaming boolean
local state = {
    original_text = nil,
    suggestions = {},
    current_index = 1,
    ns_id = api.nvim_create_namespace("NemuDiff"),
    buf_id = nil,
    start_line = nil,
    end_line = nil,
    is_streaming = false
}

-- setup highlights
local function setup_highlights()
    vim.cmd([[
        highlight default link NemuDiffAdd DiffAdd
        highlight default link NemuDiffDelete DiffDelete
        highlight default link NemuDiffChange DiffChange
        highlight default link NemuInlineHint Comment
        highlight default link NemuSuggestionCount Special
    ]])
end

-- initialize diff state
---@param buf number buffer id
---@param start_line number starting line
---@param end_line number ending line
---@param text string original text
function M.init_diff(buf, start_line, end_line, text)
    state.buf_id = buf
    state.start_line = start_line
    state.end_line = end_line
    state.original_text = text
    state.suggestions = {}
    state.current_index = 1
    state.is_streaming = true

    setup_highlights()
end

-- create virtual text for suggestion counter
local function update_suggestion_counter()
    if #state.suggestions == 0 then return end

    local counter_text = string.format(
        " suggestion %d/%d (tab to cycle)",
        state.current_index,
        #state.suggestions
    )

    api.nvim_buf_set_extmark(state.buf_id, state.ns_id, state.start_line - 1, 0, {
        virt_text = { { counter_text, "NemuSuggestionCount" } },
        virt_text_pos = "right_align",
    })
end

-- apply current suggestion diff
local function apply_current_diff()
    if not state.buf_id or #state.suggestions == 0 then return end

    local suggestion = state.suggestions[state.current_index]
    if not suggestion then return end

    -- clear previous highlights
    api.nvim_buf_clear_namespace(state.buf_id, state.ns_id, 0, -1)

    -- compute diff
    local diff = vim.diff(
        state.original_text,
        suggestion.text,
        {
            algorithm = "patience",
            indent_heuristic = true,
            context = 3
        }
    )

    if not diff then return end

    -- parse and apply diff hunks
    local hunks = vim.diff.parse_diff(diff)
    local offset = 0

    for _, hunk in ipairs(hunks) do
        local start = hunk.start + offset
        local count = hunk.count

        if hunk.type == "delete" then
            -- highlight deleted lines
            for i = start, start + count - 1 do
                api.nvim_buf_add_highlight(
                    state.buf_id,
                    state.ns_id,
                    "NemuDiffDelete",
                    i - 1,
                    0,
                    -1
                )
            end
        elseif hunk.type == "add" then
            -- insert and highlight added lines
            api.nvim_buf_set_lines(
                state.buf_id,
                start - 1,
                start - 1,
                false,
                vim.split(hunk.lines[1], "\n")
            )

            for i = 1, #hunk.lines do
                api.nvim_buf_add_highlight(
                    state.buf_id,
                    state.ns_id,
                    "NemuDiffAdd",
                    start + i - 2,
                    0,
                    -1
                )
            end

            offset = offset + #hunk.lines
        end
    end

    update_suggestion_counter()
end

-- cycle to next/previous suggestion
---@param direction "next"|"prev"
function M.cycle_suggestion(direction)
    if #state.suggestions == 0 or state.is_streaming then return end

    if direction == "next" then
        state.current_index = (state.current_index % #state.suggestions) + 1
    else
        state.current_index = state.current_index == 1
            and #state.suggestions
            or state.current_index - 1
    end

    apply_current_diff()
end

-- stream new suggestion chunk
---@param chunk string new text chunk
function M.stream_chunk(chunk)
    if not state.buf_id then return end

    -- if this is a new suggestion
    if #state.suggestions == 0 or not state.is_streaming then
        table.insert(state.suggestions, {
            text = chunk,
            index = #state.suggestions + 1,
            total = 0 -- will be updated when streaming ends
        })
        state.is_streaming = true
    else
        -- append to current suggestion
        local current = state.suggestions[#state.suggestions]
        current.text = current.text .. chunk
    end

    -- apply diff for the current suggestion
    apply_current_diff()
end

-- finish streaming current suggestion
function M.end_stream()
    state.is_streaming = false
    local current = state.suggestions[#state.suggestions]
    if current then
        current.total = #state.suggestions
    end
    update_suggestion_counter()
end

-- accept current suggestion
function M.accept_current()
    if not state.buf_id or #state.suggestions == 0 then return end

    local suggestion = state.suggestions[state.current_index]
    if not suggestion then return end

    -- apply final text
    local final_lines = vim.split(suggestion.text, "\n")
    api.nvim_buf_set_lines(
        state.buf_id,
        state.start_line - 1,
        state.end_line,
        false,
        final_lines
    )

    -- clear state
    api.nvim_buf_clear_namespace(state.buf_id, state.ns_id, 0, -1)
    M.reset()
end

-- reject all suggestions
function M.reject_all()
    if not state.buf_id then return end

    -- restore original text
    local original_lines = vim.split(state.original_text, "\n")
    api.nvim_buf_set_lines(
        state.buf_id,
        state.start_line - 1,
        state.end_line,
        false,
        original_lines
    )

    -- clear state
    api.nvim_buf_clear_namespace(state.buf_id, state.ns_id, 0, -1)
    M.reset()
end

-- reset internal state
function M.reset()
    state = {
        original_text = nil,
        suggestions = {},
        current_index = 1,
        ns_id = state.ns_id,
        buf_id = nil,
        start_line = nil,
        end_line = nil,
        is_streaming = false
    }
end

return M
