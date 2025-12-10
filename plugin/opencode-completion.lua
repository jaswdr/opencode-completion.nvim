if vim.g.loaded_opencode_completion then
  return
end
vim.g.loaded_opencode_completion = true

require('opencode-completion')