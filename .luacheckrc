std = "luajit"
globals = { "vim" }
exclude_files = { ".deps" }

files["tests"] = {
  globals = { "describe", "it", "before_each", "after_each", "assert" },
}
