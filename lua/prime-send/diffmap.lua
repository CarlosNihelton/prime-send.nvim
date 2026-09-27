local M = {}

--- Strip the a/ or b/ prefix from a diff path.
---@param path string
---@param prefix string
---@return string
local function strip_prefix(path, prefix)
  if path:sub(1, #prefix + 1) == prefix .. "/" then
    return path:sub(#prefix + 2)
  end
  return path
end

--- Parse a unified diff into one section per file, each with its hunks. The
--- file path comes from the +++ header (b/ prefix stripped, trailing tab or
--- timestamp removed), falling back to the diff --git paths, and from the
--- --- header when the +++ header is /dev/null.
---@param diff_text string|string[] the diff text or its lines
---@return table[] sections
function M.parse(diff_text)
  local lines = diff_text
  if type(diff_text) == "string" then
    lines = vim.split(diff_text, "\n", { plain = true })
  end

  local sections = {}
  local section, hunk = nil, nil
  local buf_line = 0

  for _, line in ipairs(lines) do
    buf_line = buf_line + 1

    if line:sub(1, 11) == "diff --git " then
      if section and section.path == nil then
        section.path = section.git_b
      end
      section = { hunks = {}, old_path = nil, path = nil, git_b = nil }
      sections[#sections + 1] = section
      section.git_b = line:sub(12):match(" b/(.+)$")
      hunk = nil
    elseif section == nil then
      goto continue
    elseif line:sub(1, 4) == "--- " then
      local p = line:sub(5)
      if p ~= "/dev/null" then
        section.old_path = strip_prefix(p, "a")
      end
      hunk = nil
    elseif line:sub(1, 4) == "+++ " then
      local p = line:sub(5):gsub("\t.*$", "")
      if p == "/dev/null" then
        section.path = section.old_path
      else
        section.path = strip_prefix(p, "b")
      end
      hunk = nil
    elseif line:sub(1, 2) == "@@" then
      local old_start, old_count, new_start, new_count = line:match("^@@%s*%-(%d+),?(%d*)%s*%+(%d+),?(%d*)")
      hunk = {
        old_start = tonumber(old_start) or 0,
        old_count = tonumber(old_count) or 1,
        new_start = tonumber(new_start) or 0,
        new_count = tonumber(new_count) or 1,
        buf_start = buf_line + 1,
        lines = {},
      }
      section.hunks[#section.hunks + 1] = hunk
    elseif hunk then
      hunk.lines[#hunk.lines + 1] = { text = line, buf_line = buf_line }
    end

    ::continue::
  end

  if section and section.path == nil then
    section.path = section.git_b
  end

  return sections
end

--- Map a line of the diff buffer to the line it denotes in the referenced
--- file. Context and + lines map to the new side, - lines to the old side.
--- Returns the file path and the mapped line, or nil for positions on
--- headers, between hunks, or past the end.
---@param sections table[]
---@param buf_line integer
---@return string|nil path
---@return integer|nil line
function M.locate(sections, buf_line)
  for _, section in ipairs(sections) do
    for _, hunk in ipairs(section.hunks) do
      if buf_line >= hunk.buf_start and buf_line < hunk.buf_start + #hunk.lines then
        local new_line, old_line = hunk.new_start, hunk.old_start
        for _, entry in ipairs(hunk.lines) do
          local kind = entry.text:sub(1, 1)
          if entry.buf_line == buf_line then
            if kind == "-" then
              return section.path, old_line
            elseif kind == "+" or kind == " " then
              return section.path, new_line
            end
            return nil
          end
          if kind == "-" then
            old_line = old_line + 1
          else
            old_line = old_line + 1
            new_line = new_line + 1
          end
        end
      end
    end
  end
  return nil
end

return M
