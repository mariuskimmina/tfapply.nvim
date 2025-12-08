--- Configuration management for tfapply.nvim

local M = {
  -- Terminal window configuration
  terminal = {
    -- Window size (fraction of editor size)
    width = 0.8,
    height = 0.8,
    -- Border style: 'single', 'double', 'rounded', 'solid', 'shadow'
    border = 'rounded',
    -- Close terminal automatically on successful apply
    auto_close = false,
    -- Delay before auto-closing (milliseconds)
    auto_close_delay = 2000,
    -- Number of lines to keep in scrollback buffer
    scrollback = 100000,
    -- Show helpful keybinding hints at the top
    show_hints = true,
  },

  -- Terraform configuration
  terraform = {
    -- Terraform binary path (uses 'terraform' from PATH by default)
    bin = 'terraform',
    -- Working directory (nil uses current file's directory)
    cwd = nil,
    -- Additional terraform apply arguments
    apply_args = {},
    -- Environment variables for terraform (nil inherits from Neovim)
    -- Example: { TF_VAR_region = 'us-west-2', AWS_PROFILE = 'dev' }
    env = nil,
  },

  -- Parser configuration
  parser = {
    -- Resource types to recognize
    resource_types = {
      'resource',
      'data',
      'module',
    },
  },

  -- Interactive apply mode configuration
  interactive = {
    -- Enable interactive plan review mode
    enabled = true,
    -- Require all resource blocks to be reviewed before approving
    require_review_all = true,
    -- Auto-collapse blocks when marked as reviewed
    auto_collapse_reviewed = true,
    -- Show unchanged attributes in resource blocks
    show_unchanged = false,
    -- Auto-expand all blocks on initial display
    auto_expand_all = false,
    -- Highlight reviewed items differently
    dim_reviewed = true,
  },
}

--- Merge user configuration with defaults
--- @param opts table User configuration
function M.merge_with(opts)
  M.terminal = vim.tbl_deep_extend('force', M.terminal, opts.terminal or {})
  M.terraform = vim.tbl_deep_extend('force', M.terraform, opts.terraform or {})
  M.parser = vim.tbl_deep_extend('force', M.parser, opts.parser or {})
  M.interactive = vim.tbl_deep_extend('force', M.interactive, opts.interactive or {})
end

--- Validate configuration
--- @return boolean is_valid
--- @return string|nil error_message
function M.validate()
  -- Check if terraform binary exists
  if vim.fn.executable(M.terraform.bin) == 0 then
    return false, string.format('Terraform binary not found: %s', M.terraform.bin)
  end

  -- Validate window size
  if M.terminal.width <= 0 or M.terminal.width > 1 then
    return false, 'terminal.width must be between 0 and 1'
  end
  if M.terminal.height <= 0 or M.terminal.height > 1 then
    return false, 'terminal.height must be between 0 and 1'
  end

  return true, nil
end

return M
