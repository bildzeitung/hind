module(...,package.seeall)

-- fractal outline generator instead
--[[
   +----*----+
   |         |
   *         * 
   |         | 
   +----*----+

   Basically, take an initial shape (currently hardcoded as a square), and 
  take each line segment and subdivide it (the *'s). Then, wiggle the original
  points by some value perpendicular to the *'s around it. Repeat process to
  make the map more detailed. 

  Re-map the point set into a map structure, drawing lines using Bresenham's 
  algorithm.
--]]

--
-- simple point constructor; just has nice printing. Includes copy constructor
--
local function p(x,y)
	local m = { __tostring = function(s) return s.x..','..s.y end }

	-- copy constructor
	if type(x) == 'table' and not y then
		y = x.y ; x = x.x
	end
	
	return setmetatable({x=x,y=y},m)
end

--
-- given two points, return a new point between them
--
local function mid(a,b)
	return p( (a.x+b.x)/2, (a.y+b.y)/2 )
end

--
-- given a point (vector), return the Euclidean norm
--
local function norm(a)
	return math.sqrt( a.x*a.x + a.y*a.y )
end

-- fracturing consists of:
--  - adding a middle point to each line segment
--  - iterating through the intial points; take the prev and next points in the list and
--    calculate the perpendicular vector norm
--  - scale the x,y of said norm and add it to the initial point (so, we wobble it)
--  - return the new point set and the subdivision scaling factor (length) value to use
-- 
local function fracture(points)
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


--
--
--
function displaymap(m)
	for i=1,#m do
		local s = ''
		for j =1,#m[i] do
			if m[i][j] >0 then s = s..'*' else s=s..' ' end
		end
		print(s)
	end
end

--
-- use Bresenham to raster out the line segments
--
local function bresenham(p0,p1,m)
	m[p0.y][p0.x] = 1
	
	local dx = math.abs(p1.x-p0.x)
	local dy = math.abs(p1.y-p0.y)
	
	local sx, sy
	if p0.x < p1.x then sx=1 else sx=-1 end
	if p0.y < p1.y then sy=1 else sy=-1 end
	
	local err = dx-dy
	
	while true do
		m[p0.y][p0.x] = 1
		
		if (p0.x == p1.x) and (p0.y == p1.y) then return end
		
		local e2 = 2*err
		if e2 > -dy then
			err = err-dy
			p0.x = p0.x+sx
		end
		
		if e2 < dx then
			err = err+dx
			p0.y = p0.y+sy
		end
	end
end

--
--
--
function generatemap(points,height,width)
	points = points or { p(0,0), p(0,64), p(64,64), p(64,0) ; length = 64 }
	
	-- do the subdivision
	while points.length > 1 do points = fracture(points) end
	
	--  get bounding box
	local minpt = p(points[1])
	local maxpt = p(points[1])
	for _,v in ipairs(points) do
		if v.x < minpt.x then minpt.x = v.x end
		if v.y < minpt.y then minpt.y = v.y end

		if v.x > maxpt.x then maxpt.x = v.x end
		if v.y > maxpt.y then maxpt.y = v.y end
	end
	
	-- setup the map
	local imin = p(1,1)
	local imax = p(width,height)
	
	-- setup the scaling transformation
	local stx  = (imax.x-imin.x)/(maxpt.x-minpt.x)
	local sty  = (imax.y-imin.y)/(maxpt.y-minpt.y)
	
	-- init map
	local map = {}
	for i=1,imax.y do
		map[i] = {}
		for j =1,imax.x do map[i][j] = 0 end
	end
	
	-- transform window (line segment) space into view (map/raster) space 
	for k,v in ipairs(points) do
		local x = math.floor((v.x-minpt.x)*stx+imin.x)
		local y = math.floor((v.y-minpt.y)*sty+imin.y)
		points[k] = p(x,y)
	end

	-- raster out the island onto the map
	for i=1,#points do
		bresenham(points[i],points[(i% #points)+1],map)
	end
		
	return map
end
