nw.Register("rp.ReportClaimed"):Write(net.WriteBool):Read(net.ReadBool):SetPlayer()
nw.Register("rp.LastReport"):Write(net.WriteInt, 32):Read(net.ReadInt, 32):SetPlayer()

function freports.FormatRankName(r_or_p)
	if isstring(r_or_p) then
		return freports.config.BRanks[r_or_p] and freports.config.BRanks[r_or_p][1] or r_or_p
	elseif isentity(r_or_p) then
		return freports.config.BRanks[r_or_p:GetUserGroup()] and freports.config.BRanks[r_or_p:GetUserGroup()][1] or r_or_p:GetUserGroup()
	end

	return "N/A"
end

function freports.FormatRankColor(r_or_p)
	if isstring(r_or_p) then
		return freports.config.BRanks[r_or_p] and freports.config.BRanks[r_or_p][2] or Color(255, 255, 255)
	elseif isentity(r_or_p) then
		return freports.config.BRanks[r_or_p:GetUserGroup()] and freports.config.BRanks[r_or_p:GetUserGroup()][2] or Color(255, 255, 255)
	end

	return Color(255, 255, 255)
end