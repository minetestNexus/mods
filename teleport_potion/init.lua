
--= Teleport Potion mod by TenPlus1 (SFX are license free)

-- Craft teleport potion or pad, use to bookmark location, place to open
-- portal or place pad, portals show a blue flame that you can walk into
-- before it closes (10 seconds), potions can also be thrown for local teleport.


-- Load support for intllib.
local MP = minetest.get_modpath(minetest.get_current_modname())
local S = minetest.get_translator and minetest.get_translator("teleport_potion") or
		dofile(MP .. "/intllib.lua")

-- check for MineClone2
local mcl = minetest.get_modpath("mcl_core")

-- max teleport distance
local dist = tonumber(minetest.settings:get("map_generation_limit") or 31000)

-- creative check
local creative_mode_cache = minetest.settings:get_bool("creative_mode")

local function is_creative(name)
	return creative_mode_cache or minetest.check_player_privs(name, {creative = true})
end

-- make sure coordinates are valid
local check_coordinates = function(str)

	if not str or str == "" then
		return nil
	end

	-- get coords from string
	local x, y, z = string.match(str, "^(-?%d+),(-?%d+),(-?%d+)$")

	-- check coords
	if x == nil or string.len(x) > 6
	or y == nil or string.len(y) > 6
	or z == nil or string.len(z) > 6 then
		return nil
	end

	-- convert string coords to numbers
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z)

	-- are coords in map range ?
	if x > dist or x < -dist
	or y > dist or y < -dist
	or z > dist or z < -dist then
		return nil
	end

	-- return ok coords
	return {x = x, y = y, z = z}
end

-- particle effects
local function tp_effect(pos)

	minetest.add_particlespawner({
		amount = 20,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x = -2, y = 1, z = -2},
		maxvel = {x = 2,  y = 2,  z = 2},
		minacc = {x = 0, y = -2, z = 0},
		maxacc = {x = 0, y = -4, z = 0},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = 0.5,
		maxsize = 1.5,
		texture = "teleport_potion_particle.png",
		glow = 15
	})
end

local teleport_destinations = {}

local function set_teleport_destination(playername, dest)

	teleport_destinations[playername] = dest

	tp_effect(dest)

	minetest.sound_play("portal_open", {
			pos = dest, gain = 1.0, max_hear_distance = 10}, true)
end

--- Teleport portal
minetest.register_node("teleport_potion:portal", {
	drawtype = "plantlike",
	tiles = {
		{
			name = "teleport_potion_portal.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.0
			}
		}
	},
	light_source = 13,
	walkable = false,
	paramtype = "light",
	pointable = false,
	buildable_to = true,
	waving = 1,
	sunlight_propagates = true,
	damage_per_second = 1, -- walking into portal hurts player
	groups = {not_in_creative_inventory = 1},

	-- start timer when portal appears
	on_construct = function(pos)
		minetest.get_node_timer(pos):start(10)
	end,

	-- remove portal after 10 seconds
	on_timer = function(pos)

		minetest.sound_play("portal_close", {
				pos = pos, gain = 1.0, max_hear_distance = 10}, true)

		minetest.remove_node(pos)
	end,
	on_blast = function() end,
	drop = {}
})

-- Throwable potion
local function throw_potion(itemstack, player)

	local playerpos = player:get_pos()

	local obj = minetest.add_entity({
		x = playerpos.x,
		y = playerpos.y + 1.5,
		z = playerpos.z
	}, "teleport_potion:potion_entity")

	local dir = player:get_look_dir()
	local velocity = 20

	obj:set_velocity({
		x = dir.x * velocity,
		y = dir.y * velocity,
		z = dir.z * velocity
	})

	obj:set_acceleration({
		x = dir.x * -3,
		y = -9.5,
		z = dir.z * -3
	})

	obj:set_yaw(player:get_look_horizontal())
	obj:get_luaentity().player = player
end

-- potion entity
local potion_entity = {
	physical = true,
	visual = "sprite",
	visual_size = {x = 1.0, y = 1.0},
	textures = {"teleport_potion_potion.png"},
	collisionbox = {-0.1,-0.1,-0.1,0.1,0.1,0.1},
	lastpos = {},
	player = ""
}

potion_entity.on_step = function(self, dtime)

	if not self.player then

		self.object:remove()

		return
	end

	local pos = self.object:get_pos()

	if self.lastpos.x ~= nil then

		local vel = self.object:get_velocity()

		-- only when potion hits something physical
		if vel.x == 0
		or vel.y == 0
		or vel.z == 0 then

			if self.player ~= "" then

				-- round up coords to fix glitching through doors
				self.lastpos = vector.round(self.lastpos)

				self.player:set_pos(self.lastpos)

				minetest.sound_play("portal_close", {
					pos = self.lastpos,
					gain = 1.0,
					max_hear_distance = 5
				}, true)

				tp_effect(self.lastpos)
			end

			self.object:remove()

			return

		end
	end

	self.lastpos = pos
end

minetest.register_entity("teleport_potion:potion_entity", potion_entity)

--- Teleport potion
minetest.register_node("teleport_potion:potion", {
	tiles = {"teleport_potion_potion.png"},
	drawtype = "signlike",
	paramtype = "light",
	paramtype2 = "wallmounted",
	walkable = false,
	sunlight_propagates = true,
	description = S("Teleport Potion (use to set destination, place to open portal)"),
	inventory_image = "teleport_potion_potion.png",
	wield_image = "teleport_potion_potion.png",
	groups = {dig_immediate = 3, vessel = 1},
	selection_box = {type = "wallmounted"},

	on_use = function(itemstack, user, pointed_thing)

		if pointed_thing.type == "node" then
			set_teleport_destination(user:get_player_name(), pointed_thing.above)
		else
			throw_potion(itemstack, user)

			if not is_creative(user:get_player_name()) then

				itemstack:take_item()

				return itemstack
			end
		end
	end,

	after_place_node = function(pos, placer, itemstack, pointed_thing)

		local name = placer:get_player_name()
		local dest = teleport_destinations[name]

		if dest then

			minetest.set_node(pos, {name = "teleport_potion:portal"})

			local meta = minetest.get_meta(pos)

			-- Set portal destination
			meta:set_int("x", dest.x)
			meta:set_int("y", dest.y)
			meta:set_int("z", dest.z)

			-- Portal open effect and sound
			tp_effect(pos)

			minetest.sound_play("portal_open", {
					pos = pos, gain = 1.0, max_hear_distance = 10}, true)
		else
			minetest.chat_send_player(name, S("Potion failed!"))
			minetest.remove_node(pos)
			minetest.add_item(pos, "teleport_potion:potion")
		end
	end
})

-- teleport potion recipe
if mcl then
minetest.register_craft({
	output = "teleport_potion:potion",
	recipe = {
		{"", "mcl_core:diamond", ""},
		{"mcl_core:diamond", "mcl_potions:glass_bottle", "mcl_core:diamond"},
		{"", "mcl_core:diamond", ""}
	}
})
else
minetest.register_craft({
	output = "teleport_potion:potion",
	recipe = {
		{"", "default:diamond", ""},
		{"default:diamond", "vessels:glass_bottle", "default:diamond"},
		{"", "default:diamond", ""}
	}
})
end

--- Teleport pad
local teleport_formspec_context = {}

minetest.register_node("teleport_potion:pad", {
	tiles = {"teleport_potion_pad.png", "teleport_potion_pad.png^[transformFY"},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_wallmounted = true,
	walkable = true,
	sunlight_propagates = true,
	description = S("Teleport Pad (use to set destination, place to open portal)"),
	inventory_image = "teleport_potion_pad.png",
	wield_image = "teleport_potion_pad.png",
	light_source = 5,
	groups = {snappy = 3},
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},

	-- Save pointed nodes coordinates as destination for further portals
	on_use = function(itemstack, user, pointed_thing)

		if pointed_thing.type == "node" then
			set_teleport_destination(user:get_player_name(), pointed_thing.above)
		end
	end,

	-- Initialize teleport to saved location or the current position
	after_place_node = function(pos, placer, itemstack, pointed_thing)

		local meta = minetest.get_meta(pos)
		local name = placer:get_player_name()
		local dest = teleport_destinations[name]

		if not dest then
			dest = pos
		end

		-- Set coords
		meta:set_int("x", dest.x)
		meta:set_int("y", dest.y)
		meta:set_int("z", dest.z)

		meta:set_string("infotext", S("Pad Active (@1,@2,@3)",
				dest.x, dest.y, dest.z))

		minetest.sound_play("portal_open", {
				pos = pos,	 gain = 1.0, max_hear_distance = 10}, true)
	end,

	-- Show formspec depending on the players privileges.
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)

		local name = clicker:get_player_name()

		if minetest.is_protected(pos, name) then

			minetest.record_protection_violation(pos, name)

			return
		end

		local meta = minetest.get_meta(pos)
		local coords = {
			x = meta:get_int("x"),
			y = meta:get_int("y"),
			z = meta:get_int("z")
		}
		local coords = coords.x .. "," .. coords.y .. "," .. coords.z
		local desc = meta:get_string("desc")

		formspec = "field[desc;" .. S("Description") .. ";"
				.. minetest.formspec_escape(desc) .. "]"

		-- Only allow privileged players to change coordinates
		if minetest.check_player_privs(name, "teleport") then
			formspec = formspec ..
					"field[coords;" .. S("Teleport coordinates") .. ";" .. coords .. "]"
		end

		teleport_formspec_context[name] = {
			pos = pos,
			coords = coords,
			desc = desc,
		}

		minetest.show_formspec(name, "teleport_potion:set_destination", formspec)
	end
})

-- Check and set coordinates
minetest.register_on_player_receive_fields(function(player, formname, fields)

	if formname ~= "teleport_potion:set_destination" then
		return false
	end

	local name = player:get_player_name()
	local context = teleport_formspec_context[name]

	if not context then return false end

	teleport_formspec_context[name] = nil

	local meta = minetest.get_meta(context.pos)

	-- Coordinates were changed
	if fields.coords and fields.coords ~= context.coords then

		local coords = check_coordinates(fields.coords)

		if coords then
			meta:set_int("x", coords.x)
			meta:set_int("y", coords.y)
			meta:set_int("z", coords.z)
		else
			minetest.chat_send_player(name, S("Teleport Pad coordinates failed!"))
		end
	end

	-- Update infotext
	if fields.desc and fields.desc ~= "" then
		meta:set_string("desc", fields.desc)
		meta:set_string("infotext", S("Teleport to @1", fields.desc))
	else
		local coords = minetest.string_to_pos("(" .. context.coords .. ")")

		meta:set_string("infotext", S("Pad Active (@1,@2,@3)",
			coords.x, coords.y, coords.z))
	end

	return true
end)

-- teleport pad recipe
if mcl then
minetest.register_craft({
	output = "teleport_potion:pad",
	recipe = {
		{"teleport_potion:potion", "mcl_core:glass", "teleport_potion:potion"},
		{"mcl_core:glass", "mesecons:redstone", "mcl_core:glass"},
		{"teleport_potion:potion", "mcl_core:glass", "teleport_potion:potion"}
	}
})
else
minetest.register_craft({
	output = "teleport_potion:pad",
	recipe = {
		{"teleport_potion:potion", "default:glass", "teleport_potion:potion"},
		{"default:glass", "default:mese", "default:glass"},
		{"teleport_potion:potion", "default:glass", "teleport_potion:potion"}
	}
})
end

-- check portal & pad, teleport any entities on top
minetest.register_abm({
	label = "Potion/Pad teleportation",
	nodenames = {"teleport_potion:portal", "teleport_potion:pad"},
	interval = 2,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)

		-- check objects inside pad/portal
		local objs = minetest.get_objects_inside_radius(pos, 1)

		if #objs == 0 then
			return
		end

		-- get coords from pad/portal
		local meta = minetest.get_meta(pos)

		if not meta then return end -- errorcheck

		local target_coords = {
			x = meta:get_int("x"),
			y = meta:get_int("y"),
			z = meta:get_int("z")
		}

		for n = 1, #objs do

			if objs[n]:is_player() then

				-- play sound on portal end
				minetest.sound_play("portal_close", {
					pos = pos,
					gain = 1.0,
					max_hear_distance = 5
				}, true)

				-- move player
				objs[n]:set_pos(target_coords)

				-- paricle effects on arrival
				tp_effect(target_coords)

				-- play sound on destination end
				minetest.sound_play("portal_close", {
					pos = target_coords,
					gain = 1.0,
					max_hear_distance = 5
				}, true)

				-- rotate player to look in pad placement direction
				local rot = node.param2
				local yaw = 0

				if rot == 0 or rot == 20 then
					yaw = 0 -- north
				elseif rot == 2 or rot == 22 then
					yaw = 3.14 -- south
				elseif rot == 1 or rot == 23 then
					yaw = 4.71 -- west
				elseif rot == 3 or rot == 21 then
					yaw = 1.57 -- east
				end

				objs[n]:set_look_horizontal(yaw)
			end
		end
	end
})


-- lucky blocks
if minetest.get_modpath("lucky_block") then

	lucky_block:add_blocks({
		{"dro", {"teleport_potion:potion"}, 2},
		{"tel"},
		{"dro", {"teleport_potion:pad"}, 1},
		{"lig"}
	})
end

print ("[MOD] Teleport Potion loaded")
