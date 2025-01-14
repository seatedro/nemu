-- =============================================================================
--  Nemu: Logger
-- =============================================================================
local M = {}

-- log levels
M.levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

-- current log level
M.level = M.levels.INFO

-- log file path
M.path = vim.fn.stdpath("cache") .. "/nemu.log"

-- format message with timestamp
local function format_msg(level, msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    return string.format("[%s] [%s] %s", timestamp, level, msg)
end

-- write to log file
local function write_log(msg)
    local file = io.open(M.path, "a")
    if file then
        file:write(msg .. "\n")
        file:close()
    end
end

-- log functions for each level
function M.debug(msg, opts)
    if M.level <= M.levels.DEBUG then
        local formatted = format_msg("DEBUG", msg)
        write_log(formatted)
        if opts and opts.notify == true then
            vim.notify(msg, vim.log.levels.DEBUG)
        end
    end
end

function M.info(msg, opts)
    if M.level <= M.levels.INFO then
        local formatted = format_msg("INFO", msg)
        write_log(formatted)
        if opts and opts.notify == true then
            vim.notify(msg, vim.log.levels.INFO)
        end
    end
end

function M.warn(msg, opts)
    if M.level <= M.levels.WARN then
        local formatted = format_msg("WARN", msg)
        write_log(formatted)
        if opts and opts.notify == true then
            vim.notify(msg, vim.log.levels.WARN)
        end
    end
end

function M.error(msg, opts)
    if M.level <= M.levels.ERROR then
        local formatted = format_msg("ERROR", msg)
        write_log(formatted)
        if opts and opts.notify == true then
            vim.notify(msg, vim.log.levels.ERROR)
        end
    end
end

return M
