local tests = {}

function tests.test()
	local input = require("input")
	local primitives = require("input.primitives")

	local string = primitives.string
	local integer = primitives.integer

	input({
			name = string(),
			age = integer():positive():max(100),
			address = {
				street = integer():positive(),
				city = string(),
				state = string():one_of({ "NY", "PA" }),
				zip = string():length(5):match("^%d+$"),
				apartment = string():optional()
			}
		},
		{
			on_complete = function(person_info)
				print(vim.inspect(person_info))
			end
		}
	)
end

return tests
