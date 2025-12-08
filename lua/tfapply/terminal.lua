--- Floating terminal implementation for running terraform commands

local M = {}
local buffer_monitor = require('tfapply.buffer_monitor')
local interactive = require('tfapply.interactive')

-- Store active terminal info
local active_terminal = {
  buf = nil,
  win = nil,
  process = nil,
}

--- Create a centered floating window
--- @param width_fraction number Window width as fraction of editor width
--- @param height_fraction number Window height as fraction of editor height
--- @param border string Border style
--- @return number bufnr Buffer number
--- @return number winid Window ID
local function create_floating_window(width_fraction, height_fraction, border)
  -- Calculate window size
  local width = math.floor(vim.o.columns * width_fraction)
  local height = math.floor(vim.o.lines * height_fraction)

  -- Calculate starting position (centered)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true) -- not listed, scratch buffer

  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = border,
    title = ' Terraform Apply ',
    title_pos = 'center',
  }

  -- Create window
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)

  -- Set buffer options
  local config = require('tfapply.config')
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'tfapply', { buf = bufnr })
  vim.api.nvim_set_option_value('scrollback', config.terminal.scrollback, { buf = bufnr })

  -- Set window options for better terminal experience
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
  vim.api.nvim_set_option_value('wrap', true, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })

  -- Store terminal info
  active_terminal.buf = bufnr
  active_terminal.win = winid

  return bufnr, winid
end

--- Create an output window for streaming terraform results
--- @return number bufnr Buffer number
--- @return number winid Window ID
function M.create_output_window()
  local config = require('tfapply.config')

  -- Create floating window
  local bufnr, winid = create_floating_window(
    config.terminal.width,
    config.terminal.height,
    config.terminal.border
  )

  -- Store terminal info
  active_terminal.buf = bufnr
  active_terminal.win = winid

  -- Set up keymaps for output window
  local opts = { buffer = bufnr, silent = true, noremap = true }

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, opts)

  -- Scrolling
  vim.keymap.set('n', '<C-d>', '<C-d>zz', opts)
  vim.keymap.set('n', '<C-u>', '<C-u>zz', opts)

  -- Enable modifiable for line insertion
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })

  return bufnr, winid
end

--- Get the working directory for terraform commands
--- @return string cwd
local function get_working_directory()
  local config = require('tfapply.config')

  -- Use configured cwd if set
  if config.terraform.cwd then
    return config.terraform.cwd
  end

  -- Use the directory of the current file
  local current_file = vim.fn.expand('%:p')
  if current_file and current_file ~= '' then
    return vim.fn.fnamemodify(current_file, ':h')
  end

  -- Fallback to current working directory
  return vim.fn.getcwd()
end

--- Build terraform apply command
--- @param targets string[]|nil Optional target resources
--- @return string[] command
local function build_terraform_command(targets)
  local config = require('tfapply.config')
  local cmd = { config.terraform.bin, 'apply' }

  -- Add target flags
  if targets then
    for _, target in ipairs(targets) do
      table.insert(cmd, '-target=' .. target)
    end
  end

  -- Add any additional arguments from config
  for _, arg in ipairs(config.terraform.apply_args) do
    table.insert(cmd, arg)
  end

  return cmd
end

--- Close the floating terminal
function M.close()
  if active_terminal.win and vim.api.nvim_win_is_valid(active_terminal.win) then
    vim.api.nvim_win_close(active_terminal.win, true)
  end

  if active_terminal.buf and vim.api.nvim_buf_is_valid(active_terminal.buf) then
    vim.api.nvim_buf_delete(active_terminal.buf, { force = true })
  end

  active_terminal.buf = nil
  active_terminal.win = nil
end

--- Run terraform apply with interactive mode (using termopen with buffer monitoring)
--- @param targets string[]|nil Optional target resources
local function run_apply_interactive(targets)
  local config = require('tfapply.config')

  -- Validate configuration
  local valid, err = config.validate()
  if not valid then
    vim.notify('tfapply.nvim: ' .. err, vim.log.levels.ERROR)
    return
  end

  -- Build command
  local cmd = build_terraform_command(targets)
  local cwd = get_working_directory()

  -- Show command being executed
  local cmd_str = table.concat(cmd, ' ')
  vim.notify(string.format('Running: %s\nIn: %s', cmd_str, cwd), vim.log.levels.INFO)

  -- Create floating window
  local bufnr, winid = create_floating_window(
    config.terminal.width,
    config.terminal.height,
    config.terminal.border
  )

  -- Store terminal info
  active_terminal.buf = bufnr
  active_terminal.win = winid

  -- Build job options
  local job_opts = {
    cwd = cwd,
    on_exit = function(job_id, exit_code, event)
      -- This will be handled by the buffer monitor
    end,
  }

  -- Add environment variables if configured
  if config.terraform.env then
    job_opts.env = vim.tbl_extend('force', vim.fn.environ(), config.terraform.env)
  end

  -- Start terminal job
  local job_id = vim.fn.termopen(cmd, job_opts)

  if job_id <= 0 then
    vim.notify('Failed to start terraform process', vim.log.levels.ERROR)
    return
  end

  -- Start monitoring the buffer for approval prompt
  local monitor = buffer_monitor.start(bufnr, job_id, {
    on_prompt = function(output_lines, job_id)
      -- Approval prompt detected!
      -- Don't close the window yet - just hide it by switching to a different buffer
      -- This keeps the terminal job alive so we can send input to it

      -- Start interactive review with a process wrapper
      local process_wrapper = {
        output_buffer = output_lines,
        job_id = job_id,
        bufnr = bufnr,
        winid = winid, -- Pass the window ID so we can manage it
      }

      interactive.start_review(output_lines, process_wrapper)
    end,
    on_exit = function(exit_code)
      if exit_code == 0 then
        vim.notify('Terraform apply completed successfully', vim.log.levels.INFO)

        -- Auto-close if configured
        if config.terminal.auto_close and vim.api.nvim_win_is_valid(winid) then
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(winid) then
              vim.api.nvim_win_close(winid, true)
            end
          end, config.terminal.auto_close_delay)
        end
      else
        vim.notify(
          string.format('Terraform apply failed with exit code %d', exit_code),
          vim.log.levels.ERROR
        )
      end
    end,
  })

  -- Set up keymaps for the terminal
  local opts = { buffer = bufnr, silent = true, noremap = true }

  -- Terminal mode: Easy escape to normal mode
  vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', opts)
  vim.keymap.set('t', '<C-n>', '<C-\\><C-n>', opts)

  -- Normal mode: Close with q or ESC (but only if prompt hasn't been detected)
  vim.keymap.set('n', 'q', function()
    if not monitor.prompt_detected then
      buffer_monitor.stop(monitor)
      vim.api.nvim_win_close(winid, true)
    end
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    if not monitor.prompt_detected then
      buffer_monitor.stop(monitor)
      vim.api.nvim_win_close(winid, true)
    end
  end, opts)

  -- Start in insert mode (terminal mode)
  vim.cmd('startinsert')
end

--- Run terraform apply in a floating terminal (legacy non-interactive mode)
--- @param targets string[]|nil Optional target resources
local function run_apply_legacy(targets)
  local config = require('tfapply.config')

  -- Validate configuration
  local valid, err = config.validate()
  if not valid then
    vim.notify('tfapply.nvim: ' .. err, vim.log.levels.ERROR)
    return
  end

  -- Create floating window
  local bufnr, winid = create_floating_window(
    config.terminal.width,
    config.terminal.height,
    config.terminal.border
  )

  -- Build command
  local cmd = build_terraform_command(targets)
  local cwd = get_working_directory()

  -- Show command being executed
  local cmd_str = table.concat(cmd, ' ')
  vim.notify(string.format('Running: %s\nIn: %s', cmd_str, cwd), vim.log.levels.INFO)

  -- Build job options
  local job_opts = {
    cwd = cwd,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        vim.notify('Terraform apply completed successfully', vim.log.levels.INFO)

        -- Auto-close if configured
        if config.terminal.auto_close then
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(winid) then
              vim.api.nvim_win_close(winid, true)
            end
          end, config.terminal.auto_close_delay)
        end
      else
        vim.notify(
          string.format('Terraform apply failed with exit code %d', exit_code),
          vim.log.levels.ERROR
        )
      end
    end,
  }

  -- Add environment variables if configured
  if config.terraform.env then
    -- Merge with current environment
    job_opts.env = vim.tbl_extend('force', vim.fn.environ(), config.terraform.env)
  end

  -- Start terminal job
  local job_id = vim.fn.termopen(cmd, job_opts)

  if job_id <= 0 then
    vim.notify('Failed to start terraform process', vim.log.levels.ERROR)
    return
  end

  -- Set up keymaps for better terminal experience
  local opts = { buffer = bufnr, silent = true, noremap = true }

  -- Normal mode: Close terminal with q or ESC
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(winid, true)
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(winid, true)
  end, opts)

  -- Normal mode: Scrolling
  vim.keymap.set('n', '<C-d>', '<C-d>zz', opts)
  vim.keymap.set('n', '<C-u>', '<C-u>zz', opts)
  vim.keymap.set('n', '<C-f>', '<C-f>zz', opts)
  vim.keymap.set('n', '<C-b>', '<C-b>zz', opts)
  vim.keymap.set('n', 'G', 'Gzb', opts)
  vim.keymap.set('n', 'gg', 'ggzb', opts)

  -- Terminal mode: Easy escape to normal mode for scrolling
  vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', opts)
  vim.keymap.set('t', '<C-n>', '<C-\\><C-n>', opts)

  -- Terminal mode: Quick close
  vim.keymap.set('t', '<C-q>', function()
    vim.api.nvim_win_close(winid, true)
  end, opts)

  -- Normal mode: Jump to bottom and enter insert mode
  vim.keymap.set('n', 'i', 'Gi', opts)
  vim.keymap.set('n', 'a', 'Ga', opts)
  vim.keymap.set('n', 'A', 'GA', opts)

  -- Enable mouse support
  vim.api.nvim_set_option_value('mouse', 'a', { win = winid })

  -- Add a helpful message at the top if configured
  if config.terminal.show_hints then
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
      '───────────────────────────────────────────────────────────────',
      ' Terraform Apply Terminal',
      ' Ctrl+N: Normal mode (scroll)  |  q/ESC: Close  |  i: Terminal mode',
      ' Mouse scroll works  |  Ctrl+Q: Quick close',
      '───────────────────────────────────────────────────────────────',
      '',
    })
  end

  -- Start in insert mode (terminal mode)
  vim.cmd('startinsert')
end

--- Run terraform apply (chooses interactive or legacy mode based on config)
--- @param targets string[]|nil Optional target resources
function M.run_apply(targets)
  local config = require('tfapply.config')

  if config.interactive.enabled then
    run_apply_interactive(targets)
  else
    run_apply_legacy(targets)
  end
end

return M
