-- Plugin entry point for tfapply.nvim
-- This file is automatically loaded by Neovim

-- Check Neovim version compatibility
if vim.fn.has('nvim-0.10') ~= 1 then
  vim.notify('tfapply.nvim requires Neovim >= 0.10', vim.log.levels.ERROR)
  return
end

-- Prevent loading if already loaded
if vim.g.loaded_tfapply then
  return
end
vim.g.loaded_tfapply = 1

-- Create user commands
vim.api.nvim_create_user_command('TfApply', function()
  require('tfapply').apply()
end, {
  desc = 'Apply terraform (full apply)',
})

vim.api.nvim_create_user_command('TfApplyHover', function()
  require('tfapply').apply_hover()
end, {
  desc = 'Apply the resource under cursor (targeted apply)',
})

vim.api.nvim_create_user_command('TfApplyFile', function()
  require('tfapply').apply_file()
end, {
  desc = 'Apply all resources in the current file (targeted apply)',
})

vim.api.nvim_create_user_command('TfInit', function()
  require('tfapply').init()
end, {
  desc = 'Run terraform init',
})

vim.api.nvim_create_user_command('TfApplyClose', function()
  require('tfapply').close_terminal()
end, {
  desc = 'Close the terraform terminal window',
})
