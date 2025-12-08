--- Interactive terraform plan review UI
--- Provides a UI for reviewing and approving terraform changes

local M = {}
local plan_parser = require('tfapply.plan_parser')
local buffer_monitor = require('tfapply.buffer_monitor')

--- @class ReviewState
--- @field blocks PlanBlock[] Parsed plan blocks
--- @field summary table Plan summary
--- @field reviewed table<number, boolean> Map of block index to reviewed status
--- @field collapsed table<number, boolean> Map of block index to collapsed status
--- @field current_block number Currently selected block index
--- @field bufnr number Review buffer number
--- @field winid number Review window ID
--- @field process TerraformProcess The terraform process
--- @field decision string|nil 'approve' or 'reject'

local active_review = nil

--- Create the review UI floating window
--- @return number bufnr
--- @return number winid
local function create_review_window()
  local config = require('tfapply.config')

  -- Calculate window size
  local width = math.floor(vim.o.columns * config.terminal.width)
  local height = math.floor(vim.o.lines * config.terminal.height)

  -- Calculate starting position (centered)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = config.terminal.border,
    title = ' Terraform Plan Review ',
    title_pos = 'center',
  }

  -- Create window
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)

  -- Set buffer options
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'tfapply-review', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- Set window options
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
  vim.api.nvim_set_option_value('wrap', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })

  return bufnr, winid
end

--- Render the review UI
--- @param state ReviewState
local function render_review(state)
  local config = require('tfapply.config')
  local lines = {}
  local highlights = {}

  -- Add header
  table.insert(lines, '╔═══════════════════════════════════════════════════════════════════════╗')
  table.insert(lines, '║  Terraform Plan Review - Review each resource before applying        ║')
  table.insert(lines, '╚═══════════════════════════════════════════════════════════════════════╝')
  table.insert(lines, '')

  -- Add summary
  local summary_line = string.format(
    '  Plan: %d to add, %d to change, %d to destroy',
    state.summary.add,
    state.summary.change,
    state.summary.destroy
  )
  table.insert(lines, summary_line)
  table.insert(lines, '')
  table.insert(lines, '─────────────────────────────────────────────────────────────────────────')
  table.insert(lines, '')

  -- Track line numbers for each block
  local block_line_map = {}

  -- Render each resource block
  for i, block in ipairs(state.blocks) do
    if block.type == 'resource' then
      local start_line = #lines + 1
      block_line_map[i] = start_line

      -- Get status indicators
      local reviewed = state.reviewed[i] or false
      local collapsed = state.collapsed[i] or false
      local is_current = (i == state.current_block)

      -- Build the block header
      local checkbox = reviewed and '[✓]' or '[ ]'
      local expand_icon = collapsed and '▶' or '▼'
      local action_symbol = plan_parser.get_action_symbol(block.action)

      local header = string.format(
        '%s %s %s %s (%s)',
        is_current and '→' or ' ',
        checkbox,
        expand_icon,
        block.resource_address,
        action_symbol .. ' ' .. block.action
      )

      table.insert(lines, header)

      -- Add highlight for current block
      if is_current then
        table.insert(highlights, {
          line = start_line - 1,
          col_start = 0,
          col_end = -1,
          hl_group = 'CursorLine',
        })
      end

      -- Add highlight for action
      local action_hl = plan_parser.get_action_highlight(block.action)
      table.insert(highlights, {
        line = start_line - 1,
        col_start = #header - #block.action - 3,
        col_end = #header,
        hl_group = action_hl,
      })

      -- Render block content if not collapsed
      if not collapsed then
        local show_unchanged = config.interactive.show_unchanged
        local block_lines = plan_parser.filter_unchanged(block.lines, show_unchanged)

        for _, line in ipairs(block_lines) do
          local display_line = '    ' .. line
          table.insert(lines, display_line)

          -- Apply dimming if reviewed
          if reviewed and config.interactive.dim_reviewed then
            table.insert(highlights, {
              line = #lines - 1,
              col_start = 0,
              col_end = -1,
              hl_group = 'Comment',
            })
          end
        end
      end

      table.insert(lines, '')
    end
  end

  -- Add controls section
  table.insert(lines, '─────────────────────────────────────────────────────────────────────────')
  table.insert(lines, '')

  local reviewed_count = 0
  for _, reviewed in pairs(state.reviewed) do
    if reviewed then
      reviewed_count = reviewed_count + 1
    end
  end

  local total_resources = 0
  for _, block in ipairs(state.blocks) do
    if block.type == 'resource' then
      total_resources = total_resources + 1
    end
  end

  local progress = string.format('  Progress: %d / %d resources reviewed', reviewed_count, total_resources)
  table.insert(lines, progress)
  table.insert(lines, '')

  -- Approval buttons
  local can_approve = true
  if config.interactive.require_review_all and reviewed_count < total_resources then
    can_approve = false
  end

  if can_approve then
    table.insert(lines, '  [A] Approve and Apply    [R] Reject and Cancel')
  else
    table.insert(lines, '  Review all resources before approving    [R] Reject and Cancel')
  end

  table.insert(lines, '')
  table.insert(lines, '  Controls:')
  table.insert(lines, '    j/k or ↓/↑  : Navigate resources')
  table.insert(lines, '    Space       : Toggle reviewed status')
  table.insert(lines, '    Enter       : Expand/collapse resource')
  table.insert(lines, '    q/Esc       : Reject and quit')

  -- Write to buffer
  vim.api.nvim_set_option_value('modifiable', true, { buf = state.bufnr })
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = state.bufnr })

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('tfapply_review')
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      state.bufnr,
      ns_id,
      hl.hl_group,
      hl.line,
      hl.col_start,
      hl.col_end
    )
  end

  -- Position cursor on current block if exists
  if block_line_map[state.current_block] then
    vim.api.nvim_win_set_cursor(state.winid, { block_line_map[state.current_block], 0 })
  end
end

--- Find the next resource block
--- @param state ReviewState
--- @param direction number 1 for next, -1 for previous
--- @return number|nil block_index
local function find_next_resource(state, direction)
  local start = state.current_block + direction
  local step = direction

  if direction > 0 then
    for i = start, #state.blocks do
      if state.blocks[i].type == 'resource' then
        return i
      end
    end
  else
    for i = start, 1, step do
      if state.blocks[i].type == 'resource' then
        return i
      end
    end
  end

  return nil
end

--- Toggle reviewed status for current block
--- @param state ReviewState
local function toggle_reviewed(state)
  local config = require('tfapply.config')

  if state.blocks[state.current_block].type == 'resource' then
    local current_status = state.reviewed[state.current_block] or false
    state.reviewed[state.current_block] = not current_status

    -- Auto-collapse if configured and now reviewed
    if not current_status and config.interactive.auto_collapse_reviewed then
      state.collapsed[state.current_block] = true
    end

    render_review(state)

    -- Move to next resource
    local next_block = find_next_resource(state, 1)
    if next_block then
      state.current_block = next_block
      render_review(state)
    end
  end
end

--- Toggle collapsed status for current block
--- @param state ReviewState
local function toggle_collapsed(state)
  if state.blocks[state.current_block].type == 'resource' then
    local current_status = state.collapsed[state.current_block] or false
    state.collapsed[state.current_block] = not current_status
    render_review(state)
  end
end

--- Navigate to next/previous resource
--- @param state ReviewState
--- @param direction number 1 for next, -1 for previous
local function navigate(state, direction)
  local next_block = find_next_resource(state, direction)
  if next_block then
    state.current_block = next_block
    render_review(state)
  end
end

--- Handle approval
--- @param state ReviewState
local function approve(state)
  local config = require('tfapply.config')

  -- Check if all reviewed if required
  if config.interactive.require_review_all then
    local all_reviewed = true
    for i, block in ipairs(state.blocks) do
      if block.type == 'resource' and not state.reviewed[i] then
        all_reviewed = false
        break
      end
    end

    if not all_reviewed then
      vim.notify('Please review all resources before approving', vim.log.levels.WARN)
      return
    end
  end

  state.decision = 'approve'
  vim.notify('Approving changes...', vim.log.levels.INFO)

  -- Send 'yes' to terraform
  local success = buffer_monitor.send_input(state.process.job_id, 'yes')

  if not success then
    vim.notify('Failed to send approval to terraform. The process may have terminated.', vim.log.levels.ERROR)
    return
  end

  -- Close review window
  if vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end

  -- Switch back to the terminal window if it still exists
  if state.process.winid and vim.api.nvim_win_is_valid(state.process.winid) then
    vim.api.nvim_set_current_win(state.process.winid)

    -- Scroll to bottom
    vim.cmd('normal! G')
    -- Enter terminal mode
    vim.cmd('startinsert')
  end

  active_review = nil
end

--- Handle rejection
--- @param state ReviewState
local function reject(state)
  state.decision = 'reject'
  vim.notify('Rejecting changes', vim.log.levels.INFO)

  -- Send 'no' to terraform
  buffer_monitor.send_input(state.process.job_id, 'no')

  -- Close review window
  if vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end

  -- Switch back to the terminal window if it still exists
  if state.process.winid and vim.api.nvim_win_is_valid(state.process.winid) then
    vim.api.nvim_set_current_win(state.process.winid)
  end

  active_review = nil
end

--- Setup keybindings for the review buffer
--- @param state ReviewState
local function setup_keybindings(state)
  local opts = { buffer = state.bufnr, silent = true, noremap = true }

  -- Navigation
  vim.keymap.set('n', 'j', function() navigate(state, 1) end, opts)
  vim.keymap.set('n', 'k', function() navigate(state, -1) end, opts)
  vim.keymap.set('n', '<Down>', function() navigate(state, 1) end, opts)
  vim.keymap.set('n', '<Up>', function() navigate(state, -1) end, opts)

  -- Toggle reviewed
  vim.keymap.set('n', '<Space>', function() toggle_reviewed(state) end, opts)

  -- Toggle collapsed
  vim.keymap.set('n', '<CR>', function() toggle_collapsed(state) end, opts)

  -- Approve
  vim.keymap.set('n', 'A', function() approve(state) end, opts)
  vim.keymap.set('n', 'a', function() approve(state) end, opts)

  -- Reject
  vim.keymap.set('n', 'R', function() reject(state) end, opts)
  vim.keymap.set('n', 'r', function() reject(state) end, opts)
  vim.keymap.set('n', 'q', function() reject(state) end, opts)
  vim.keymap.set('n', '<Esc>', function() reject(state) end, opts)
end

--- Start interactive review session
--- @param output_lines string[] Terraform plan output
--- @param process TerraformProcess The terraform process
function M.start_review(output_lines, process)
  local config = require('tfapply.config')

  -- DON'T close the terminal window - keep it alive in the background
  -- The terminal job will die if we close its window
  -- Instead, we'll just create the review window on top and manage switching between them

  -- Parse the plan output
  local blocks, summary = plan_parser.parse_plan(output_lines)

  -- Find first resource block
  local first_resource = nil
  for i, block in ipairs(blocks) do
    if block.type == 'resource' then
      first_resource = i
      break
    end
  end

  -- Create review state
  local state = {
    blocks = blocks,
    summary = summary,
    reviewed = {},
    collapsed = {},
    current_block = first_resource or 1,
    process = process,
    decision = nil,
  }

  -- Auto-expand or collapse all blocks based on config
  if config.interactive.auto_expand_all then
    -- All collapsed = false by default
  else
    -- All collapsed = true
    for i, block in ipairs(blocks) do
      if block.type == 'resource' then
        state.collapsed[i] = true
      end
    end
  end

  -- Create UI
  local bufnr, winid = create_review_window()
  state.bufnr = bufnr
  state.winid = winid

  -- Setup keybindings
  setup_keybindings(state)

  -- Render initial UI
  render_review(state)

  -- Store active review
  active_review = state

  return state
end

return M
