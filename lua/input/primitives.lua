local primitives = {}

---@alias Primitive { __type: string, __order: integer, [string]: unknown }

local index = 0

local function next_index()
	index = index + 1
	return index
end

primitives.number = function()
	return {
		validate = function(self, validation, error_message)
			table.insert(self.__validation_hooks, { test = validation, failure_message = error_message })
			return self
		end,

		max = function(self, max)
			table.insert(self.__validation_hooks, {
				failure_message = "Value cannot be larger than " .. tostring(max),
				test = function(value)
					return value <= max
				end
			})
			return self
		end,

		min = function(self, min)
			table.insert(self.__validation_hooks, {
				failure_message = "Value cannot be smaller than " .. tostring(min),
				test = function(value)
					return value >= min
				end
			})
			return self
		end,

		nonnegative = function(self)
			return self:min(0)
		end,

		--- Enforces that this number must be positive (> 0).
		---
		---@return self
		positive = function(self)
			table.insert(self.__validation_hooks, {
				failure_message = "Value must be positive",
				test = function(value)
					return value > 0
				end
			})
			return self
		end,

		negative = function(self)
			table.insert(self.__validation_hooks, {
				failure_message = "Value must be negative",
				test = function(value)
					return value < 0
				end
			})
			return self
		end,

		integeric = function(self)
			table.insert(self.__validation_hooks, {
				failure_message = "Value must be an integer",
				test = function(value)
					return value == math.floor(value)
				end
			})
			return self
		end,

		default = function(self, value)
			self.__default = value
			return self
		end,

		optional = function(self)
			return self:default("")
		end,

		__default = nil,
		__convert = function(value)
			local number = tonumber(value)
			if number == nil then
				return nil, "Value must be a number"
			end
			return number
		end,
		__validation_hooks = {},
		__type = "number",
		__order = next_index(),
		__validate = function(self, value)
			for _, hook in ipairs(self.__validation_hooks) do
				if not hook.test(value) then
					return hook.failure_message
				end
			end
			return nil
		end,
	}
end

primitives.string = function()
	return {
		validate = function(self, validator, failure_message)
			table.insert(self.__validation_hooks,
				{ test = validator, failure_message = failure_message or "Invalid value" })
			return self
		end,

		nonempty = function(self)
			table.insert(self.__validation_hooks, {
				failure_message = "Value cannot be empty",
				test = function(value)
					return value ~= ""
				end
			})
			return self
		end,

		hidden = function(self)
			self.__hidden = true
			return self
		end,

		one_of = function(self, list)
			return self:validate(
				function(value) return vim.list_contains(list, value) end,
				("Value must be either %s"):format(table.concat(list, ", "))
			)
		end,

		length = function(self, length)
			table.insert(self.__validation_hooks, {
				failure_message = ("Value must be %d characters"):format(length),
				test = function(value)
					return #value == length
				end
			})
			return self
		end,

		match = function(self, pattern)
			return self:validate(function(value)
				return value:match(pattern)
			end, ("Value must match \"%s\""):format(pattern))
		end,

		optional = function(self)
			return self:default("")
		end,


		default = function(self, value)
			self.__default = value
			return self
		end,

		__default = nil,
		__convert = function(value) return value end,
		__validation_hooks = {},
		__type = "string",
		__order = next_index(),

		__validate = function(self, value)
			for _, hook in ipairs(self.__validation_hooks) do
				if not hook.test(value) then
					return hook.failure_message
				end
			end
			return nil
		end,
	}
end

primitives.integer = function()
	return primitives.number():integeric()
end

primitives.list = function()
	return {
		validate = function(self, validation, failure_message)
			table.insert(self.__validation_hooks, validation, failure_message)
			return self
		end,

		default = function(self, value)
			self.__default = value
			return self
		end,

		__default = nil,
		__convert = function(value) return value end,
		__validation_hooks = {},
		__type = "string",
		__order = next_index(),

		__validate = function(self, value)
			for _, hook in ipairs(self.__validation_hooks) do
				if not hook.test(value) then
					return hook.failure_message
				end
			end
			return nil
		end,
	}
end

return primitives
