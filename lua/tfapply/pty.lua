--- PTY-based terraform process manager
--- Provides fine-grained control over terraform execution for interactive mode

local M = {}
local uv = vim.loop

--- @class TerraformProcess
--- @field handle userdata Process handle
--- @field stdin userdata Stdin pipe
--- @field stdout userdata Stdout pipe
--- @field stderr userdata Stderr pipe
--- @field pid number Process ID
--- @field output_buffer string[] Accumulated output lines
--- @field on_output function|nil Callback for new output
--- @field on_prompt function|nil Callback when approval prompt detected
--- @field on_exit function|nil Callback when process exits
--- @field paused boolean Whether output reading is paused
--- @field prompt_detected boolean Whether we've seen the approval prompt

--- Create a new terraform process with PTY control
--- @param cmd string[] Command and arguments
--- @param opts table Options { cwd, env, on_output, on_prompt, on_exit }
--- @return TerraformProcess|nil process
--- @return string|nil error
function M.spawn(cmd, opts)
  opts = opts or {}

  local process = {
    handle = nil,
    stdin = nil,
    stdout = nil,
    stderr = nil,
    pid = nil,
    output_buffer = {},
    on_output = opts.on_output,
    on_prompt = opts.on_prompt,
    on_exit = opts.on_exit,
    paused = false,
    prompt_detected = false,
  }

  -- Create pipes for communication
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  if not stdin or not stdout or not stderr then
    return nil, "Failed to create pipes"
  end

  process.stdin = stdin
  process.stdout = stdout
  process.stderr = stderr

  -- Prepare spawn options
  local spawn_opts = {
    args = vim.list_slice(cmd, 2), -- All args except the first (command)
    stdio = { stdin, stdout, stderr },
    cwd = opts.cwd,
    env = opts.env,
    -- Hide the window on Windows
    hide = true,
  }

  -- Output processing function
  local function process_output(data, is_stderr)
    if not data or process.paused then
      return
    end

    -- Split into lines
    local lines = vim.split(data, '\n', { plain = true })

    for i, line in ipairs(lines) do
      -- Skip empty last line from split
      if i == #lines and line == '' then
        break
      end

      table.insert(process.output_buffer, line)

      -- Check for approval prompt
      if not process.prompt_detected then
        -- Terraform approval prompt patterns
        local prompt_patterns = {
          'Do you want to perform these actions%?',
          'Do you really want to destroy all resources%?',
          'Enter a value:',
        }

        for _, pattern in ipairs(prompt_patterns) do
          if line:match(pattern) then
            process.prompt_detected = true
            process.paused = true

            if process.on_prompt then
              vim.schedule(function()
                process.on_prompt(process.output_buffer)
              end)
            end

            return
          end
        end
      end

      -- Call output callback
      if process.on_output then
        vim.schedule(function()
          process.on_output(line, is_stderr)
        end)
      end
    end
  end

  -- Read stdout
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify('Error reading terraform stdout: ' .. err, vim.log.levels.ERROR)
      end)
      return
    end

    if data then
      process_output(data, false)
    end
  end)

  -- Read stderr
  stderr:read_start(function(err, data)
    if err then
      vim.schedule(function()
        vim.notify('Error reading terraform stderr: ' .. err, vim.log.levels.ERROR)
      end)
      return
    end

    if data then
      process_output(data, true)
    end
  end)

  -- Spawn the process
  local handle, pid_or_err = uv.spawn(cmd[1], spawn_opts, function(code, signal)
    -- Cleanup
    if process.handle and not process.handle:is_closing() then
      process.handle:close()
    end

    if not stdin:is_closing() then
      stdin:close()
    end

    if not stdout:is_closing() then
      stdout:close()
    end

    if not stderr:is_closing() then
      stderr:close()
    end

    -- Call exit callback
    if process.on_exit then
      vim.schedule(function()
        process.on_exit(code, signal)
      end)
    end
  end)

  if not handle then
    return nil, "Failed to spawn process: " .. tostring(pid_or_err)
  end

  process.handle = handle
  process.pid = pid_or_err

  return process, nil
end

--- Send input to the terraform process
--- @param process TerraformProcess
--- @param input string Input to send (will automatically append newline)
function M.send_input(process, input)
  if not process or not process.stdin then
    return
  end

  -- Ensure input ends with newline
  if not input:match('\n$') then
    input = input .. '\n'
  end

  process.stdin:write(input)
  process.paused = false -- Resume output processing
end

--- Resume output processing after it was paused
--- @param process TerraformProcess
function M.resume_output(process)
  if process then
    process.paused = false
  end
end

--- Kill the terraform process
--- @param process TerraformProcess
--- @param signal number|nil Signal to send (default: SIGTERM)
function M.kill(process, signal)
  if not process or not process.handle then
    return
  end

  signal = signal or uv.constants.SIGTERM
  process.handle:kill(signal)
end

--- Check if process is still running
--- @param process TerraformProcess
--- @return boolean
function M.is_running(process)
  return process and process.handle and not process.handle:is_closing()
end

return M
