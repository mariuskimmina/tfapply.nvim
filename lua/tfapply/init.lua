--- Main entry point for tfapply.nvim
--- Handles plugin initialization and public API

local M = {}

local has_setup = false

--- Setup the plugin with user configuration
--- @param opts table|nil User configuration options
function M.setup(opts)
  if has_setup then
    return
  end
  has_setup = true

  -- Check Neovim version requirement (0.10+)
  if vim.fn.has('nvim-0.10') == 0 then
    vim.notify('tfapply.nvim requires Neovim 0.10 or newer', vim.log.levels.ERROR)
    return
  end

  -- Merge user configuration with defaults
  local config = require('tfapply.config')
  config.merge_with(opts or {})

  -- Validate configuration
  local valid, err = config.validate()
  if not valid then
    vim.notify('tfapply.nvim: Invalid configuration - ' .. err, vim.log.levels.ERROR)
    return
  end
end

--- Run terraform apply (full apply)
function M.apply()
  require('tfapply.commands').apply()
end

--- Run terraform apply on the resource under cursor
function M.apply_hover()
  require('tfapply.commands').apply_hover()
end

--- Run terraform apply on all resources in current file
function M.apply_file()
  require('tfapply.commands').apply_file()
end

--- Close the terraform terminal window
function M.close_terminal()
  require('tfapply.terminal').close()
end

return M
