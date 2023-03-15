factions = {}
factions.invite_queqe = {}
local storage = minetest.get_mod_storage()
--factions structure = {
    --faction_name = {
        --members = {},
        --owner = ""
    --},
--}
function factions.save_data(data)
    if type(data) == "table" then
        storage:set_string("faction_data", minetest.serialize(data))
    end
end

function factions.load_data()
    local faction_data = storage:get_string("faction_data")
    if faction_data then
        faction_data = minetest.deserialize(faction_data)
        --extra check needed
        if type(faction_data) ~= "table" then
            faction_data = {} 
        end
    else 
        faction_data = {}
    end
    return faction_data
end

--store data in ram
local faction_data = factions.load_data()

--return false if player is in no faction
function factions.is_player_in(name)
    local trigger = false
    local fname = nil
    --if not next()
    for faction, cat in pairs(faction_data) do  
        for catname, value in pairs(cat) do
            if catname == "members" then
                for _, member in pairs(value) do
                    if member == name then
                        fname = faction
                        trigger = true
                        break
                    end
                end
            end
        end
    end
    return trigger, fname
end

function factions.is_faction_exist(fname)
    for k, _ in pairs(faction_data) do
        if k == fname then
            return true
        end
    end
    return false
end

function factions.create_faction(name, fname) 
    if factions.is_player_in(name) == true then
        minetest.chat_send_player(name, "[Server] Error your already in a faction")
        return
    end
    if factions.is_faction_exist(fname) == true then
        minetest.chat_send_player(name, "[Server] Sorry but this faction already exists")
        return
    end
    faction_data[fname] = {
        members = {name},
        owner = name           
    }
end

function factions.leave_faction(name)
    local is_in, fname = factions.is_player_in(name) 
    if is_in == false then
        minetest.chat_send_player(name, "[Server] Error your in no faction")
        return
    end
    for i, mname in ipairs(faction_data[fname].members) do
        if mname == name then  
            table.remove(faction_data[fname].members, i)
        end
    end
    --are there any players left?
    if next(faction_data[fname].members) then
        --are we the owner?
        if faction_data[fname].owner == name then
            --if we are the owner make someone random the owner than
            faction_data[fname].owner = faction_data[fname].members[math.random(1, #faction_data[fname].members)]
            minetest.chat_send_player(name, "[Server] the new owner is "..faction_data[fname].owner)
        end
    else
        minetest.chat_send_player(name, "[Server] deleted your faction")
        faction_data[fname] = nil
    end
    minetest.chat_send_player(name, "[Server] Left your faction")
end

function factions.invite_player(name, invited_person)
    local is_in, fname = factions.is_player_in(name)
    if is_in == false then
        minetest.chat_send_player(name, "[Server] You are in no faction")
        return 
    end
    if factions.is_player_in(invited_person) == true then
        minetest.chat_send_player(name, "[Server] This user is already in a faction")
        return
    end
    minetest.chat_send_player(invited_person, "[Server] You have been invite to join "..fname.." to accept type /faction_accept")
    factions.invite_queqe[invited_person] = fname
end
    
function factions.invite_accept(name) 
    if factions.is_player_in(name) == true then
        minetest.chat_send_player(name, "[Server] Your already in a faction")
        factions.invite_queqe[name] = nil 
        return
    end
    if factions.invite_queqe[name] == nil then
       minetest.chat_send_player(name, "[Server] theres no invite in you queqe")
       return  
    end
    table.insert(faction_data[factions.invite_queqe[name]].members, name)
    minetest.chat_send_player(name, "[Server] You joined the faction "..factions.invite_queqe[name])
    factions.invite_queqe[name] = nil
end

function factions.kick_player(name, kicked_person)
    local is_in, fname = factions.is_player_in(name) 
    if is_in == false then 
       minetest.chat_send_player(name, "[Server] Your not in a faction")
       return 
    end
    if faction_data[fname].owner ~= name then
       minetest.chat_send_player(name, "[Server] Only the owner can kick others")
       return  
    end
    for i, mname in ipairs(faction_data[fname].members) do
        if mname == kicked_person then  
            table.remove(faction_data[fname].members, i)
            minetest.chat_send_player(name, "[Server] kicked "..kicked_person)
            break
        end
    end 
end 

minetest.register_on_shutdown(function() 
    factions.save_data(faction_data)
end)
local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer +dtime 
    if timer == 3600 then
       factions.save_data(faction_data)
       timer = 0
    end
end)

minetest.register_chatcommand("faction_create", {
    description = "/faction_create [faction_name] creates a faction",
    privs = {interact=true},
    func = function(name, param)
        factions.create_faction(name, param) 
    end
})

minetest.register_chatcommand("faction_leave", {
    description = "/faction_leave leave a faction",
    privs = {interact=true},
    func = function(name, param)
        factions.leave_faction(name)
    end
})


minetest.register_chatcommand("faction_invite", {
    description = "/faction_invite invite others to your faction",
    privs = {interact=true},
    func = function(name, param)
        if minetest.get_player_by_name(param) == nil then
           minetest.chat_send_player(name, "[Server] Error user has to be online")
           return 
        end
        factions.invite_player(name, param)
    end
})

minetest.register_chatcommand("faction_accept", {
    description = "/faction_accept accept a faction invite",
    privs = {interact=true},
    func = function(name, param)
        factions.invite_accept(name) 
    end
})

minetest.register_chatcommand("faction_kick", {
    description = "/faction_kick [name] kicks a player from your faction",
    privs = {interact=true},
    func = function(name, param)
        if param == "" then return end
        factions.kick_player(name, param)
    end
})

minetest.register_chatcommand("faction_info", {
    description = "/faction_info [faction] returns a list of all members + the owner",
    privs = {interact=true},
    func = function(name, param)
        if param == "" then return end
        if factions.is_faction_exist(param) then
            minetest.chat_send_player(name, "[Server] Faction: "..param)
            minetest.chat_send_player(name, "[Server] Owner: "..faction_data[param].owner)
            minetest.chat_send_player(name, "[Server] members: "..table.concat(faction_data[param].members, ", "))
        end
    end
})

minetest.register_chatcommand("faction_pinfo", {
    description = "/faction_pinfo [player] returns a list of the faction where the player is in + all members and the owner",
    privs = {interact=true},
    func = function(name, param)
        if param == "" then return end
        local is_in, fname = factions.is_player_in(param)
        if is_in == true then
            minetest.chat_send_player(name, "[Server] Faction: "..fname)
            minetest.chat_send_player(name, "[Server] Owner: "..faction_data[fname].owner)
            minetest.chat_send_player(name, "[Server] members: "..table.concat(faction_data[fname].members, ", "))
        end
    end
})
