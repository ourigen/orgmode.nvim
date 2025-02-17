local uv = vim.loop
local utils = {}

---@param file string
---@param callback function
function utils.readfile(file, callback)
  uv.fs_open(file, 'r', 438, function(err1, fd)
    if err1 then
      return callback(err1)
    end
    uv.fs_fstat(fd, function(err2, stat)
      if err2 then
        return callback(err2)
      end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then
          return callback(err3)
        end
        uv.fs_close(fd, function(err4)
          if err4 then
            return callback(err4)
          end
          local lines = vim.split(data, '\n')
          table.remove(lines, #lines)
          return callback(nil, lines)
        end)
      end)
    end)
  end)
end

function utils.open(target)
  if vim.fn.executable('xdg-open') then
    return vim.fn.system(string.format('xdg-open %s', target))
  end

  if vim.fn.executable('open') then
    return vim.fn.system(string.format('open %s', target))
  end

  if vim.fn.has('win32') then
    return vim.fn.system(string.format('start "%s"', target))
  end
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
function utils.echo_warning(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'WarningMsg', additional_msg, store_in_history)
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
function utils.echo_error(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'ErrorMsg', additional_msg, store_in_history)
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
function utils.echo_info(msg, additional_msg, store_in_history)
  return utils._echo(msg, nil, additional_msg, store_in_history)
end

---@private
function utils._echo(msg, hl, additional_msg, store_in_history)
  vim.cmd([[redraw!]])
  local msg_item = { string.format('[orgmode] %s', msg) }
  if hl then
    table.insert(msg_item, hl)
  end
  local msg_list = { msg_item }
  if additional_msg then
    msg_list = utils.concat(msg_list, additional_msg)
  end
  local store = true
  if type(store_in_history) == 'boolean' then
    store = store_in_history
  end
  return vim.api.nvim_echo(msg_list, store, {})
end

---@param word string
---@return string
function utils.capitalize(word)
  return (word:gsub('^%l', string.upper))
end

---@param isoweekday number
---@return number
function utils.convert_from_isoweekday(isoweekday)
  if isoweekday == 7 then
    return 1
  end
  return isoweekday + 1
end

---@param weekday number
---@return number
function utils.convert_to_isoweekday(weekday)
  if weekday == 1 then
    return 7
  end
  return weekday - 1
end

---@param tbl table
---@param callback function
---@param acc any
---@return table
function utils.reduce(tbl, callback, acc)
  for i, v in pairs(tbl) do
    acc = callback(acc, v, i)
  end
  return acc
end

--- Concat one table at the end of another table
---@param first table
---@param second table
---@return table
function utils.concat(first, second)
  for _, v in ipairs(second) do
    table.insert(first, v)
  end
  return first
end

function utils.menu(title, items, prompt)
  local content = { title .. ':' }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, string.rep(item.separator or '-', item.length or 80))
    else
      valid_keys[item.key] = item
      table.insert(content, string.format('%s %s', item.key, item.label))
    end
  end
  prompt = prompt or 'key'
  table.insert(content, prompt .. ': ')
  vim.cmd(string.format('echon "%s"', table.concat(content, '\\n')))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd([[redraw!]])
  local entry = valid_keys[char]
  if not entry or not entry.action then
    return
  end
  return entry.action()
end

function utils.keymap(mode, lhs, rhs, opts)
  return vim.api.nvim_set_keymap(
    mode,
    lhs,
    rhs,
    vim.tbl_extend('keep', opts or {}, {
      nowait = true,
      silent = true,
      noremap = true,
    })
  )
end

function utils.buf_keymap(buf, mode, lhs, rhs, opts)
  return vim.api.nvim_buf_set_keymap(
    buf,
    mode,
    lhs,
    rhs,
    vim.tbl_extend('keep', opts or {}, {
      nowait = true,
      silent = true,
      noremap = true,
    })
  )
end

function utils.esc(cmd)
  return vim.api.nvim_replace_termcodes(cmd, true, false, true)
end

function utils.parse_tags_string(tags)
  local parsed_tags = {}
  for _, tag in ipairs(vim.split(tags or '', ':')) do
    if tag:find('^[%w_%%@#]+$') then
      table.insert(parsed_tags, tag)
    end
  end
  return parsed_tags
end

function utils.tags_to_string(taglist)
  local tags = ''
  if #taglist > 0 then
    tags = ':' .. table.concat(taglist, ':') .. ':'
  end
  return tags
end

function utils.ensure_array(val)
  if type(val) ~= 'table' then
    return { val }
  end
  return val
end

function utils.humanize_minutes(minutes)
  if minutes == 0 then
    return 'Now'
  end
  local is_past = minutes < 0
  local minutes_abs = math.abs(minutes)
  if minutes_abs < 60 then
    if is_past then
      return string.format('%d min ago', minutes_abs)
    end
    return string.format('in %d min', minutes_abs)
  end

  local hours = math.floor(minutes_abs / 60)
  local remaining_minutes = minutes_abs - (hours * 60)

  if remaining_minutes == 0 then
    if is_past then
      return string.format('%d hr ago', hours)
    end
    return string.format('in %d hr', hours)
  end

  if is_past then
    return string.format('%d hr and %d min ago', hours, remaining_minutes)
  end
  return string.format('in %d hr and %d min', hours, remaining_minutes)
end

return utils
