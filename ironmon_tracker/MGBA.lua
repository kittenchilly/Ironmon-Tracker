MGBA = {
	-- TextBuffer screens
	Screens = {
	},
}

function MGBA.initialize()
	-- Currently unused
end

function MGBA.createBuffers()
	local screens = { "Main Screen" } -- , "Enemy Screen"
	for _, screen in ipairs(screens) do
		MGBA.Screens[screen] = console:createBuffer(screen)
	end
end

function MGBA.drawScreen()
	local screen = MGBA.Screens["Main Screen"]

	local data = DataHelper.buildTrackerScreenDisplay()
	MGBA.formatPokemonDisplayObj(data)

	-- %-#s means to left-align, padding out the right-part of the string with spaces
	local justify2, justify3
	if Options["Right justified numbers"] then
		justify2, justify3 = "%2s", "%3s"
	else
		justify2, justify3 = "%-2s", "%-3s"
	end

	local topheader = "%-20s %-5s" .. justify3
	local topbar = "%-20s %-5s" .. justify3
	local lines = {
		string.format(topheader, string.format("%-13s", data.p.name), "BST", data.p.bst),
		string.format("-------%-20s--", data.p.types):gsub(" ", "-"),
		string.format(topbar, string.format("HP: %s/%s   %s", data.p.curHP, data.p.hp, data.p.status), data.p.labels.hp, data.p.hp),
		string.format(topbar, string.format("Lv.%s (%s)", data.p.level, data.p.evo), data.p.labels.atk, data.p.atk),
		string.format(topbar, string.format("%s", data.p.line1), data.p.labels.def, data.p.def),
		string.format(topbar, string.format("%s", data.p.line2), data.p.labels.spa, data.p.spa),
		string.format(topbar, "", data.p.labels.spd, data.p.spd),
		string.format(topbar, string.format("Heals: %.0f%% (%s)", data.x.healperc, data.x.healnum), data.p.labels.spe, data.p.spe),
		"-----------------------------",
	}

	local botheader = "%-17s %-2s  %-3s %-3s"
	local botbar = "%-17s " .. justify3 .. " " .. justify3 .. " " .. justify3
	table.insert(lines, string.format(botheader, data.m.nextmoveheader, "PP", "Pow", "Acc"))
	for i, move in ipairs(data.m.moves) do
		-- Primary move data to display
		table.insert(lines, string.format(botbar, move.name, move.pp, move.power, move.accuracy))

		-- Extra move info, unsure if wanted, can't use colors or symbols
		-- table.insert(lines, string.format(" ┗%s %s %s", move.iscontact, move.type, move.category))
	end
	table.insert(lines, "-----------------------------")
	table.insert(lines, "Badges: 1 2 3 4 5 _ 7 _")

	screen:clear()
	-- screen:moveCursor(0, 0) -- not sure when/how to use this yet
	for _, line in ipairs(lines) do
		screen:print(line)
		screen:print('\n')
	end
end

function MGBA.formatPokemonDisplayObj(data)
	data.p.name = data.p.name:upper()

	if data.p.status ~= "" then
		data.p.status = string.format("[%s]", data.p.status)
	end

	-- Format type as "Normal" or "Flying/Normal"
	if data.p.types[2] ~= data.p.types[1] and data.p.types[2] ~= nil then
		data.p.types = string.format("(%s/%s)", Utils.firstToUpper(data.p.types[1]), Utils.firstToUpper(data.p.types[2]))
	else
		data.p.types = Utils.firstToUpper(data.p.types[1] or Constants.BLANKLINE)
	end

	local escapeString = string.char(27) .. '[%dm'
	print(string.format(escapeString .. 'Test' .. escapeString .. ' Okay', 31, 0))
	-- print("\x1b[31mTest")
	data.p.labels = {}
	for _, statKey in ipairs(Constants.OrderedLists.STATSTAGES) do
		if statKey == data.p.positivestat then
			data.p.labels[statKey] = '\033[32m' .. statKey:upper() .. '+\033[0m'
		elseif statKey == data.p.negativestat then
			data.p.labels[statKey] = '\033[31m' .. statKey:upper() .. '-\033[0m'
		else
			data.p.labels[statKey] = statKey:upper()
		end

		if not Tracker.Data.isViewingOwn then
			local statBtn = TrackerScreen.Buttons[statKey]
			if statBtn ~= nil then
				data.p[statKey] = string.format("[%s]", Constants.STAT_STATES[statBtn.statState or 0].text)
			end
		end
	end

	for i, move in ipairs(data.m.moves) do
		move.name = move.name .. Utils.inlineIf(move.starred, "*", "")
		move.type = Utils.firstToUpper(move.type)
		move.category = Utils.inlineIf(move.category == MoveData.Categories.STATUS, "", "(" .. move.category:sub(1, 1) .. ")") -- "(P)" or "(S)"
		move.iscontact = Utils.inlineIf(move.iscontact, "@", "")
		if move.isstab then
			move.power = move.power .. "+"
		end
	end
end

function MGBA.drawChevron(x, y, width, height, thickness, direction, hasColor)
	local color = Theme.COLORS["Default text"]
	local i = 0
	if direction == "up" then
		if hasColor then
			color = Theme.COLORS["Positive text"]
		end
		y = y + height + thickness + 1
		while i < thickness do
			-- gui.drawLine(x, y - i, x + (width / 2), y - i - height, color)
			-- gui.drawLine(x + (width / 2), y - i - height, x + width, y - i, color)
			i = i + 1
		end
	elseif direction == "down" then
		if hasColor then
			color = Theme.COLORS["Negative text"]
		end
		y = y + thickness + 2
		while i < thickness do
			-- gui.drawLine(x, y + i, x + (width / 2), y + i + height, color)
			-- gui.drawLine(x + (width / 2), y + i + height, x + width, y + i, color)
			i = i + 1
		end
	end
end

-- draws chevrons bottom-up, coloring them if 'intensity' is a value beyond 'max'
-- 'intensity' ranges from -N to +N, where N is twice 'max'; negative intensity are drawn downward
function MGBA.drawChevrons(x, y, intensity, max)
	if intensity == 0 then return end

	local weight = math.abs(intensity)
	local spacing = 2

	for index = 0, max - 1, 1 do
		if weight > index then
			local hasColor = weight > max + index
			MGBA.drawChevron(x, y, 4, 2, 1, Utils.inlineIf(intensity > 0, "up", "down"), hasColor)
			y = y - spacing
		end
	end
end

function MGBA.drawMoveEffectiveness(x, y, value)
	if value == 2 then
		MGBA.drawChevron(x, y + 4, 4, 2, 1, "up", true)
	elseif value == 4 then
		MGBA.drawChevron(x, y + 4, 4, 2, 1, "up", true)
		MGBA.drawChevron(x, y + 2, 4, 2, 1, "up", true)
	elseif value == 0.5 then
		MGBA.drawChevron(x, y, 4, 2, 1, "down", true)
	elseif value == 0.25 then
		MGBA.drawChevron(x, y, 4, 2, 1, "down", true)
		MGBA.drawChevron(x, y + 2, 4, 2, 1, "down", true)
	end
end

function MGBA.drawButton(button, shadowcolor)
	if true then return end
	if button == nil or button.box == nil then return end

	-- Don't draw the button if it's currently not visible
	if button.isVisible ~= nil and not button:isVisible() then
		return
	end

	local x = button.box[1]
	local y = button.box[2]
	local width = button.box[3]
	local height = button.box[4]

	-- First draw a box if
	if button.type == Constants.ButtonTypes.FULL_BORDER or button.type == Constants.ButtonTypes.CHECKBOX or button.type == Constants.ButtonTypes.STAT_STAGE then
		local bordercolor = Utils.inlineIf(button.boxColors ~= nil, Theme.COLORS[button.boxColors[1]], Theme.COLORS["Upper box border"])
		local fillcolor = Utils.inlineIf(button.boxColors ~= nil, Theme.COLORS[button.boxColors[2]], Theme.COLORS["Upper box background"])

		-- Draw the box's shadow and the box border
		if shadowcolor ~= nil then
			gui.drawRectangle(x + 1, y + 1, width, height, shadowcolor, fillcolor)
		end
		gui.drawRectangle(x, y, width, height, bordercolor, fillcolor)
	end

	if button.type == Constants.ButtonTypes.FULL_BORDER or button.type == Constants.ButtonTypes.NO_BORDER then
		if button.text ~= nil and button.text ~= "" then
			MGBA.drawText(x + 1, y, button.text, Theme.COLORS[button.textColor], shadowcolor)
		end
	elseif button.type == Constants.ButtonTypes.CHECKBOX then
		if button.text ~= nil and button.text ~= "" then
			local textColor = Utils.inlineIf(button.disabled, "Negative text", button.textColor)
			MGBA.drawText(x + width + 1, y - 2, button.text, Theme.COLORS[textColor], shadowcolor)
		end

		-- Draw a mark if the checkbox button is toggled on
		if button.toggleState ~= nil and button.toggleState then
			local toggleColor = Utils.inlineIf(button.disabled, "Negative text", button.toggleColor)
			gui.drawLine(x + 1, y + 1, x + width - 1, y + height - 1, Theme.COLORS[toggleColor])
			gui.drawLine(x + 1, y + height - 1, x + width - 1, y + 1, Theme.COLORS[toggleColor])
		end
	elseif button.type == Constants.ButtonTypes.COLORPICKER then
		if button.themeColor ~= nil then
			local hexCodeText = string.upper(string.sub(string.format("%#x", Theme.COLORS[button.themeColor]), 5))
			-- Draw a colored circle with a black border
			gui.drawEllipse(x - 1, y, width, height, 0xFF000000, Theme.COLORS[button.themeColor])
			-- Draw the hex code to the side, and the text label for it
			MGBA.drawText(x + width + 1, y - 2, hexCodeText, Theme.COLORS[button.textColor], shadowcolor)
			MGBA.drawText(x + width + 37, y - 2, button.text, Theme.COLORS[button.textColor], shadowcolor)
		end
	elseif button.type == Constants.ButtonTypes.IMAGE then
		if button.image ~= nil then
			gui.drawImage(button.image, x, y)
		end
	elseif button.type == Constants.ButtonTypes.PIXELIMAGE then
		if button.image ~= nil then
			MGBA.drawImageAsPixels(button.image, x, y, { Theme.COLORS[button.textColor] }, shadowcolor)
		end
		if button.text ~= nil and button.text ~= "" then
			MGBA.drawText(x + width + 1, y, button.text, Theme.COLORS[button.textColor], shadowcolor)
		end
	elseif button.type == Constants.ButtonTypes.POKEMON_ICON then
		local imagePath = button:getIconPath()
		if imagePath ~= nil then
			local iconset = Options.IconSetMap[Options["Pokemon icon set"]]
			gui.drawImage(imagePath, x, y + iconset.yOffset, width, height)
		end
	elseif button.type == Constants.ButtonTypes.STAT_STAGE then
		if button.text ~= nil and button.text ~= "" then
			if button.text == Constants.STAT_STATES[2].text then
				y = y - 1 -- Move up the negative stat mark 1px
			end
			MGBA.drawText(x, y - 1, button.text, Theme.COLORS[button.textColor], shadowcolor)
		end
	end
end
