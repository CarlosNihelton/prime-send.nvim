-- Minimal init for running the busted suite standalone with plenary.
vim.opt.runtimepath:append(vim.fn.getcwd() .. "/.deps/plenary.nvim")
vim.opt.runtimepath:append(vim.fn.getcwd())

require("plenary")
