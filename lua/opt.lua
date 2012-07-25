--[[ MUCH SLOWER
local s = os.clock()
for i = 1, 10000000 do
	local a = {}
	a[1] = 1; a[2] = 2; a[3] = 3
end
print(os.clock()-s)

MUCH FASTER!
local s = os.clock()
for i = 1, 10000000 do
	local a = {true, true, true}
	a[1] = 1; a[2] = 2; a[3] = 3
end
print(os.clock()-s)
]]

collectgarbage('stop')
print(collectgarbage('count'))
local t = {}
for i = 1200, 3000 do
	t[i] = os.time({year = i, month = 6, day = 14})
end
print(collectgarbage('count'))
local t = {}
local aux = {year = nil, month = 6, day = 14}
	for i = 1200, 3000 do
	aux.year = i
	t[i] = os.time(aux)
end
print(collectgarbage('count'))