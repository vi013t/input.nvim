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

		default = function(self, value)
			self.__default = value
			return self
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
		validate = function(self, validation, failure_message)
			table.insert(self.__validation_hooks, validation, failure_message)
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
