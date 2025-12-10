local M = {}
local Job = require("plenary.job")

function M.get_context()
  -- Get entire buffer text
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, '\n')

  -- Insert <|cursor|> at cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  if row >= 0 and row < #lines then
    local line = lines[row + 1]
    if col <= #line then
      lines[row + 1] = line:sub(1, col) .. '<|cursor|>' .. line:sub(col + 1)
      text = table.concat(lines, '\n')
    end
  end
  return text
end

function M.create_session(callback)
	Job:new({
		command = "curl",
		args = {
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-d",
			vim.json.encode({ title = "opencode-completion-session" }),
			"http://localhost:4096/session",
		},
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local stderr = table.concat(j:stderr_result(), "\n")
					vim.notify(
						"opencode-completion: Failed to create session, stderr: " .. stderr,
						vim.log.levels.ERROR
					)
					callback(nil)
					return
				end
				local result = table.concat(j:result(), "\n")
				local ok, data = pcall(vim.json.decode, result)
				if not ok or not data.id then
					vim.notify("opencode-completion: Invalid session response", vim.log.levels.ERROR)
					callback(nil)
					return
				end
				callback(data.id)
			end)
		end,
	}):start()
end

function M.send_completion_request(session_id, context, callback)
	local lang = vim.bo.filetype
	local prompt = string.format(
		"You are a Senior %s Developer. The code below has a <|cursor|> marker indicating the cursor position. Look at the function name and surrounding context to understand what the function should do, then complete the code by replacing <|cursor|> with the appropriate code continuation. Return ONLY the code that should replace <|cursor|>, nothing else (no explanations, no markdown, no original code): %s",
		lang,
		context
	)

	Job:new({
		command = "curl",
		args = {
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"-d",
			vim.json.encode({
				parts = { { type = "text", text = prompt } },
			}),
			string.format("http://localhost:4096/session/%s/message", session_id),
		},
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local stderr = table.concat(j:stderr_result(), "\n")
					vim.notify("opencode-completion: Failed to send request, stderr: " .. stderr, vim.log.levels.ERROR)
					callback(nil)
					return
				end
				local result = table.concat(j:result(), "\n")
				vim.notify('opencode-completion: Raw result length: ' .. #result, vim.log.levels.INFO)
				local ok, data = pcall(vim.json.decode, result)
				if not ok then
					vim.notify("opencode-completion: Failed to decode JSON", vim.log.levels.ERROR)
					callback(nil)
					return
				end
				if data.success == false then
					vim.notify("opencode-completion: API error", vim.log.levels.ERROR)
					callback(nil)
					return
				end
				local parts = data.data and data.data.parts or data.parts
				if not parts or #parts == 0 then
					vim.notify("opencode-completion: No parts in response", vim.log.levels.ERROR)
					callback(nil)
					return
				end
				-- Find the text part
				local completion = nil
				for _, part in ipairs(parts) do
					if part.type == "text" and part.text then
						completion = part.text
						break
					end
				end
				if not completion then
					vim.notify("opencode-completion: No text part in response", vim.log.levels.ERROR)
					callback(nil)
					return
				end
				-- Clean null characters and other non-printable characters
				completion = completion:gsub('\0', ''):gsub('[\1-\8\11-\12\14-\31\127-\255]', ''):gsub('<|cursor|>', '')
				if completion:match("```") then
					local lines = vim.split(completion, "\n")
					local in_code = false
					local code_lines = {}
					for _, line in ipairs(lines) do
						if line:match("```") then
							in_code = not in_code
							if not in_code then
								break
							end
						elseif in_code then
							table.insert(code_lines, line)
						end
					end
					completion = table.concat(code_lines, "\n")
				end
				callback(completion)
			end)
		end,
	}):start()
end

return M
