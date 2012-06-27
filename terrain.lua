-- heightmap generation according to:
--   http://gameprogrammer.com/fractal.html#diamond
--
-- This is diamond-square algorithm, a kind of twisty red-black with noise
--

local base = 8
local h    = base+1
local w    = base+1

math.randomseed(os.time())
math.random() -- discard first value

-- init terrain
local terrain = {}
for i = 1,h do
  terrain[i] = {}
end

-- set initial corners
terrain[1][1] = 32
terrain[h][1] = 32
terrain[1][w] = 32
terrain[h][w] = 32

local mid    = base/2+1
local step   = base
local hrange = 32
 
-- display the terrain map
function pterrain()
	for i=1,base+1 do
	  local str = ''
	  for j=1,base+1 do
		local val = terrain[i]
		if val then val = val[j] or '-' else val = '-' end
	    str = str .. val .. ' '
	  end
	  print(str)
	end
	print()
end

-- ok, badly named: this fn modifies the value by [-hrange,hrange], and then
-- clamps the values to the range [0,64]
function clamp(x,y)
	terrain[y][x] = terrain[y][x] + math.random(-hrange,hrange)
	
	if terrain[y][x] < 0 then terrain[y][x] = 0 end
	if terrain[y][x] > 64 then terrain[y][x] = 64 end
	
	terrain[y][x] = math.floor(terrain[y][x])
end

while mid > 1 do
	local hstep = step / 2  -- ain't no half-steppin'
	
	-- diamond step
	for i=mid,h,step do
		for j=mid,w,step do
			terrain[i][j] = ( terrain[i-hstep][j-hstep] + terrain[i-hstep][j+hstep] + 
						  	  terrain[i+hstep][j-hstep] + terrain[i+hstep][j+hstep] ) / 4
			clamp(j,i)
		end
	end

	pterrain()
	
	function diamond( x, y )
	  local avg = 0
	  local sum = 0

	  if x < w then
	    sum = sum + terrain[y][x+hstep]
	    avg = avg + 1
	  end

	  if x-step > 0 then
	    sum = sum + terrain[y][x-hstep]
	    avg = avg + 1
	  end

	  if y-step > 0 then
	    sum = sum + terrain[y-hstep][x]
	    avg = avg + 1
	  end

	  if y < h then
	    sum = sum + terrain[y+hstep][x]
	    avg = avg + 1
	  end

	  terrain[y][x] = sum / avg
	  clamp(x,y)
	end

	-- square step
	for i=mid,h, step do
		for j=mid,w, step do
			diamond( j - hstep, i )
			diamond( j,         i - hstep )
			diamond( j + hstep, i )
			diamond( j,         i + hstep )
		end
	end

	pterrain()
	
	print(';;;')

	step = step / 2
	mid  = math.ceil(mid/2)
	hrange = hrange / 2
end
