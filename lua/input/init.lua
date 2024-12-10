local input_width = 30

local function setup_highlights()
	local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")

	local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Comment")), "fg#")
	vim.api.nvim_set_hl(0, "ConfigureNeutral", { bg = bg, fg = fg })

	fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("DiagnosticError")), "fg#")
	vim.api.nvim_set_hl(0, "ConfigureBad", { bg = bg, fg = fg, bold = true })

	fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("DiagnosticOk")), "fg#")
	vim.api.nvim_set_hl(0, "ConfigureGood", { bg = bg, fg = fg, bold = true })
end

---@param text string
local function to_title_case(text)
	local builder = ""
	local is_first_word_character = true
	for index = 1, #text do
		local character = text:sub(index, index)
		if is_first_word_character then
			builder = builder .. character:upper()
			is_first_word_character = false
		else
			if character == "_" then character = " " end
			if character == " " then
				is_first_word_character = true
			end
			builder = builder .. character
		end
	end
	return builder
end


---@param value Primitive | table<string, Primitive>
---
---@return integer
local function ordering(value)
	if value.__order ~= nil then
		---@cast value Primitive
		return value.__order
	end

	---@cast value table<string, Primitive>

	local orders = {}
	for _, table_value in pairs(value) do
		table.insert(orders, ordering(table_value))
	end

	return math.min(table.unpack(orders))
end

---@alias InputBox { line: integer, column: integer, }

---@return InputBox
local function draw_input_box(buffer, column, width, title, content, state, failure_message, required)
	-- Highlight
	local highlight = "ConfigureNeutral"
	if state == "valid" then
		highlight = "ConfigureGood"
	elseif state == "invalid" then
		highlight = "ConfigureBad"
	end

	local full_title = " " .. title .. " "
	if required then full_title = full_title .. "* " end

	local top_line = (" "):rep(column - 1) ..
		"╭ " ..
		full_title ..
		("─"):rep(width - 3 - #full_title) ..
		"╮"
	local middle_line = (" "):rep(column - 1) ..
		"│" ..
		" " ..
		content ..
		(" "):rep(width - 3 - #content) ..
		"│"
	local bottom_line = (" "):rep(column - 1) ..
		"╰" ..
		("─"):rep(width - 2) ..
		"╯"

	local middle_line_with_message = middle_line
	if failure_message ~= nil and state ~= "neutral" then
		middle_line_with_message = middle_line_with_message .. "  " .. failure_message
	end

	vim.api.nvim_buf_set_lines(buffer, -1, -1, true, { top_line })
	vim.api.nvim_buf_set_lines(buffer, -1, -1, true, { middle_line_with_message })
	vim.api.nvim_buf_set_lines(buffer, -1, -1, true, { bottom_line })

	-- Top Line
	vim.api.nvim_buf_add_highlight(
		buffer,
		-1,
		highlight,
		vim.api.nvim_buf_line_count(buffer) - 3,
		0,
		#top_line
	)

	if required then
		vim.api.nvim_buf_add_highlight(
			buffer,
			-1,
			"ConfigureBad",
			vim.api.nvim_buf_line_count(buffer) - 3,
			column + 1 + #full_title,
			column + 2 + #full_title
		)
	end

	-- Middle Line
	vim.api.nvim_buf_add_highlight(
		buffer,
		-1,
		highlight,
		vim.api.nvim_buf_line_count(buffer) - 2,
		column - 1,
		column
	)

	-- Bottom line
	vim.api.nvim_buf_add_highlight(
		buffer,
		-1,
		highlight,
		vim.api.nvim_buf_line_count(buffer) - 1,
		0,
		#bottom_line
	)

	vim.api.nvim_buf_add_highlight(
		buffer,
		-1,
		highlight,
		vim.api.nvim_buf_line_count(buffer) - 2,
		#middle_line - 3,
		#middle_line
	)

	if failure_message ~= nil then
		vim.api.nvim_buf_add_highlight(
			buffer,
			-1,
			highlight,
			vim.api.nvim_buf_line_count(buffer) - 2,
			#middle_line + 2,
			#middle_line_with_message
		)
	end
	return { line = vim.api.nvim_buf_line_count(buffer) - 1, column = column + 3, content = content }
end

---@param value table<string, Primitive>
local function ordered_pairs(value)
	local seen = {}

	---@return string | nil, Primitive | table<string, Primitive> | nil
	return function()
		local min = 999999999
		local min_value = nil
		local min_key = nil
		for key, table_value in pairs(value) do
			if vim.list_contains(seen, key) then
				goto continue
			end

			local order = ordering(table_value)
			if order < min then
				min = order
				min_value = table_value
				min_key = key
			end

			::continue::
		end

		table.insert(seen, min_key)
		return min_key, min_value
	end
end

---@alias Screen { main_buffer: integer, main_window: integer, input_buffers: integer[], input_windows: integer[], close: fun(self): nil }

---@param arguments { screen: Screen, value: Primitive | table<string, Primitive>, name?: string, line?: number, column?: number, content: { line: integer, content: string }[] }
local function add_input(arguments)
	if arguments.name == nil then
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true, { "" })
	end
	local line = arguments.line or 1
	local column = arguments.column or 0

	-- Individual value
	if arguments.value.__type ~= nil then
		local value = arguments.value
		---@cast value Primitive

		-- Get content
		local content = ""
		local input_line = vim.api.nvim_buf_line_count(arguments.screen.main_buffer) + 2
		for _, input in ipairs(arguments.content) do
			if input.line == input_line then
				content = input.content
				break
			end
		end

		local converted_value, failure_message = value.__convert(content)
		if converted_value ~= nil then
			failure_message = value:__validate(converted_value)
		end

		local state = "neutral"
		if content ~= "" then
			state = "valid"
		end
		if state ~= "neutral" and failure_message ~= nil then
			state = "invalid"
		end

		local input_box = draw_input_box(
			arguments.screen.main_buffer,
			column,
			input_width,
			to_title_case(arguments.name),
			content,
			state,
			failure_message,
			value.__default == nil
		)
		table.insert(arguments.screen.input_boxes, input_box)

		return
	end

	local name = arguments.name

	-- Table of values
	local value = arguments.value
	---@cast value table<string, Primitive>
	if arguments.name ~= nil then
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true, { "" })
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true,
			{ (" "):rep(arguments.column) .. to_title_case(arguments.name) }
		)
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true, { "" })
		line = line + 2
	end
	arguments.column = column + 3
	line = line + 1
	for key, table_value in ordered_pairs(value) do
		arguments.name = key
		arguments.value = table_value
		arguments.line = line
		add_input(arguments)
		line = line + 3
	end

	if name == nil then
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true, { "" })
		vim.api.nvim_buf_set_lines(arguments.screen.main_buffer, -1, -1, true, { "   Confirm" })
		vim.api.nvim_buf_add_highlight(
			arguments.screen.main_buffer,
			-1,
			"ConfigureGoodBorder",
			vim.api.nvim_buf_line_count(arguments.screen.main_buffer) - 1,
			3, 3 + #"Confirm"
		)
	end
end

local function redraw(screen, schema, options)
	local cursor = vim.api.nvim_win_get_cursor(screen.main_window)[1]
	local line = assert(vim.api.nvim_buf_get_lines(screen.main_buffer, cursor - 1, cursor, true)[1]:match(
		"│ ([^%s]*)%s*│"))

	local old_index = nil
	for index, content_line in ipairs(screen.content) do
		if content_line.line == cursor then
			old_index = index
			break
		end
	end

	if old_index ~= nil then
		table.remove(screen.content, old_index)
	end

	table.insert(screen.content, { line = cursor, content = line })

	vim.api.nvim_buf_set_lines(screen.main_buffer, 0, -1, true, {})
	vim.api.nvim_buf_set_lines(screen.main_buffer, -1, -1, true, { "  " .. options.title })
	screen.input_boxes = {}

	add_input({
		screen = screen,
		value = schema,
		content = screen.content,
	})

	local column = screen.input_boxes[screen.current_input_box].column
	for _, input in ipairs(screen.content) do
		if input.line == screen.input_boxes[screen.current_input_box].line then
			column = column + #input.content
			break
		end
	end

	vim.api.nvim_win_set_cursor(screen.main_window, {
		screen.input_boxes[screen.current_input_box].line,
		column
	})
	vim.api.nvim_command("startinsert")
end

---@type PartialInputOptions
local default_input_options = {
	window_options = {
		width = 70,
		height = 30,
		relative = "editor",
		style = "minimal",
		border = "rounded"
	},
	convert_case = true,
	title = "Input",
	on_complete = function() end
}

---@class InputOptions
---@field convert_case boolean
---@field window_options table<any, any>,
---@field title string
---@field on_complete fun(value: table): nil

---@class PartialInputOptions
---@field convert_case? boolean
---@field window_options? table<any, any>,
---@field title? string
---@field on_complete? fun(value: table): nil

---@param schema Primitive | table<string, Primitive>
---@param options PartialInputOptions | nil
local function input(schema, options)
	options = options or {}
	options = vim.tbl_deep_extend("force", default_input_options, options)

	setup_highlights()
	local vim_width = vim.api.nvim_get_option_value("columns", { scope = "global" })
	local vim_height = vim.api.nvim_get_option_value("lines", { scope = "global" })

	local buffer = vim.api.nvim_create_buf(false, true)

	local window = vim.api.nvim_open_win(buffer, true, vim.tbl_deep_extend("force", {
		row = math.ceil((vim_height - options.window_options.height) / 2 - 1),
		col = math.ceil((vim_width - options.window_options.width) / 2),
	}, options.window_options))

	---@type Screen
	local screen = {
		main_buffer = buffer,
		main_window = window,
		input_boxes = {},
		content = {},
		current_input_box = 1,
		close = function(self)
			vim.api.nvim_buf_delete(self.main_buffer, { force = true })
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', false)
		end
	}

	-- Mappings
	vim.keymap.set("i", "<Tab>", function()
		screen.current_input_box = screen.current_input_box + 1
		redraw(screen, schema, options)
	end, { buffer = screen.main_buffer })
	vim.keymap.set("i", "<Enter>", function()
		screen.current_input_box = screen.current_input_box + 1
		redraw(screen, schema, options)
	end, { buffer = screen.main_buffer })
	vim.keymap.set("i", "<Esc>", function()
		screen:close()
	end, { buffer = screen.main_buffer })
	vim.keymap.set("i", "<S-Tab>", function()
		screen.current_input_box = screen.current_input_box - 1
		redraw(screen, schema, options)
	end, { buffer = screen.main_buffer })

	vim.keymap.set("n", "q", function() screen:close() end, { buffer = screen.main_buffer })

	add_input({
		screen = screen,
		value = schema,
		content = {},
	})

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = buffer,
		callback = function()
			redraw(screen, schema, options)
		end
	})

	vim.api.nvim_win_set_cursor(screen.main_window, {
		screen.input_boxes[screen.current_input_box].line,
		screen.input_boxes[screen.current_input_box].column,
	})
	redraw(screen, schema, options)
end

return input
