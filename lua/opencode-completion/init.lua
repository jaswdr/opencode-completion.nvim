local M = {}

local session_id = nil
local ghost_ns = vim.api.nvim_create_namespace("opencode_completion_ghost")
local ghost_extmark_id = nil

function M.setup(opts)
	opts = opts or {}
	-- Check for nvim-treesitter
	local ok, _ = pcall(require, "nvim-treesitter")
	if not ok then
		vim.notify("opencode-completion: nvim-treesitter is required but not installed", vim.log.levels.ERROR)
		return
	end
	-- Check for plenary
	ok, _ = pcall(require, "plenary")
	if not ok then
		vim.notify("opencode-completion: plenary.nvim is required but not installed", vim.log.levels.ERROR)
		return
	end

	vim.keymap.set({"n", "i"}, "<C-l>", function()
		M.trigger_completion()
	end, { desc = "Trigger OpenCode completion" })

	-- User commands for debugging
	vim.api.nvim_create_user_command("OpenCodeComplete", M.trigger_completion, {})
	vim.api.nvim_create_user_command("OpenCodeSession", function()
		if session_id then
			vim.notify("Current session ID: " .. session_id, vim.log.levels.INFO)
		else
			vim.notify("No session created yet", vim.log.levels.INFO)
		end
	end, {})
end

function M.trigger_completion()
	print("opencode-completion: trigger called")
	-- Set mark at cursor
	vim.cmd("normal! mc")

	local utils = require("opencode-completion.utils")
	local context = utils.get_context()
	if not context then
		vim.notify("opencode-completion: Failed to extract context", vim.log.levels.ERROR)
		return
	end

	-- Show ghost text
	local cursor = vim.api.nvim_win_get_cursor(0)
	ghost_extmark_id = vim.api.nvim_buf_set_extmark(0, ghost_ns, cursor[1]-1, cursor[2], {
		virt_text = { { "Vibe coding...", "Comment" } },
		virt_text_pos = "inline",
	})

	-- Ensure session
	if not session_id then
		utils.create_session(function(id)
			session_id = id
			utils.send_completion_request(session_id, context, function(response)
				vim.schedule(function() M.handle_response(response) end)
			end)
		end)
	else
		utils.send_completion_request(session_id, context, function(response)
			vim.schedule(function() M.handle_response(response) end)
		end)
	end
end

function M.handle_response(response)
	-- Clear ghost text
	if ghost_extmark_id then
		vim.api.nvim_buf_del_extmark(0, ghost_ns, ghost_extmark_id)
		ghost_extmark_id = nil
	end

	if not response then
		vim.notify("opencode-completion: No response from server", vim.log.levels.ERROR)
		return
	end

	-- Insert the code
	local cursor = vim.api.nvim_win_get_cursor(0)
	local lines = vim.split(response, '\n')
	vim.notify("opencode-completion: Inserting lines: " .. vim.inspect(lines), vim.log.levels.INFO)
	vim.api.nvim_buf_set_text(0, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2], lines)
	-- Keep cursor at original position
	vim.api.nvim_win_set_cursor(0, cursor)
end

return M

