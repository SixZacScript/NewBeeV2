local TokenHelper = {}

function TokenHelper:getAllToken()
   return {
        -- TIER 1: ULTRA RARE (Priority 100) - Extremely valuable items
        ["💎 Diamond Egg"] = {id = 1471850677, isSkill = false, Priority = 100},
        ["⭐ Starjelly"] = {id = 2319943273, isSkill = false, Priority = 100},
        ["🥇 Gold Egg"] = {id = 1471849394, isSkill = false, Priority = 95},
        ["🌱 Sprout"] = {id = 2529092020, isSkill = false, Priority = 90},
        ["🕯️ Hard wax"] = {id = 8277780065, isSkill = false, Priority = 90},

        -- TIER 2: HIGH VALUE CONSUMABLES (Priority 80-90)
        ["🌙 Moon Charm"] = {id = 2306224708, isSkill = false, Priority = 89},
        ["🛢️ Oil"] = {id = 2545746569, isSkill = false, Priority = 89},
        ["✨ Glitter"] = {id = 2542899798, isSkill = false, Priority = 89},
        ["🧪 Glue"] = {id = 2504978518, isSkill = false, Priority = 89},
        ["🎲 Dice 3"] = {id = 8055428094, isSkill = false, Priority = 89},
        ["🎫 Ticket"] = {id = 1674871631, isSkill = false, Priority = 85},
        ["🫐 Neon berry"] = {id = 4483267595, isSkill = false, Priority = 85},
        ["🔷 Blue Extract"] = {id = 2495936060, isSkill = false, Priority = 80},
        ["🔴 Red Extract"] = {id = 2495935291, isSkill = false, Priority = 80},
        ["🎲 Dice 1"] = {id = 2863468407, isSkill = false, Priority = 80},
        ["🧻 Soft Wax"] = {id = 8277778300, isSkill = false, Priority = 80},
        ["⭐ Star"] = {id = 2000457501, isSkill = true, Priority = 80},
        ["🌵 Spike"] = {id = 2314214749, isSkill = false, Priority = 80},
        ["🥚 Silver Egg"] = {id = 1471848094, isSkill = false, Priority = 80},

        -- TIER 3: POWERFUL BOOSTS & SYNCS (Priority 70-75)
        ["🔗 Link Token"] = {id = 1629547638, isSkill = true, Priority = 75},
        ["❤️ Baby Love"] = {id = 1472256444, isSkill = true, Priority = 74},
        ["😾 Tabby Love"] = {id = 1753904617, isSkill = true, Priority = 74},
        ["💣+ Buzz Bomb Plus"] = {id = 1442764904, isSkill = true, Priority = 70},
        ["🔗 Blue Sync"] = {id = 1874692303, isSkill = true, Priority = 70},
        ["🔗 Red Sync"] = {id = 1874704640, isSkill = true, Priority = 70},
        ["🎯 Scracth"] = {id = 1104415222, isSkill = true, Priority = 70},
        ["🎵 Melody"] = {id = 253828517, isSkill = true, Priority = 70},
   

        -- TIER 4: STRONG BOOSTS (Priority 60-65)
        ["🟥 Red Boost"] = {id = 1442859163, isSkill = true, Priority = 65},
        ["🟦 Blue Boost"] = {id = 1442863423, isSkill = true, Priority = 65},
        ["⬜ White Boost"] = {id = 3877732821, isSkill = true, Priority = 65},
        ["🎲 Dice 2"] = {id = 8054996680, isSkill = false, Priority = 65},
        ["💣 Buzz Bomb"] = {id = 1442725244, isSkill = true, Priority = 64},
        ["💥 Pulse"] = {id = 1874564120, isSkill = true, Priority = 63},
        ["👁️ Focus"] = {id = 1629649299, isSkill = true, Priority = 60},
        ["🫒 Bitter berry"] = {id = 4483236276, isSkill = false, Priority = 60},
       

        -- TIER 5: UTILITY ITEMS (Priority 50-55)
        ["🔶 bbm1"] = {id = 2652364563, isSkill = true, Priority = 55},
        ["🔶 Bee Bear Token"] = {id = 2652424740, isSkill = true, Priority = 55},
        ["🔶 Pollen Mark"] = {id = 2499540966, isSkill = true, Priority = 55},
        ["🔶 Honey Mark"] = {id = 2499514197, isSkill = true, Priority = 55},
        ["🦮 Honey Suckle"] = {id = 8277901755, isSkill = false, Priority = 50},
        ["🐜 Antpass"] = {id = 2060626811, isSkill = false, Priority = 50},
        ["📯 Broken Drive"] = {id = 13369738621, isSkill = false, Priority = 50},

        -- TIER 6: MEDIUM VALUE ITEMS (Priority 40-45)
        ["☁️ Cloud Vial"] = {id = 3030569073, isSkill = false, Priority = 45},
        ["🔄 Micro Converter"] = {id = 2863122826, isSkill = false, Priority = 45},
        ["🤖 Robot Pass"] = {id = 3036899811, isSkill = false, Priority = 40},
        ["💧 Gumdrops"] = {id = 1838129169, isSkill = false, Priority = 40},
        ["🥥 Coconut"] = {id = 3012679515, isSkill = false, Priority = 40},

        -- TIER 7: FOOD & TREATS (Priority 30-35)
        ["🍍 Pineapple Candy"] = {id = 2584584968, isSkill = false, Priority = 35},
        ["🔵 Blue Berry"] = {id = 2028453802, isSkill = false, Priority = 30},
        ["🎈 Red Balloon"] = {id = 8058047989, isSkill = false, Priority = 30},
        ["🫘 Jellybean 1"] = {id = 3080529618, isSkill = false, Priority = 30},
        ["🫘 Jellybean 2"] = {id = 3080740120, isSkill = false, Priority = 30},
        ["🦋 Whirligig"] = {id = 8277898895, isSkill = false, Priority = 30},

        -- TIER 8: BASIC RESOURCES (Priority 20-25)
        ["🌻 Sunflowerseed"] = {id = 1952682401, isSkill = false, Priority = 25},
        ["🍍 Pineapple"] = {id = 1952796032, isSkill = false, Priority = 25},
        ["🍓 Strawberry"] = {id = 1952740625, isSkill = false, Priority = 25},
        ["🫙 Royal Jelly"] = {id = 1471882621, isSkill = false, Priority = 20},
        
        -- TIER 9: LOW PRIORITY (Priority 10-15)
        ["😡 Rage"] = {id = 1442700745, isSkill = true, Priority = 1},
        ["⚡ Speed"] = {id = 65867881, isSkill = true, Priority = 1},
        ["🍬 Treat"] = {id = 2028574353, isSkill = false, Priority = 1},
        ["🍯 Honey"] = {id = 1472135114, isSkill = false, Priority = 1},
    }
end
function TokenHelper:getPriorityById(searchId)
    for _, data in pairs(self:getAllToken()) do
        if data.id == searchId then
            return data.Priority
        end
    end
    return 1
end

function TokenHelper:getTokenById(searchId)
    for name, data in pairs(self:getAllToken()) do
        if data.id == searchId then
            data['Name'] = name
            return name, data
        end
    end

    if not self.unknownTokenIds then
        self.unknownTokenIds = {}
    end

    if not table.find(self.unknownTokenIds, searchId) then
        table.insert(self.unknownTokenIds, searchId)

        local HttpService = game:GetService("HttpService")
        local filename = "UnknownTokens.json"
        local content = ""

        if isfile(filename) then
            local oldData = HttpService:JSONDecode(readfile(filename))
            for _, v in ipairs(oldData) do
                if not table.find(self.unknownTokenIds, v) then
                    table.insert(self.unknownTokenIds, v)
                end
            end
        end

        content = HttpService:JSONEncode(self.unknownTokenIds)
        writefile(filename, content)
    end

    return "Unknown", { id = searchId, isSkill = false, Priority = 1, Name = "Unknown" }
end


local numberName = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dd", "Ud", "Dd", "Td", "Qad", "Qid", 
	"Sxd", "Spd", "Ocd", "Nod", "Vg", "Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg"}
local pows = {}
for i = 1, #numberName do table.insert(pows, 1000^i) end

function TokenHelper:formatNumber(x: number, decimal: number?): string
	local numberName = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
	local pows = {}
	for i = 1, #numberName do
		pows[i] = 10 ^ (i * 3)
	end

	local ab = math.abs(x)
	if ab < 1000 then
		if not decimal or decimal <= 0 then
			return tostring(math.floor(x))
		else
			return string.format("%." .. decimal .. "f", x)
		end
	end

	local p = math.min(math.floor(math.log10(ab) / 3), #numberName)
	local base = ab / pows[p]

	local formatted
	if not decimal or decimal <= 0 then
		formatted = tostring(math.floor(base))
	else
		formatted = string.format("%." .. decimal .. "f", base)
	end

	return (x < 0 and "-" or "") .. formatted .. numberName[p]
end


return TokenHelper
