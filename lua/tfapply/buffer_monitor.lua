--- Monitor a terminal buffer for terraform approval prompts
--- This provides TTY compatibility while enabling interactive review

local M = {}

--- @class BufferMonitor
--- @field bufnr number The terminal buffer number
--- @field timer userdata Timer for polling buffer
--- @field on_prompt function Callback when prompt is detected
--- @field on_exit function Callback when process exits
--- @field prompt_detected boolean Whether prompt was detected
--- @field job_id number Terminal job ID

--- Start monitoring a terminal buffer for approval prompts
--- @param bufnr number Buffer number to monitor
--- @param job_id number Terminal job ID
--- @param callbacks table { on_prompt, on_exit }
--- @return BufferMonitor
function M.start(bufnr, job_id, callbacks)
  local monitor = {
    bufnr = bufnr,
    timer = vim.loop.new_timer(),
    on_prompt = callbacks.on_prompt,
    on_exit = callbacks.on_exit,
    prompt_detected = false,
    job_id = job_id,
  }

  -- Poll the buffer for prompt detection
  monitor.timer:start(100, 100, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      M.stop(monitor)
      return
    end

    -- Get all buffer lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Check if process has exited
    local channel_info = vim.fn.jobwait({ job_id }, 0)
    if channel_info[1] ~= -1 then
      -- Process has exited
      M.stop(monitor)
      if monitor.on_exit then
        monitor.on_exit(channel_info[1])
      end
      return
    end

    -- Look for approval prompt in last few lines
    if not monitor.prompt_detected then
      local check_lines = math.min(#lines, 10) -- Check last 10 lines
      for i = #lines - check_lines + 1, #lines do
        local line = lines[i] or ""

        -- Terraform approval prompt patterns
        if line:match('Do you want to perform these actions%?') or
           line:match('Do you really want to destroy') or
           line:match('Enter a value:') then
          monitor.prompt_detected = true

          -- Pause the timer
          monitor.timer:stop()

          -- Call the prompt callback with all lines
          if monitor.on_prompt then
            monitor.on_prompt(lines, job_id)
          end

          return
        end
      end
    end
  end))

  return monitor
end

--- Stop monitoring
--- @param monitor BufferMonitor
function M.stop(monitor)
  if monitor.timer then
    monitor.timer:stop()
    if not monitor.timer:is_closing() then
      monitor.timer:close()
    end
  end
end

--- Send input to the terminal job
--- @param job_id number Terminal job ID
--- @param input string Input to send
function M.send_input(job_id, input)
  -- Check if the job is still running
  -- jobwait with timeout 0 returns -1 if still running, exit code if finished
  local status = vim.fn.jobwait({ job_id }, 0)
  if status[1] ~= -1 then
    vim.notify('Terminal job is no longer running', vim.log.levels.ERROR)
    return false
  end

  -- Ensure input ends with newline
  if not input:match('\n$') then
    input = input .. '\n'
  end

  local success, err = pcall(vim.fn.chansend, job_id, input)
  if not success then
    vim.notify('Failed to send input to terraform process: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
