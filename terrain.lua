-- fractal outline generator instead
--[[
   +----*----+
   |         |
   *         * 
   |         | 
   +----*----+
--]]

function p(x,y)
	local m = { __tostring = function(s) return s.x..','..s.y end }
	return setmetatable({x=x,y=y},m)
end

function mid(a,b)
	return p( (a.x+b.x)/2, (a.y+b.y)/2 )
end

function norm(a)
	return math.sqrt( a.x*a.x + a.y*a.y )
end

points = { p(0,0), p(0,64), p(64,64), p(64,0) ; length = 64 }

-- assume connected, in a sequence
-- fracturing consists of:
--  - adding a middle point to each line segment
--  - iterating through the intial points; take the prev and next points in the list and
--    calculate the perpendicular vector norm
--  - scale the x,y of said norm and add it to the initial point (so, we wobble it)
--  - return the new point set and the subdivision scaling factor (length) value to use
-- 
function fracture(points)
	local nextgen = {}

	for i=1,#points do
		local a,b = points[i],points[(i% #points)+1]
		local m   = mid(a,b)
		nextgen[#nextgen+1] = a
		nextgen[#nextgen+1] = m
	end

	local length = points.length
	for i=1,#nextgen,2 do
		local nxt = nextgen[i+1]
		local prv = nextgen[(i+#nextgen-2)%#nextgen+1]
		local cur = nextgen[i]

		local dspx = math.random(length) - (length/2) -- [-length,length]
		local dspy = math.random(length) - (length/2) -- [-length,length]
		local v   = p(nxt.x - prv.x, nxt.y-prv.y)
		local nrm = norm(v)
		v = p(-v.y/nrm*dspy,v.x/nrm*dspx)

		cur.x = v.x + cur.x
		cur.y = v.y + cur.y
	end

	nextgen.length = length / 2

	return nextgen
end

-- do the subdivision
while points.length > 1 do
	points = fracture(points)
	for k,v in ipairs(points) do print(v) end
	print '--'
end

-- raster out the result into the map
