local color_name = {}
local function create_color(name)
    local R = math.random(0, 255)
    local G = math.random(0, 255)
    local B = math.random(0, 255)
    local name_wrap = minetest.colorize(string.format("#%X%X%X", R, G, B), name)
    color_name[name] = name_wrap
end
function get_colored_name(name) 
    return color_name[name]
end

minetest.register_on_joinplayer(function(player)
    local name = player and player:get_player_name()
    create_color(name)   
end)

minetest.register_on_leaveplayer(function(player)
    local name = player and player:get_player_name()
    color_name[name] = nil
end)

