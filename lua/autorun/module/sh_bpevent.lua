AddCSLuaFile()

module("bpevent", package.seeall, bpcommon.rescope(bpschema))

EVF_None = 0
EVF_RPC = 1
EVF_Broadcast = 2
EVF_Server = 4 -- Server -> Client
EVF_Client = 8 -- Client -> Server

EVF_Mask_Netmode = bit.bor( EVF_RPC, EVF_Broadcast, EVF_Server, EVF_Client )

NetModes = {
	{"None", EVF_None },
	{"Send to Server", bit.bor( EVF_RPC, EVF_Client )},
	{"Send to Client", bit.bor( EVF_RPC, EVF_Server )},
	{"Broadcast", bit.bor( EVF_RPC, EVF_Server, EVF_Broadcast )},
}

local meta = bpcommon.MetaTable("bpevent")

bpcommon.AddFlagAccessors(meta)

function meta:Init()

	self.flags = 0
	self.pins = bplist.New(bppin_meta):NamedItems("Pins")
	self.pins:AddListener(function(cb, action, id, var)

		if self.module then
			if cb == bplist.CB_PREMODIFY then
				self:PreModify()
			elseif cb == bplist.CB_POSTMODIFY then
				self:PostModify()
			end
		end

	end, bplist.CB_PREMODIFY + bplist.CB_POSTMODIFY)

	-- Event node on receiving end
	self.eventNodeType = bpnodetype.New()
	self.eventNodeType:AddFlag(NTF_Custom)
	self.eventNodeType:AddFlag(NTF_NotHook)
	self.eventNodeType:SetCodeType(NT_Event)
	self.eventNodeType:SetNodeClass("EventBind")
	self.eventNodeType.GetDisplayName = function() return self:GetName() end
	self.eventNodeType.GetDescription = function() return "Custom Event: " .. self:GetName() end
	self.eventNodeType.GetCategory = function() return self:GetName() end
	self.eventNodeType.event = self

	-- Event calling node
	self.callNodeType = bpnodetype.New()
	self.callNodeType:AddFlag(NTF_Custom)
	self.callNodeType:SetCodeType(NT_Function)
	self.callNodeType:SetNodeClass("EventCall")
	self.callNodeType.GetDisplayName = function() return "Call " .. self:GetName() end
	self.callNodeType.GetDescription = function() return "Call " .. self:GetName() .. " event" end
	self.callNodeType.GetCategory = function() return self:GetName() end
	self.callNodeType.event = self

	return self

end

function meta:PreModify()

	self.module:PreModifyNodeType( self.eventNodeType )
	self.module:PreModifyNodeType( self.callNodeType )

end

function meta:PostModify()

	self.module:PostModifyNodeType( self.eventNodeType )
	self.module:PostModifyNodeType( self.callNodeType )

end

function meta:SetName(name)

	self.name = name

end

function meta:GetName()

	return self.name

end

function meta:CallNodeType()

	return self.callNodeType

end

function meta:EventNodeType()

	return self.eventNodeType

end

function meta:WriteToStream(stream, mode, version)

	self.pins:WriteToStream(stream, mode, version)
	stream:WriteBits(self.flags, 8)
	return self

end

function meta:ReadFromStream(stream, mode, version)

	if not version or version >= 4 then
		self.pins:ReadFromStream(stream, mode, version)
	else
		local oldPins = bplist.New(bpvariable_meta):NamedItems("Pins")
		oldPins:ReadFromStream(stream, mode, version)
		for _, v in oldPins:Items() do
			self.pins:Add( v:CreatePin(PD_None) )
		end
	end
	self.flags = stream:ReadBits(8)
	return self

end

function New(...) return bpcommon.MakeInstance(meta, ...) end