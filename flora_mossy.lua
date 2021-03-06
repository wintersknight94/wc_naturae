-- LUALOCALS < ---------------------------------------------------------
local math, minetest, nodecore, pairs, type, vector
    = math, minetest, nodecore, pairs, type, vector
local math_random
    = math.random
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- NODE DEFINITIONS

local diggroups = {
	cracky = true,
	crumbly = true,
	choppy = true,
	snappy = true,
	thumpy = true,
	scratchy = true
}

local mossy_groups = {}
nodecore.mossy_groups = mossy_groups

local function tileswith(olddef, suff)
	local tiles = {}
	for k, v in pairs(olddef.tiles) do
		if type(v) == "string" then
			v = v .. "^" .. modname .. "_" .. suff .. ".png"
		end
		tiles[k] = v
	end
	return tiles
end
local function groupswith(olddef, added)
	local groups = {snappy = 1, [added] = 1}
	for k, v in pairs(olddef.groups) do
		if not diggroups[k] then groups[k] = v end
	end
	return groups
end
local function register_mossy(subname, fromname)
	local olddef = minetest.registered_nodes[fromname]
	if not olddef then return end
	local livename = modname .. ":mossy_" .. subname
	minetest.register_node(livename, {
			description = "Mossy " .. olddef.description,
			tiles = tileswith(olddef, "mossy"),
			drop_in_place = fromname,
			groups = groupswith(olddef, "mossy"),
			sounds = nodecore.sounds("nc_terrain_crunchy")
		})
	local dyingname = modname .. ":mossy_" .. subname .. "_dying"
	minetest.register_node(dyingname, {
			description = "Blighted Mossy " .. olddef.description,
			tiles = tileswith(olddef, "mossy_dying"),
			drop_in_place = fromname,
			groups = groupswith(olddef, "mossy_dying"),
			sounds = nodecore.sounds("nc_terrain_crunchy")
		})
	local mossgroup = {
		original = fromname,
		mossy = livename,
		dying = dyingname
	}
	for _, v in pairs(mossgroup) do
		nodecore.mossy_groups[v] = mossgroup
	end
end
nodecore.register_mossy = register_mossy

register_mossy("cobble", "nc_terrain:cobble")
register_mossy("stone", "nc_terrain:stone")
-- XXX: LEGACY PRE-THATCH SUPPORT
register_mossy("thatch", minetest.registered_nodes["nc_flora:thatch"]
	and "nc_flora:thatch" or modname .. ":thatch")
register_mossy("trunk", "nc_tree:tree")
register_mossy("dirt", "nc_terrain:dirt")
register_mossy("bricks", "nc_stonework:bricks_stone")
register_mossy("bricks_bonded", "nc_stonework:bricks_stone_bonded")
register_mossy("adobe", "nc_concrete:adobe")
register_mossy("adobe_bricks", "nc_stonework:bricks_adobe")
register_mossy("adobe_bricks_bonded", "nc_stonework:bricks_adobe_bonded")
register_mossy("sandstone", "nc_concrete:sandstone")
register_mossy("sandstone_bricks", "nc_stonework:bricks_sandstone")
register_mossy("sandstone_bricks_bonded", "nc_stonework:bricks_sandstone_bonded")
for i = 1, 7 do
	register_mossy("hstone" .. i, "nc_terrain:hard_stone_" .. i)
end

------------------------------------------------------------------------
-- SPREADING ABM

local breathable_drawtypes = {
	airlike = true,
	allfaces = true,
	allfaces_optional = true,
	torchlike = true,
	signlike = true,
	plantlike = true,
	firelike = true,
	raillike = true,
	nodebox = true,
	mesh = true,
	plantlike_rooted = true
}

local breathable_nodes = {}
minetest.after(0, function()
		for k, v in pairs(minetest.registered_nodes) do
			if breathable_drawtypes[v.drawtype] then
				breathable_nodes[k] = true
			end
		end
	end)

local function loaded(pos)
	return minetest.get_node_or_nil({x = pos.x - 1, y = pos.y - 1, z = pos.z - 1})
	and minetest.get_node_or_nil({x = pos.x + 1, y = pos.y - 1, z = pos.z - 1})
	and minetest.get_node_or_nil({x = pos.x - 1, y = pos.y + 1, z = pos.z - 1})
	and minetest.get_node_or_nil({x = pos.x + 1, y = pos.y + 1, z = pos.z - 1})
	and minetest.get_node_or_nil({x = pos.x - 1, y = pos.y - 1, z = pos.z + 1})
	and minetest.get_node_or_nil({x = pos.x + 1, y = pos.y - 1, z = pos.z + 1})
	and minetest.get_node_or_nil({x = pos.x - 1, y = pos.y + 1, z = pos.z + 1})
	and minetest.get_node_or_nil({x = pos.x + 1, y = pos.y + 1, z = pos.z + 1})
end

local alldirs = nodecore.dirs()
local function canbreathe(pos)
	for i = 1, #alldirs do
		local p = vector.add(pos, alldirs[i])
		local n = minetest.get_node(p)
		if breathable_nodes[n.name] then
			return true
		end
	end
end

minetest.register_abm({
		label = "moss spreading",
		nodenames = {"group:mossy"},
		interval = 90,
		chance = 10,
		action = function(pos, node)
			if not loaded(pos) then return end
			if not canbreathe(pos) then
				local grp = mossy_groups[node.name]
				return grp and grp.original
				and nodecore.set_node(pos, {name = grp.original})
			end
			local topos = {
				x = pos.x + math_random(-1, 1),
				y = pos.y + math_random(-1, 1),
				z = pos.z + math_random(-1, 1),
			}
			local tonode = minetest.get_node(topos)
			if minetest.get_item_group(tonode.name, "lux_emit") > 0 then
				local grp = mossy_groups[node.name]
				return grp and grp.original
				and nodecore.set_node(pos, {name = grp.dying})
			else
				local grp = mossy_groups[tonode.name]
				return grp and grp.mossy and tonode.name ~= grp.dying
				and canbreathe(topos)
				and nodecore.set_node(topos, {name = grp.mossy})
			end
		end
	})

minetest.register_abm({
		label = "moss blight",
		nodenames = {"group:mossy_dying"},
		interval = 20,
		chance = 10,
		action = function(pos, node)
			if not loaded(pos) then return end
			if not canbreathe(pos) then
				local grp = mossy_groups[node.name]
				return grp and grp.original
				and nodecore.set_node(pos, {name = grp.original})
			end
			local found = nodecore.find_nodes_around(pos, "group:mossy", 1)
			if #found < 1 then
				local grp = mossy_groups[node.name]
				return grp and grp.original
				and nodecore.set_node(pos, {name = grp.original})
			end
			local picked = found[math_random(1, #found)]
			local tonode = minetest.get_node(picked)
			local grp = mossy_groups[tonode.name]
			return grp and grp.mossy and canbreathe(picked)
			and nodecore.set_node(picked, {name = grp.dying})
		end
	})
------------------------------------------------------------------------
 -- Hardstone Degradation --
minetest.register_alias(modname.. ":mossy_hstone0",	modname.. ":mossy_stone")
for i = 1,7 do
nodecore.register_limited_abm({
		label = "moss soften stone",
		nodenames = {modname.. ":mossy_hstone"..i},
		interval = 100,
		chance = 10,
		action = function(pos)
				nodecore.set_node(pos, {name = modname .. ":mossy_hstone"..i-1})
		end
	})
end
