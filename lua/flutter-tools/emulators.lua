local Job = require("flutter-tools.job")
local ui = require("flutter-tools.ui")
local utils = require("flutter-tools.utils")
local executable = require("flutter-tools.executable")

local api = vim.api

local M = {}
-----------------------------------------------------------------------------//
-- Emulators
-----------------------------------------------------------------------------//
-- Despite looking a lot like emulators can be combined with the devices
-- there are a few subtle differences that would need to be taken into account
-- in a more generalised function, which frankly would be a little more complex,
-- hard to follow and less versatile. Emulators and devices are not the same so
-- they should be handled separately so it's easier to make changes to one
-- without it affecting the other

function _G.__flutter_tools_select_emulator()
  local emulators = vim.b.emulators
  if not emulators then
    vim.cmd [[echomsg "Sorry there is no emulator on this line"]]
    return
  end
  local lnum = vim.fn.line(".")
  local emulator = emulators[lnum]
  if emulator then
    M.launch_emulator(emulator)
  end
  api.nvim_win_close(0, true)
end
---@param emulator table
function M.launch_emulator(emulator)
  if not emulator then
    return
  end
  Job:new {
    command = executable.flutter(),
    args = {"emulators", "--launch", emulator.id},
    on_stderr = function(error, data, _)
      vim.schedule(
        function()
          ui.notify({"Error launching emulators: ", data, error})
        end
      )
    end,
    on_exit = function(job, _)
      local result = job:result()
      if not vim.tbl_isempty(result) then
        vim.schedule(
          function()
            ui.notify(job:result())
          end
        )
      end
    end
  }:sync()
end

---@param line string
function M.parse(line)
  local parts = vim.split(line, "•")
  if #parts == 4 then
    return {
      name = vim.trim(parts[2]),
      id = vim.trim(parts[1]),
      platform = vim.trim(parts[3]),
      system = vim.trim(parts[4])
    }
  end
end

---@param data table
local function get_emulators(data)
  local result = {emulators = {}, data = {}}
  for _, line in pairs(data) do
    local emulator = M.parse(line)
    if emulator then
      table.insert(result.emulators, emulator)
    end
    table.insert(result.data, line)
  end
  return result
end

local function setup_emulators_win(result, highlights)
  return function(buf, _)
    ui.add_highlights(buf, highlights)
    if #result.emulators > 0 then
      api.nvim_buf_set_var(buf, "emulators", result.emulators)
    end
    api.nvim_buf_set_keymap(
      buf,
      "n",
      "<CR>",
      ":lua __flutter_tools_select_emulator()<CR>",
      {silent = true, noremap = true}
    )
  end
end

---@param result table
local function show_emulators(result)
  local formatted = {}
  local output = get_emulators(result)
  local has_emulators = #output.emulators > 0
  local highlights = {}
  if has_emulators then
    for lnum, item in pairs(output.emulators) do
      local name = utils.display_name(item.name, item.platform)
      utils.add_device_highlights(highlights, name, lnum, item)
      table.insert(formatted, name)
    end
  else
    for _, line in pairs(output.data) do
      table.insert(formatted, line)
    end
  end
  if #formatted > 0 then
    vim.schedule(
      function()
        ui.popup_create("Flutter emulators", formatted, setup_emulators_win(output, highlights))
      end
    )
  end
end

function M.list()
  M.job =
    Job:new {
    command = executable.flutter(),
    args = {"emulators"},
    on_exit = function(j, _)
      show_emulators(j:result())
    end
  }:sync(8000)
end

return M
