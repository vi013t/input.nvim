local tests = {}

function tests.test()
	local input = require("input")
	local primitives = require("input.primitives")

	local string = primitives.string
	local integer = primitives.integer

	input({
		name = string(),
		age = integer():nonnegative():max(100),
		address = {
			street = integer():positive():integeric(),
			city = string(),
			state = string():validate(function(state) return #state == 2 end, "State must be 2 letters"),
			zip = integer():positive():max(99999),
			apartment = string():optional()
		}
	}, {
		on_complete = function(person_info)
			print(vim.inspect(person_info))
		end
	})
end

return tests
