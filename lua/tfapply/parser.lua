--- Terraform HCL parser for resource extraction

local M = {}

--- Parse a line to extract Terraform resource information
--- @param line string The line to parse
--- @return table|nil resource_info { type = string, resource_type = string, name = string }
local function parse_resource_line(line)
  -- Match patterns like:
  -- resource "aws_instance" "example" {
  -- data "aws_ami" "ubuntu" {
  -- module "vpc" {

  local patterns = {
    -- resource "type" "name"
    '^%s*(resource)%s+"([^"]+)"%s+"([^"]+)"',
    -- data "type" "name"
    '^%s*(data)%s+"([^"]+)"%s+"([^"]+)"',
    -- module "name"
    '^%s*(module)%s+"([^"]+)"',
  }

  for _, pattern in ipairs(patterns) do
    local matches = { line:match(pattern) }
    if #matches > 0 then
      local block_type = matches[1]

      if block_type == 'module' then
        return {
          type = 'module',
          name = matches[2],
          address = string.format('module.%s', matches[2]),
        }
      else
        return {
          type = block_type,
          resource_type = matches[2],
          name = matches[3],
          address = string.format('%s.%s.%s', block_type, matches[2], matches[3]),
        }
      end
    end
  end

  return nil
end

--- Get the resource under the cursor
--- @return table|nil resource_info { type = string, resource_type = string|nil, name = string, address = string }
function M.get_resource_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Search backwards from cursor to find the resource declaration
  for i = current_line, 1, -1 do
    local line = lines[i]
    local resource = parse_resource_line(line)

    if resource then
      -- Verify we're still within this resource block by finding the closing brace
      -- Count opening and closing braces from resource line to cursor
      local brace_count = 0
      for j = i, current_line do
        local l = lines[j]
        -- Count braces
        for c in l:gmatch('[{}]') do
          if c == '{' then
            brace_count = brace_count + 1
          elseif c == '}' then
            brace_count = brace_count - 1
            -- If we hit zero, we've closed the block
            if brace_count == 0 and j < current_line then
              -- Cursor is outside this resource block
              goto continue
            end
          end
        end
      end

      -- If we're here, cursor is within this resource
      if brace_count > 0 then
        return resource
      end
    end

    ::continue::
  end

  return nil
end

--- Get all resources in the current buffer
--- @return table[] resources Array of resource_info tables
function M.get_all_resources_in_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local resources = {}

  for i, line in ipairs(lines) do
    local resource = parse_resource_line(line)
    if resource then
      resource.line = i
      table.insert(resources, resource)
    end
  end

  return resources
end

--- Check if current buffer is a Terraform file
--- @return boolean
function M.is_terraform_file()
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand('%:t')

  return filetype == 'terraform'
    or filetype == 'tf'
    or filename:match('%.tf$') ~= nil
    or filename:match('%.tfvars$') ~= nil
end

return M
