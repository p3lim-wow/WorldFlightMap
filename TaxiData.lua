---- MAP DATA CONVERSION ----

-- build a database of positions for every flight point in every continent (except Argus which
-- is already accurate). this data is from pulling flight point data from one of the subzones in
-- each continent with an accurate data set, correcting the coordinates for the continent and
-- storing them in a table
local mapData = {}

-- the mapData processing is borrowed from HereBeDragons
local vector00 = CreateVector2D(0, 0)
local vector05 = CreateVector2D(0.5, 0.5)
local function processMap(mapID)
	if(not mapID or mapData[mapID]) then
		return
	end

	local instance, topLeft = C_Map.GetWorldPosFromMapPos(mapID, vector00)
	local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, vector05)

	if(topLeft and bottomRight) then
		local top, left = topLeft:GetXY()
		local bottom, right = bottomRight:GetXY()
		bottom = top + (bottom - top) * 2
		right = left + (right - left) * 2

		mapData[mapID] = {left - right, top - bottom, left, top}
	else
		local data = C_Map.GetMapInfo(mapID)
		-- dalaran and argus missing, but argus has accurate data already
	end
end

local function processMapRecursive(mapID)
	processMap(mapID)

	local children = C_Map.GetMapChildrenInfo(mapID)
	if(children and #children > 0) then
		for index = 1, #children do
			processMapRecursive(children[index].mapID)
		end
	end
end

local oobPosition = CreateVector2D(-1, -1) -- we use this to return a bogus vector instead of nil
local function GetWorldCoordinatesFromZone(position, mapID)
	local data = mapData[mapID]
	if(not data or data[1] == 0 or data[2] == 0) then
		return oobPosition
	end

	local x, y = position:GetXY()
	if(not x or not y) then
		return oobPosition
	end

	local width, height, left, top = data[1], data[2], data[3], data[4]
	x, y = left - width * x, top - height * y

	return x, y
end

local function GetZoneCoordinatesFromWorld(x, y, mapID)
	local data = mapData[mapID]
	if(not data or data[1] == 0 or data[2] == 0) then
		return nil, nil
	elseif(not x or not y) then
		return nil, nil
	end

	local width, height, left, top = data[1], data[2], data[3], data[4]
	x, y = (left - x) / width, (top - y) / height

	return CreateVector2D(x, y)
end

--[[ global ]] function TranslateZoneCoordinates(position, srcMapID, destMapID)
	if(srcMapID == destMapID) then
		return position
	end

	local x, y = GetWorldCoordinatesFromZone(position, srcMapID)
	if(not x) then
		return oobPosition
	end

	local data = mapData[destMapID]
	if(not data) then
		return oobPosition
	end

	return GetZoneCoordinatesFromWorld(x, y, destMapID)
end

local taxiPositions = {}
for continentMapID, zoneMapID in next, {
	-- any zone could have been used, I just picked some that were centered-ish
	[12] = 1, -- Kalimdor = Durotar
	[13] = 27, -- Eastern Kingdoms = Dun Morogh
	[101] = 100, -- Outland = Hellfire Peninsula
	[113] = 127, -- Northrend = Crystalsong Forest
	[424] = 390, -- Pandaria = Vale of Eternal Blossom
	[572] = 535, -- Draenor = Talador
	[619] = 680, -- Broken Isles = Suramar
	[905] = 882, -- Argus = Mac'Aree
} do
	-- process the continent for map data first
	processMapRecursive(continentMapID)

	if(not taxiPositions[continentMapID]) then
		taxiPositions[continentMapID] = {}
	end

	-- iterate through all the taxi nodes on the zone map
	local nodes = C_TaxiMap.GetTaxiNodesForMap(zoneMapID)
	for _, info in next, nodes do
		-- convert the zone map position into continent position and store it
		local pos = TranslateZoneCoordinates(info.position, zoneMapID, continentMapID)
		-- print('pos', pos and pos:GetXY())
		taxiPositions[continentMapID][info.nodeID] = pos
	end
end

--[[ global ]] function GetTaxiNodePosition(continentMapID, nodeID)
	return taxiPositions[continentMapID] and taxiPositions[continentMapID][nodeID]
end
