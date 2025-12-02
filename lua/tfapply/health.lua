--- Health check module for tfapply.nvim
--- Run with :checkhealth tfapply

local M = {}

--- Check if a command is executable
--- @param cmd string Command to check
--- @return boolean
local function is_executable(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Get version of a command
--- @param cmd string Command to get version from
--- @param args string[] Arguments to pass to get version
--- @return string|nil version Version string or nil if failed
local function get_version(cmd, args)
  local result = vim.fn.systemlist(vim.list_extend({ cmd }, args))
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

--- Main health check function
function M.check()
  local health = vim.health or require('health')

  -- Check Neovim version
  health.start('tfapply.nvim System Requirements')

  local nvim_version = vim.version()
  if nvim_version.minor >= 10 then
    health.ok(string.format('Neovim version: %d.%d.%d', nvim_version.major, nvim_version.minor, nvim_version.patch))
  else
    health.error(
      string.format('Neovim version: %d.%d.%d (requires >= 0.10)', nvim_version.major, nvim_version.minor, nvim_version.patch),
      'Please upgrade to Neovim 0.10 or newer'
    )
  end

  -- Check Terraform installation
  health.start('Terraform Installation')

  local config = require('tfapply.config')
  local tf_bin = config.terraform.bin

  if is_executable(tf_bin) then
    local version = get_version(tf_bin, { 'version' })
    if version then
      health.ok(string.format('Terraform found: %s', version))
    else
      health.ok(string.format('Terraform found at: %s', tf_bin))
    end
  else
    health.error(
      string.format('Terraform not found: %s', tf_bin),
      {
        'Install Terraform from https://www.terraform.io/downloads',
        'Or set terraform.bin in your configuration to point to the terraform binary',
      }
    )
  end

  -- Check configuration
  health.start('Configuration')

  local valid, err = config.validate()
  if valid then
    health.ok('Configuration is valid')

    -- Show current configuration
    health.info(string.format('Terminal size: %.0f%% x %.0f%%', config.terminal.width * 100, config.terminal.height * 100))
    health.info(string.format('Border style: %s', config.terminal.border))
    health.info(string.format('Auto-close: %s', config.terminal.auto_close and 'enabled' or 'disabled'))

    if config.terraform.cwd then
      health.info(string.format('Working directory: %s', config.terraform.cwd))
    end
  else
    health.error('Invalid configuration: ' .. err)
  end

  -- Check for common Terraform files in current directory
  health.start('Terraform Files')

  local cwd = vim.fn.getcwd()
  local tf_files = vim.fn.glob(cwd .. '/*.tf', false, true)
  local tfvars_files = vim.fn.glob(cwd .. '/*.tfvars', false, true)

  if #tf_files > 0 then
    health.ok(string.format('Found %d .tf file(s) in current directory', #tf_files))
  else
    health.warn('No .tf files found in current directory', 'This is fine if you are not in a Terraform project')
  end

  if #tfvars_files > 0 then
    health.info(string.format('Found %d .tfvars file(s)', #tfvars_files))
  end

  -- Check for terraform state
  local state_file = cwd .. '/terraform.tfstate'
  if vim.fn.filereadable(state_file) == 1 then
    health.info('Terraform state file found')
  end

  -- Check for .terraform directory
  local tf_dir = cwd .. '/.terraform'
  if vim.fn.isdirectory(tf_dir) == 1 then
    health.ok('Terraform initialized (.terraform directory found)')
  else
    health.warn('.terraform directory not found', 'Run "terraform init" if you are in a Terraform project')
  end
end

return M
