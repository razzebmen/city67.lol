return {
    Connect = function(ventity)
        if ventity.connection and IsValid(ventity.connection.ent) then
            local trailer = ventity.connection.ent
			if trailer.TrailerStandREN then
				trailer:TrailerStandREN(true)
			end
        end
    end,
    Disconnect = function(ventity)
        if ventity.connection and IsValid(ventity.connection.ent) then
            local trailer = ventity.connection.ent
			if trailer.TrailerStandREN then
				trailer:TrailerStandREN(false)
			end
        end
    end
}
