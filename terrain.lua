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

	-- copy constructor
	if type(x) == 'table' and not y then
		y = x.y ; x = x.x
	end
	
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
	--for k,v in ipairs(points) do print(v) end
	--print '--'
end

--  get bounding box
local minpt = p(points[1])
local maxpt = p(points[1])
for _,v in ipairs(points) do
	if v.x < minpt.x then minpt.x = v.x end
	if v.y < minpt.y then minpt.y = v.y end

	if v.x > maxpt.x then maxpt.x = v.x end
	if v.y > maxpt.y then maxpt.y = v.y end
end

print("Bounds",minpt,maxpt)

-- raster out the result into the map
local imin = p(1,1)
local imax = p(32,32)
local stx  = (imax.x-imin.x)/(maxpt.x-minpt.x)
local sty  = (imax.y-imin.y)/(maxpt.y-minpt.y)

print('Scaling: ',stx,sty)

local map = {}

-- init map
for i=1,imax.y do
	map[i] = {}
	for j =1,imax.x do
		map[i][j] = 0
	end
end

function displaymap(m)
	for i=1,#m do
		local s = ''
		for j =1,#m[i] do
			if m[i][j] >0 then s = s..'*' else s=s..' ' end
		end
		print(s)
	end
end

-- transform window (line segment) space into view (map/raster) space 
for k,v in ipairs(points) do
	local x = math.floor((v.x-minpt.x)*stx+imin.x)
	local y = math.floor((v.y-minpt.y)*sty+imin.y)
	--print(v,x,y)
	map[y][x] = 1
	points[k] = p(x,y)
end

displaymap(map)