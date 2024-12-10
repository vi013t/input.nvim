local input = require("input")

local primitives = require("input.primitives")

local tests = {}


function tests.test()
	local number = primitives.number
	local string = primitives.string

	local person_info = input.input({
		name = string():nonempty(),
		age = number():nonnegative():max(100),
		address = {
			number = number():positive(),
			street_name = string():nonempty(),
			city = string():nonempty(),
			zip = number():positive():max(99999)
		}
	})

	print(vim.inspect(person_info))
end

return tests
