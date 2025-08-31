_addon.name = 'NyzulBestBuddy'
_addon.author = 'LordAttilas'
_addon.version = '2.0'
_addon.commands = {'NyzulBestBuddy','nbb'}
_addon.language = 'english'

packets = require('packets')
config = require('config')
texts = require('texts')
-- create default settings file for textbox

default_settings = {}
default_settings.pos = {}
default_settings.pos.x = 144
default_settings.pos.y = 144
default_settings.text = {}
default_settings.text.font = 'Segoe UI'
default_settings.text.size = 12
default_settings.text.alpha = 255
default_settings.text.red = 188
default_settings.text.green = 131
default_settings.text.blue = 246
default_settings.bg = {}
default_settings.bg.alpha = 175
default_settings.bg.red = 050
default_settings.bg.green = 050
default_settings.bg.blue = 050
settings = config.load('data\\settings.xml',default_settings)

--lamps table

sortedIndexes = { 0x2D2, 0x2D3, 0x2D4, 0x2D5, 0x2D6, 0x2D7, 0x2D8 }
sortedLampIndexes = { 0x2D4, 0x2D5, 0x2D6, 0x2D7, 0x2D8 }

tLamps = {
	[0x2D4] = {}, --Lamp1
	[0x2D5] = {}, --Lamp2
	[0x2D6] = {}, --Lamp3
	[0x2D7] = {}, --Lamp4
	[0x2D8] = {}, --Lamp5
	[0x2D2] = {}, --RoT1
	[0x2D3] = {}, --RoT2
}

tLampIndexes = {
	[0x2D4] = 1,
	[0x2D5] = 2,
	[0x2D6] = 3,
	[0x2D7] = 4,
	[0x2D8] = 5,
}

tLampOrder = {
	[0x2D4] = 0,
	[0x2D5] = 0,
	[0x2D6] = 0,
	[0x2D7] = 0,
	[0x2D8] = 0,
}


eventClock = nil
clock = os.clock()
scanClock = os.clock()
text_box = texts.new(settings)

running = true
debugmode = false
needLampScan = false
lastZone = 0
lastPlayerX = 9999
lastPlayerY = 9999
lampCount = 0
lampSequences = {}
lampFloorDetected = false
currentZone = 0
currentFloorRuneFilter = 0
objectiveCompleted = false

--Convert direction to a visual cue
function directionArrow(decimal)
	local index = math.ceil(math.fmod(decimal+22.5,360) / 45)

	if index == 1 then
		return '↑'--utf8Char(8593)
	elseif index == 2 then
		return "↑→"--utf8Char(8599)
	elseif index == 3 then
		return "→"--utf8Char(8594)
	elseif index == 4 then
		return "↓→"--utf8Char(8600)
	elseif index == 5 then
		return "↓"--utf8Char(8695)
	elseif index == 6 then
		return "←↓"--utf8Char(8601)
	elseif index == 7 then
		return "←"--utf8Char(8592)
	elseif index == 8 then
		return "←↑"--utf8Char(8598)
	end
	return ""
end


--Run packet injection/force update from server on NPC
function Update()

	for k,v in pairs(tLamps) do
		local p = packets.new('outgoing', 0x016, {
			["Target Index"] = k
		})
		packets.inject(p)

	end

end

--Remove lamps object between floor or at exit
function ResetLamps()
	ResetSequences()
	needLampScan = false
	currentFloorRuneFilter = 0
	objectiveCompleted = false
	lampFloorDetected = false

	for k,v in pairs(tLamps) do
		tLamps[k] = {}
	end
end

function ResetSequences()
	lampSequences = {}
	for k,v in pairs(tLampOrder) do
		tLampOrder[k] = 0
	end
end

  
--Handles commands
windower.register_event('addon command', function(...)

	local arg = {...}
	if #arg > 3 then
		windower.add_to_chat(167, 'Invalid command. //nbb help for valid options.')

	elseif #arg == 1 and arg[1]:lower() == 'start' then
		if running == false then
			running = true
			windower.add_to_chat(200, 'NyzulBestBuddy starting')
		else
			windower.add_to_chat(200, 'NyzulBestBuddy is already running.')
		end

	elseif #arg == 1 and arg[1]:lower() == 'stop' then
		if running == true then
			running = false
			text_box:visible(false)
			windower.add_to_chat(200, 'NyzulBestBuddy stopping')
		else
			windower.add_to_chat(200, 'NyzulBestBuddy is not running.')
		end
		
	elseif #arg >= 1 and arg[1]:lower() == 'set' then
		
		local lampIndex = nil
		
		--Find lamp index
		if #arg == 1 then
			--Lamp based on target
			local player = windower.ffxi.get_player()
			local targetIndex = player.target_index
			if targetIndex ~= nil then
				target = windower.ffxi.get_mob_by_index(targetIndex)
				if target ~= nil and target.name == "Runic Lamp" then
					lampIndex = targetIndex
				end
			end
		else
			--Manual lamp specified
			local lampAssignement = arg[2]:lower()
			if lampAssignement == 'a' then
				lampIndex = 0x2D4
			elseif lampAssignement == 'b' then
				lampIndex = 0x2D5
			elseif lampAssignement == 'c' then
				lampIndex = 0x2D6
			elseif lampAssignement == 'd' then
				lampIndex = 0x2D7
			elseif lampAssignement == 'e' then
				lampIndex = 0x2D8
			end
		end
		
		if lampIndex ~= nil then
			local lampPosition = 0
			
			if #arg >= 3 then
				lampPosition = tonumber(arg[3])
			else
				for i = #lampSequences,1, -1 do
					local sequenceLampIndex = lampSequences[i]
					local rowItemIndex = math.fmod(i-1,lampCount)+1
					
					if lampIndex == sequenceLampIndex then
						lampPosition = rowItemIndex
						break
					end
					
				end
			end

			if lampPosition < 0 or lampPosition > lampCount then
				windower.add_to_chat(200, 'NyzulBestBuddy - Invalid lamp position #'..lampPosition..' (0 - Disable or 1 to '..lampCount..')')
			else
				if tLampOrder[lampIndex] > 0 and tLampOrder[lampIndex] == lampPosition then
					windower.add_to_chat(200, 'NyzulBestBuddy - Lamp '..GetLampAssignement(lampIndex)..' position reset')
					tLampOrder[lampIndex] = 0
				else
					windower.add_to_chat(200, 'NyzulBestBuddy - Lamp '..GetLampAssignement(lampIndex)..' confirmed at position #'..lampPosition)
					tLampOrder[lampIndex] = lampPosition
				end
				
			end
		else
			windower.add_to_chat(200, 'NyzulBestBuddy - Invalid target to set lamp order')
		end
		
	elseif #arg == 2 and arg[1]:lower() == 'insert' then
		local lampAssignement = arg[2]:lower()
		if lampAssignement == 'a' then
			lampSequences[#lampSequences+1] = sortedLampIndexes[1]
		elseif lampAssignement == 'b' then
			lampSequences[#lampSequences+1] = sortedLampIndexes[2]
		elseif lampAssignement == 'c' then
			lampSequences[#lampSequences+1] = sortedLampIndexes[3]
		elseif lampAssignement == 'd' then
			lampSequences[#lampSequences+1] = sortedLampIndexes[4]
		elseif lampAssignement == 'e' then
			lampSequences[#lampSequences+1] = sortedLampIndexes[5]
		end
	
	elseif #arg == 1 and arg[1]:lower() == 'remove' then	
		table.remove(lampSequences)
	
	elseif #arg == 1 and arg[1]:lower() == 'clear' then
		ResetSequences()

	elseif #arg == 1 and arg[1]:lower() == 'debug' then
		if debugmode == true then
			debugmode = false
			windower.add_to_chat(200, 'NyzulBestBuddy stoping debug mode')
			text_box:visible(false)
		else
			debugmode = true
			windower.add_to_chat(200, 'NyzulBestBuddy starting debug mode.')
		end

	elseif #arg == 1 and arg[1]:lower() == 'help' then
		windower.add_to_chat(200, 'Available Options:')
		windower.add_to_chat(200, '  //nbb start - Turns on NyzulBestBuddy and starts sending lamp packets on lamp floor')
		windower.add_to_chat(200, '  //nbb stop - Turns off NyzulBestBuddy')
		windower.add_to_chat(200, '  //nbb set [a-e] [pos] - Set lamp [Target] to correct position [Last sequence]')
		windower.add_to_chat(200, '  //nbb insert a-e - Insert light sequence manually')
		windower.add_to_chat(200, '  //nbb remove - Remove last light sequence manually')
		windower.add_to_chat(200, '  //nbb clear - Clear sequences and correct positions')
		windower.add_to_chat(200, '  //nbb debug - Turns debug mode')
		windower.add_to_chat(200, '  //nbb help - Displays this text')
	end
end)


--Register and parse incoming 0x0E for relevant data
windower.register_event("incoming chunk", function(id, data)
	if id == 0x0E  then

        local packet     = packets.parse('incoming', data)
		local mob_index  = packet["Index"]

		for k,v in pairs(tLamps) do
			if mob_index == k then
				mob = windower.ffxi.get_mob_by_index(mob_index)
				if mob ~= nil then
					if mob.name == "Runic Lamp" or mob.name == "Rune of Transfer" then
						tLamps[k] = mob
					end
				end
			end
		end
	end
end)


function HideDisplay()
	if not debugmode then
		text_box:visible(false)
		text_box:text("")
	end
end

function ComputeDistance(playerpos, target)
	return math.sqrt(math.pow(target.x - playerpos.x,2) + math.pow(target.y - playerpos.y,2))
end

function ComputeRelativeDirection(playerpos, target)
	local vectorX = (target.x - playerpos.x)
	local vectorY = (target.y - playerpos.y)
	local quatranCorection = 0
	if vectorX < 0 then
		quatranCorection = 180
	elseif vectorY < 0 then
		quatranCorection = 360
	end
	local playerdirection = math.fmod((playerpos.facing*180/3.1413)+450,360)
	local direction = math.fmod(360 - (math.deg(math.atan((target.y - playerpos.y)/(target.x - playerpos.x))) + quatranCorection) + 90,360)
	return math.fmod(direction - playerdirection + 360,360)
end

function GetLampAssignement(targetIndex)
	return string.char(64+tLampIndexes[targetIndex])
end

function Display()
	
	new_text = ""

	local player = windower.ffxi.get_player()
	local playerpos = windower.ffxi.get_mob_by_index(player.index)
	local lampCountCheck = 0

	--Run timer
	if eventClock ~= nil then
		local remainingMinutes = 30-(math.round(((os.clock()- eventClock)/60),0))
		new_text = new_text .."Timer - "
		if remainingMinutes <= 5 then
			new_text = new_text .."\\cs(255,0,0)"
		elseif remainingMinutes <= 8 then
			new_text = new_text .."\\cs(255,255,0)"
		else
			new_text = new_text .."\\cs(200,200,200)"
		end
		new_text = new_text..remainingMinutes.." min(s)\\cr\n"
	end

	--Detect current floor Rune
	if currentFloorRuneFilter == 0 and tLamps[0x2D2].id ~= nil and tLamps[0x2D3].id ~= nil then
		local rune1 = tLamps[0x2D2]
		local rune2 = tLamps[0x2D3]
		if rune1.id ~= nil and rune2.id ~= nil then
			local distance1 = ComputeDistance(playerpos,rune1)
			local distance2 = ComputeDistance(playerpos,rune2)
			if distance1 < distance2 then
				currentFloorRuneFilter = rune2.index
			else
				currentFloorRuneFilter = rune1.index
			end
		end
	end

	--Display Lamps
	for i = 1,7 do
		local target = tLamps[sortedIndexes[i]]
		
		if target.id ~= nil then
			local distance = ComputeDistance(playerpos,target)
			--Lamp at 0-0 are not used.
			if not(target.x==0 and target.y==0) and distance < 300 and target.index ~= currentFloorRuneFilter then
				local isRunicLamp = target.name == "Runic Lamp"
				
				if not isRunicLamp or lampFloorDetected then
					local relativeDirection = ComputeRelativeDirection(playerpos,target)
					new_text = new_text .. target.name
					if isRunicLamp then
						new_text = new_text.." "..GetLampAssignement(target.index)
						lampCountCheck = lampCountCheck + 1
					end
					if debugmode then
						new_text = new_text .. " ID: [" .. (target.index) .. "]"
					end 
					new_text = new_text .. " - \\cs(200,200,200)".. math.round(distance,0) .. " Yalms\\cr \\cs(255,255,255)" .. directionArrow(relativeDirection) .."\\cr \n"
				end
			end
		end
	end	
	
	if #lampSequences > 0 and debugmode and lampCountCheck == 0 then	
		lampCountCheck = 3
	end
	
	if lampCount ~= lampCountCheck then
		if debugmode then
			windower.add_to_chat(200, "NyzulBestBuddy Debug - Lamp quantity changed to "..lampCountCheck..".")
		end
		lampCount = lampCountCheck
	end
	
	--Display current lamp Sequences
	if #lampSequences > 0 then	
		
		for i = 1, #lampSequences do
			local lampIndex = lampSequences[i]
			
			local rowItemIndex = math.fmod(i-1,lampCount)+1
			local lampAssignement = GetLampAssignement(lampIndex)
			local correctLampPosition = tLampOrder[lampIndex]
			
			if i > 1 then
				if rowItemIndex == 1 then
					new_text = new_text.."\n"
				else
					new_text = new_text.."\\cs(200,200,200)->\\cr"
				end
			end
			if rowItemIndex == correctLampPosition then
				new_text = new_text.."\\cs(0,255,0)"..lampAssignement.."\\cr"
			else
				new_text = new_text.."\\cs(200,200,200)"..lampAssignement.."\\cr"
			end
			
		end
	end

	--General informations
	if debugmode then
		local info = windower.ffxi.get_info()
			
		new_text = new_text .. "\n"..player.name .. " status:" .. player.status .. " x:"..math.round(playerpos.x,2) .. " y:"..math.round(playerpos.y,2).." z:"..math.round(playerpos.z,2)
		new_text = new_text .. "\nZone: " .. info.zone .." ("..(currentZone)..")"
		new_text = new_text .. "\nLampCount: "..lampCount.." LampOrder: "..tLampOrder[0x2D4].." "..tLampOrder[0x2D5].." "..tLampOrder[0x2D6].." "..tLampOrder[0x2D7].." "..tLampOrder[0x2D8]
	end
	
	--Target informations
	local index = player.target_index
	if index ~= nil then		
		target = windower.ffxi.get_mob_by_index(index)

		if target ~= nil then
			if target.name == "Runic Lamp" then
				local nextRowItemOrder = math.fmod(#lampSequences,lampCount)+1
				local lampOrder = tLampOrder[target.index]
				if lampOrder == 0 then
					--Check if other lamp is marked at this posistion
					local foundOtherLampAtThisIndex = false
					for i = 1, #tLampOrder do
						local otherLampOrder = tLampOrder[tLampIndexes[i]]
						if otherLampOrder == nextRowItemOrder then
							foundOtherLampAtThisIndex = true
						end
					end
					if foundOtherLampAtThisIndex then
						--Display warning or current lamp is about to be set in the order of another confirmed lamp
						new_text = new_text.."\n"..target.name.." [\\cs(255,0,0)"..GetLampAssignement(target.index).."\\cr]"
					else
						--Display regular color of nothing related to this lamp order
						new_text = new_text.."\n"..target.name.." ["..GetLampAssignement(target.index).."]"
					end
				elseif lampOrder == nextRowItemOrder then
					--Display correct order for this lamp if already set
					new_text = new_text.."\n"..target.name.." [\\cs(0,255,0)"..GetLampAssignement(target.index).."\\cr]"
				else
					--Display warning or current lamp is about to be set in wrong order
					new_text = new_text.."\n"..target.name.." [\\cs(255,0,0)"..GetLampAssignement(target.index).."\\cr]"
				end
			end
			
			if debugmode then
				local distance = ComputeDistance(playerpos,target)
				local relativeDirection = ComputeRelativeDirection(playerpos,target)
				if target.name == "Runic Lamp" then
					new_text = new_text.."["..GetLampAssignement(target.index).."] "
				end
				new_text = new_text .. "\n" .. target.name .. " x:"..math.round(target.x,2) .. " y:"..math.round(target.y,2).." z:"..math.round(target.z,2)
				new_text = new_text .. "\n" .. "Index:" .. target.index .. " status:" .. target.status .. " entity_type:" .. target.entity_type .. " spawn_type:" .. target.spawn_type
				new_text = new_text .. "\n" .. "Distance:"..math.round(distance,1) .. " Direction:"..math.round(relativeDirection,1) .. " " .. directionArrow(relativeDirection) 
			end
		end
	elseif debugmode then
		new_text = new_text .. "\n\nNo target"
	end
	
	if objectiveCompleted then
		new_text = new_text .. "\n\\cs(0,255,0)Floor objective completed !!!\\cr"
	end

	text_box:text(new_text)
	text_box:visible(string.len(new_text) > 0)

end


--Detect Lamp Action
windower.register_event("status change", function(new,old)
	--This status change occur only when a "Activate lamp Yes No" menu appear. Do not occur for lamp that get activated on touch.
	if running and new == 4 and currentZone == 77 then
		LampAction()
	end
end)


windower.register_event("zone change", function(new_id,old_id)
	currentZone = new_id
end)


windower.register_event("incoming text", function(original,modified,original_mode,modified_mode,blocked)
	if running == true and currentZone == 77 then
		if string.match(original,'Objective:') and string.match(original,'lamps') then
			windower.add_to_chat(200, 'NyzulBestBuddy - Lamp floor detected...')
			lampFloorDetected = true
			--Request a delayed lamp scan
			needLampScan = true
			scanClock = os.clock()
		elseif string.match(original,'Rune of Transfer activated.') then
			objectiveCompleted = true
			if debugmode then
				windower.add_to_chat(200, 'NyzulBestBuddy - Floor objective completed !!!')
			end
		end
	end
end)

--Building the order of discovery sequence of lamps
function LampAction()
	local target = windower.ffxi.get_mob_by_target('t')
    
	if target ~= nil and target.name == "Runic Lamp" then
		local lampAssignement = GetLampAssignement(target.index)
		windower.add_to_chat(200, "NyzulBestBuddy Debug - Runic Lamp ["..lampAssignement.."] interaction.")
		lampSequences[#lampSequences+1] = target.index
	end
end


--Main loop
windower.register_event('prerender', function()
	
	if running == true and os.clock() - clock > 1 then
		
		--Force reload of zone if plugin reloaded while in the zone already
		if currentZone == 0 then
			local info = windower.ffxi.get_info()
			currentZone = info.zone
		end

		if lastZone ~= currentZone then

			if currentZone == 77 then
				if debugmode then
					windower.add_to_chat(200, "NyzulBestBuddy Debug - Nyzul Isle Investigation enter detected...")
				end
				eventClock = os.clock()
			elseif lastZone == 77 then
				if debugmode then
					windower.add_to_chat(200, "NyzulBestBuddy Debug - Nyzul Isle Investigation exit detected...")
				end
				ResetLamps()
				HideDisplay()
				eventClock = nil
			end
			lastZone = currentZone
		end
		
		if currentZone == 77 or debugmode then
			local player = windower.ffxi.get_player()
			local playerpos = windower.ffxi.get_mob_by_index(player.index)
			
			if playerpos ~= nil then
				--Warping inside the zone 77 equal a floor change even if we don't really move up between each floors.
				if math.abs(lastPlayerX - playerpos.x) > 10 or math.abs(lastPlayerY - playerpos.y) > 10 then
					ResetLamps()
					if currentZone == 77 then
						if debugmode then
							windower.add_to_chat(200, "NyzulBestBuddy Debug - Nyzul Isle Investigation map changed...")								
						end
					end
				end
	
				--Wait 5 seconds before scanning lamps on new maps
				if needLampScan and os.clock() - scanClock > 5 then
					if debugmode then
						windower.add_to_chat(200, "NyzulBestBuddy - Scanning for lamps...")								
					end
					needLampScan = false
					Update()
				end
	
				lastPlayerX = playerpos.x
				lastPlayerY = playerpos.y

				Display()
			end

		end

		clock = os.clock()

	end
		
end)

  
