---- DATA PROVIDER ----
-- partly ripped off FlightMap_FlightPathDataProviderMixin

local WorldFlightMapProvider = CreateFromMixins(FlightPointDataProviderMixin)
function WorldFlightMapProvider:OnAdded(...)
	MapCanvasDataProviderMixin.OnAdded(self, ...)

	UIParent:UnregisterEvent('TAXIMAP_OPENED')
	TaxiFrame:UnregisterAllEvents()

	self:RegisterEvent('TAXIMAP_OPENED')
	self:RegisterEvent('TAXIMAP_CLOSED')
end

function WorldFlightMapProvider:OnEvent(event, ...)
	if(event == 'TAXIMAP_OPENED') then
		local continentMapID = self:GetContinentForMapID(C_Map.GetBestMapForUnit('player'))
		self:SetTaxiMapID(continentMapID)
		-- OpenWorldMap(continentMapID)

		if(not self:GetMap():IsShown()) then
			ToggleWorldMap()
		end

		self:SetTaxiState(true)
		self:RefreshAllData()
	elseif(event == 'TAXIMAP_CLOSED') then
		self:SetTaxiState(false)

		CloseTaxiMap()
		if(self:GetMap():IsShown()) then
			ToggleWorldMap()
		end

		self:RemoveAllData()
	end
end

function WorldFlightMapProvider:OnHide()
	if(self:IsTaxiOpen()) then
		CloseTaxiMap()
	end
end

function WorldFlightMapProvider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate('WorldFlightMapPinTemplate')
end

function WorldFlightMapProvider:RefreshAllData()
	self:RemoveAllData()

	if(not self.slotIndexToPin) then
		self.slotIndexToPin = {}
	else
		table.wipe(self.slotIndexToPin)
	end

	if(self:IsTaxiOpen()) then
		local Map = self:GetMap()

		local mapID = Map:GetMapID()
		local taxiMapID = self:GetTaxiMapID()
		local taxiNodes = C_TaxiMap.GetAllTaxiNodes()
		for _, info in next, taxiNodes do
			-- TODO: this shit is messed up for Argus
			-- get "accurate" node positions
			local pos = GetTaxiNodePosition(taxiMapID, info.nodeID) or info.position
			-- replace the position for the current map instead
			local zonePos = TranslateZoneCoordinates(pos, taxiMapID, mapID)
			info.position = zonePos or pos
			Map:AcquirePin('WorldFlightMapPinTemplate', self, info)
		end
	end
end

function WorldFlightMapProvider:IsTaxiOpen()
	return self.taxiOpen
end

function WorldFlightMapProvider:SetTaxiState(state)
	self.taxiOpen = state
end

function WorldFlightMapProvider:SetTaxiMapID(mapID)
	self.taxiMapID = mapID
end

function WorldFlightMapProvider:GetTaxiMapID()
	return self.taxiMapID
end

function WorldFlightMapProvider:IsOnArgus()
	return self:GetTaxiMapID() == 905
end

function WorldFlightMapProvider:GetContinentForMapID(mapID)
	local continent = MapUtil.GetMapParentInfo(mapID, Enum.UIMapType.Continent)
	return continent and continent.mapID
end

function WorldFlightMapProvider:HighlightRouteToPin(Pin)
	if(not self.linePool) then
		self.linePool = CreateLinePool(Pin, 'BACKGROUND') -- attach to the pin so it gets drawn on top
	end

	local taxiSlotIndex = Pin:GetID()
	for routeIndex = 1, GetNumRoutes(taxiSlotIndex) do
		local sourceIndex = TaxiGetNodeSlot(taxiSlotIndex, routeIndex, true)
		local destIndex = TaxiGetNodeSlot(taxiSlotIndex, routeIndex, false)

		local startPin = self.slotIndexToPin[sourceIndex]
		local destPin = self.slotIndexToPin[destIndex]

		local Line = self.linePool:Acquire()
		Line:SetNonBlocking(true)
		Line:SetAtlas('_UI-Taxi-Line-horizontal')
		Line:SetThickness(32)
		Line:SetStartPoint('CENTER', startPin)
		Line:SetEndPoint('CENTER', destPin)
		Line:Show()

		-- force show all the pins in the route
		startPin:Show()
		destPin:Show()
	end
end

function WorldFlightMapProvider:RemoveRouteToPin(Pin)
	if(self.linePool) then
		self.linePool:ReleaseAll()
	end

	for _, Pin in next, self.slotIndexToPin do
		-- update visibility
		Pin:UpdateState()
	end
end

WorldMapFrame:AddDataProvider(WorldFlightMapProvider)
