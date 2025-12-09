--- Command implementations for tfapply.nvim

local M = {}

--- Run full terraform apply
function M.apply()
  local terminal = require('tfapply.terminal')
  terminal.run_apply(nil)
end

--- Run targeted terraform apply on resource under cursor
function M.apply_hover()
  local parser = require('tfapply.parser')
  local terminal = require('tfapply.terminal')

  -- Check if we're in a Terraform file
  if not parser.is_terraform_file() then
    vim.notify('Not a Terraform file', vim.log.levels.WARN)
    return
  end

  -- Get the resource under cursor
  local resource = parser.get_resource_under_cursor()

  if not resource then
    vim.notify('No Terraform resource found under cursor', vim.log.levels.WARN)
    return
  end

  -- Show what we're targeting
  local msg = string.format('Targeting: %s', resource.address)
  vim.notify(msg, vim.log.levels.INFO)

  -- Run targeted apply
  terminal.run_apply({ resource.address })
end

--- Run terraform apply on all resources in current file
function M.apply_file()
  local parser = require('tfapply.parser')
  local terminal = require('tfapply.terminal')

  -- Check if we're in a Terraform file
  if not parser.is_terraform_file() then
    vim.notify('Not a Terraform file', vim.log.levels.WARN)
    return
  end

  -- Get all resources in buffer
  local resources = parser.get_all_resources_in_buffer()

  if #resources == 0 then
    vim.notify('No Terraform resources found in current file', vim.log.levels.WARN)
    return
  end

  -- Extract addresses
  local targets = {}
  for _, resource in ipairs(resources) do
    table.insert(targets, resource.address)
  end

  -- Show what we're targeting
  local msg = string.format('Targeting %d resource(s) from current file', #targets)
  vim.notify(msg, vim.log.levels.INFO)

  -- Run targeted apply
  terminal.run_apply(targets)
end

--- Run terraform init
function M.init()
  local terminal = require('tfapply.terminal')
  terminal.run_init()
end

return M
