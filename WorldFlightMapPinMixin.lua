---- PIN MIXIN ----
-- partly ripped off FlightMap_FlightPointPinMixin

WorldFlightMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
function WorldFlightMapPinMixin:OnAcquired(dataProvider, taxiNodeInfo)
	dataProvider.slotIndexToPin[taxiNodeInfo.slotIndex] = self

	self.dataProvider = dataProvider
	self.name = taxiNodeInfo.name
	self.state = taxiNodeInfo.state
	self.textureKitPrefix = taxiNodeInfo.textureKitPrefix

	self:SetID(taxiNodeInfo.slotIndex)
	self:SetPosition(taxiNodeInfo.position:GetXY())

	self:UpdateState()
	self:UpdateStyle()
	self:UpdateSize()
end

local function IsVindicaarTextureKit(textureKitPrefix)
	if(textureKitPrefix) then
		return not not textureKitPrefix:match('FlightMaster_Vindicaar')
	end
end

function WorldFlightMapPinMixin:OnClick(button)
	if(button == 'LeftButton') then
		TakeTaxiNode(self:GetID())
	end
end

function WorldFlightMapPinMixin:OnMouseEnter()
	local taxiSlotIndex = self:GetID()

	WorldMapTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	WorldMapTooltip:AddLine(self.name, nil, nil, nil, true)

	SetCursor('TAXI_CURSOR')

	if(self.state == Enum.FlightPathState.Current) then
		WorldMapTooltip:AddLine(TAXINODEYOUAREHERE, 1, 1, 1, true)
	elseif(self.state == Enum.FlightPathState.Reachable) then
		if(self.dataProvider:IsOnArgus()) then
			-- Argus travels are free and disconnected
		else
			local travelCost = TaxiNodeCost(taxiSlotIndex)
			if(cost ~= 0) then
				SetTooltipMoney(WorldMapTooltip, travelCost)
			end

			self.dataProvider:HighlightRouteToPin(self)
		end
	elseif(self.state == Enum.FlightPathState.Unreachable) then
		local r, g, b = RED_FONT_COLOR:GetRGB()
		WorldMapTooltip:AddLine(TAXI_PATH_UNREACHABLE, r, g, b, true)
	end

	WorldMapTooltip:Show()
end

function WorldFlightMapPinMixin:OnMouseLeave()
	self.dataProvider:RemoveRouteToPin(self)

	WorldMapTooltip:Hide()
	ResetCursor()
end

function WorldFlightMapPinMixin:UpdateStyle()
	local atlasFormat
	if(self.textureKitPrefix) then
		-- Argus node
		if(IsVindicaarTextureKit(self.textureKitPrefix)) then
			self:SetNudgeSourceRadius(2)
			self:SetNudgeSourceMagnitude(1.5, 3.65)
		elseif(self.textureKitPrefix == 'FlightMaster_Argus') then
			self:SetNudgeSourceRadius(1.5)
			self:SetNudgeSourceMagnitude(1, 2)
		end

		atlasFormat = self.textureKitPrefix .. '-%s'
	else
		atlasFormat = '%s'
	end

	self:SetAlpha(1)
	if(self.state == Enum.FlightPathState.Current) then
		self.Icon:SetAtlas(atlasFormat:format('Taxi_Frame_Green'))
		self.Highlight:SetAtlas(atlasFormat:format('Taxi_Frame_Gray'))
	elseif(self.state == Enum.FlightPathState.Reachable) then
		self.Icon:SetAtlas(atlasFormat:format('Taxi_Frame_Gray'))
		self.Highlight:SetAtlas(atlasFormat:format('Taxi_Frame_Gray'))
	elseif(self.state == Enum.FlightPathState.Unreachable) then
		self.Icon:SetAtlas(atlasFormat:format('UI-Taxi-Icon-Nub'))
		self.Highlight:SetAtlas(atlasFormat:format('UI-Taxi-Icon-Nub'))
		self:SetAlpha(0.5)
	end

	local mapID = self.dataProvider:GetMap():GetMapID()
	local taxiMapID = self.dataProvider:GetTaxiMapID()
	self.Arrow:SetShown(mapID ~= taxiMapID and self.state ~= Enum.FlightPathState.Unreachable)
end

function WorldFlightMapPinMixin:UpdateSize()
	if(IsVindicaarTextureKit(self.textureKitPrefix)) then
		self:SetSize(39, 42)
	elseif(self.textureKitPrefix == 'FlightMaster_Argus') then
		self:SetSize(34, 28)
	elseif(self.state == Enum.FlightPathState.Current) then
		self:SetSize(28, 28)
	elseif(self.state == Enum.FlightPathState.Reachable) then
		self:SetSize(20, 20)
	elseif(self.state == Enum.FlightPathState.Unreachable) then
		self:SetSize(14, 14)
	end
end

function WorldFlightMapPinMixin:UpdateState()
	self:SetShown(self.state ~= Enum.FlightPathState.Unreachable)
end

local function AnimateArrow(AnimGroup)
	local Arrow = AnimGroup.Arrow
	Arrow:ClearAllPoints()

	local Animation = AnimGroup.Animation
	if(AnimGroup.down) then
		Arrow:SetPoint('BOTTOM', Arrow:GetParent(), 'TOP')
		Animation:SetSmoothing('IN')
	else
		Arrow:SetPoint('BOTTOM', Arrow:GetParent(), 'TOP', 0, 10)
		Animation:SetSmoothing('OUT')
	end

	Animation:SetOffset(0, AnimGroup.down and 10 or -10)
	AnimGroup.down = not AnimGroup.down
	AnimGroup:Play()
end

function WorldFlightMapPinMixin:OnLoad()
	-- self:SetScalingLimits(1.25, 0.9625, 1.275) -- scaling limits to play with
	self:UseFrameLevelType('PIN_FRAME_LEVEL_TOPMOST') -- PIN_FRAME_LEVEL_FLIGHT_POINT was too low
	-- self:SetNudgeSourceRadius(1) -- nudge other pins away

	local Icon = self:CreateTexture(nil, 'OVERLAY')
	Icon:SetAllPoints()
	self.Icon = Icon

	local Highlight = self:CreateTexture(nil, 'HIGHLIGHT')
	Highlight:SetAllPoints()
	Highlight:SetBlendMode('ADD')
	Highlight:SetAlpha(0.25)
	self.Highlight = Highlight

	local Arrow = self:CreateTexture(nil, 'OVERLAY')
	Arrow:SetPoint('BOTTOM', self, 'TOP')
	Arrow:SetSize(32, 32)
	Arrow:SetTexture([[Interface\Minimap\Minimap-DeadArrow]])
	Arrow:SetTexCoord(0, 1, 1, 0)
	self.Arrow = Arrow

	local AnimGroup = Arrow:CreateAnimationGroup()
	AnimGroup.Arrow = Arrow

	local Animation = AnimGroup:CreateAnimation('Translation')
	Animation:SetOffset(0, 10)
	Animation:SetDuration(0.5)
	Animation:SetSmoothing('IN')
	AnimGroup.Animation = Animation

	AnimGroup:SetScript('OnFinished', AnimateArrow)
	AnimGroup:Play()
end
