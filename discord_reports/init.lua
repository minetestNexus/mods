minetest.register_chatcommand("report", {
    description = "/report <report> sends a report directly to discord in the reports channel",
    privs = {interact=true},
    func = function(name, param)
        if param == nil then return end
        send_message_on_discord_reports("[Server] Report from **"..name.."**: "..param)
    end
})
