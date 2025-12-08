--- Parser for terraform plan output
--- Extracts resource blocks and structure for interactive review

local M = {}

--- @class PlanBlock
--- @field type string Block type: 'header', 'resource', 'summary', 'prompt', 'other'
--- @field action string|nil Resource action: 'create', 'update', 'replace', 'destroy', 'read'
--- @field resource_address string|nil Full resource address (e.g., "aws_instance.example")
--- @field resource_type string|nil Resource type (e.g., "aws_instance")
--- @field resource_name string|nil Resource name (e.g., "example")
--- @field lines string[] The actual output lines for this block
--- @field start_line number Starting line number
--- @field end_line number Ending line number

--- Parse terraform plan output into structured blocks
--- @param output_lines string[] Array of output lines
--- @return PlanBlock[] blocks
--- @return table summary { add = number, change = number, destroy = number }
function M.parse_plan(output_lines)
  local blocks = {}
  local current_block = nil
  local summary = { add = 0, change = 0, destroy = 0 }

  for i, line in ipairs(output_lines) do
    -- Detect resource block headers
    -- Patterns like: "  # aws_instance.example will be created"
    local resource_match = line:match('^%s*#%s+(.-)%s+will%s+be%s+(.+)$')
    if resource_match then
      -- Save previous block
      if current_block then
        current_block.end_line = i - 1
        table.insert(blocks, current_block)
      end

      -- Parse action from the match
      local address, action_text = resource_match, select(2, line:match('^%s*#%s+(.-)%s+will%s+be%s+(.+)$'))
      local action = M.parse_action(action_text)

      -- Extract resource type and name from address
      local resource_type, resource_name = address:match('^(.-)%.(.+)$')

      current_block = {
        type = 'resource',
        action = action,
        resource_address = address,
        resource_type = resource_type,
        resource_name = resource_name,
        lines = { line },
        start_line = i,
        end_line = i,
      }

      goto continue
    end

    -- Detect plan summary
    -- Pattern: "Plan: 1 to add, 2 to change, 3 to destroy."
    local add, change, destroy = line:match('Plan:%s*(%d+)%s+to%s+add,%s*(%d+)%s+to%s+change,%s*(%d+)%s+to%s+destroy')
    if add then
      -- Save previous block
      if current_block then
        current_block.end_line = i - 1
        table.insert(blocks, current_block)
      end

      summary.add = tonumber(add) or 0
      summary.change = tonumber(change) or 0
      summary.destroy = tonumber(destroy) or 0

      current_block = {
        type = 'summary',
        lines = { line },
        start_line = i,
        end_line = i,
      }

      goto continue
    end

    -- Detect approval prompt
    if line:match('Do you want to perform these actions%?') or
       line:match('Do you really want to destroy') or
       line:match('Enter a value:') then
      -- Save previous block
      if current_block then
        current_block.end_line = i - 1
        table.insert(blocks, current_block)
      end

      current_block = {
        type = 'prompt',
        lines = { line },
        start_line = i,
        end_line = i,
      }

      goto continue
    end

    -- Detect section headers
    if line:match('^Terraform will perform') or
       line:match('^Terraform used the selected') or
       line:match('^An execution plan has been generated') then
      -- Save previous block
      if current_block then
        current_block.end_line = i - 1
        table.insert(blocks, current_block)
      end

      current_block = {
        type = 'header',
        lines = { line },
        start_line = i,
        end_line = i,
      }

      goto continue
    end

    -- Add line to current block or create 'other' block
    if current_block then
      table.insert(current_block.lines, line)
      current_block.end_line = i
    else
      -- Create a new 'other' block for miscellaneous lines
      current_block = {
        type = 'other',
        lines = { line },
        start_line = i,
        end_line = i,
      }
    end

    ::continue::
  end

  -- Save final block
  if current_block then
    table.insert(blocks, current_block)
  end

  return blocks, summary
end

--- Parse action text into standardized action type
--- @param action_text string The action description from terraform
--- @return string action Standardized action: 'create', 'update', 'replace', 'destroy', 'read'
function M.parse_action(action_text)
  action_text = action_text:lower()

  if action_text:match('created') then
    return 'create'
  elseif action_text:match('destroyed') or action_text:match('deleted') then
    return 'destroy'
  elseif action_text:match('replaced') then
    return 'replace'
  elseif action_text:match('updated') or action_text:match('modified') or action_text:match('changed') then
    return 'update'
  elseif action_text:match('read') then
    return 'read'
  end

  return 'unknown'
end

--- Get a symbol for the resource action
--- @param action string Action type
--- @return string symbol Symbol representing the action
function M.get_action_symbol(action)
  local symbols = {
    create = '+',
    destroy = '-',
    update = '~',
    replace = '±',
    read = '⊙',
    unknown = '?',
  }

  return symbols[action] or '?'
end

--- Get a color highlight group for the action
--- @param action string Action type
--- @return string hl_group Highlight group name
function M.get_action_highlight(action)
  local highlights = {
    create = 'DiffAdd',
    destroy = 'DiffDelete',
    update = 'DiffChange',
    replace = 'WarningMsg',
    read = 'Comment',
    unknown = 'Normal',
  }

  return highlights[action] or 'Normal'
end

--- Filter out unchanged attributes if configured
--- @param lines string[] Resource block lines
--- @param show_unchanged boolean Whether to show unchanged attributes
--- @return string[] filtered_lines
function M.filter_unchanged(lines, show_unchanged)
  if show_unchanged then
    return lines
  end

  local filtered = {}
  for _, line in ipairs(lines) do
    -- Skip lines that represent unchanged attributes (no +, -, ~ prefix in content)
    local content = line:match('^%s+(.*)$')
    if content then
      local first_char = content:sub(1, 1)
      -- Include lines with change indicators or structural elements
      if first_char == '+' or first_char == '-' or first_char == '~' or
         first_char == '#' or first_char == '}' or first_char == '{' or
         content:match('^resource%s') or content:match('^data%s') then
        table.insert(filtered, line)
      end
    else
      -- Include non-indented lines (headers, etc.)
      table.insert(filtered, line)
    end
  end

  return filtered
end

return M
