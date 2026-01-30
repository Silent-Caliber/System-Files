local KeySystem = {}

-- // CONFIGURATION //
local CONFIG = { 
    workerURL = "https://punk-x-validator.qqsilentcaliber.workers.dev",
    projectID = "bfc2470693470fa2438ea2ff4b7dd4be",
    fileName = "Punk-X-Files/punk-x-key.txt",
    oldFileName = "punk-x-key.txt",
    autoSave = true,
    -- discordWebhook = "https://discord.com/api/webhooks/1462092315190624330/BQy7iAZ8q5mnh18vIE3LLj2H9gaUnbvbo0jlscALQ3D5t5PXn1YBENHe_7kGk_Xb8vtu" -- Optional: Your Discord webhook
}

-- // SERVICES //
local HttpService = game:GetService("HttpService")
local RbxAnalytics = game:GetService("RbxAnalyticsService")

-- // SAFE REQUEST FUNCTION //
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

-- // HELPER: Get HWID //
local function getHWID()
    if gethwid then 
        local success, hwid = pcall(gethwid)
        if success and hwid then
            return hwid
        end
    end
    -- Fallback to analytics client ID
    local clientId = tostring(RbxAnalytics:GetClientId())
    return clientId:gsub("-", "")
end

-- // DISCORD WEBHOOK NOTIFICATION //
local function SendDiscordNotification(eventType, keyData)
    if not CONFIG.discordWebhook or CONFIG.discordWebhook == "" then
        return -- Webhook not configured
    end
    
    -- Determine embed color and title based on event
    local embed_color = 3066993 -- Green by default
    local embed_title = "🔑 Key Activity"
    
    if eventType == "validated" then
        embed_color = 3066993 -- Green
        embed_title = "✅ Key Validated"
    elseif eventType == "invalid" then
        embed_color = 15158332 -- Red
        embed_title = "❌ Invalid Key Attempt"
    end
    
    -- Build embed fields
    local fields = {}
    
    if keyData.key then
        table.insert(fields, {
            name = "Key",
            value = "`" .. keyData.key .. "`",
            inline = true
        })
    end
    
    if keyData.hwid then
        table.insert(fields, {
            name = "HWID",
            value = "`" .. keyData.hwid .. "`",
            inline = true
        })
    end
    
    if keyData.status then
        table.insert(fields, {
            name = "Status",
            value = keyData.status,
            inline = true
        })
    end
    
    if keyData.expireDate and keyData.expireDate ~= -1 then
        table.insert(fields, {
            name = "Expires",
            value = os.date("%Y-%m-%d %H:%M", keyData.expireDate),
            inline = false
        })
    elseif keyData.expireDate == -1 then
        table.insert(fields, {
            name = "Expires",
            value = "Never",
            inline = false
        })
    end
    
    if keyData.message then
        table.insert(fields, {
            name = "Message",
            value = keyData.message,
            inline = false
        })
    end
    
    -- Add timestamp
    table.insert(fields, {
        name = "Timestamp",
        value = os.date("%B %d, %Y at %I:%M %p"),
        inline = false
    })
    
    -- Build webhook payload
    local data = {
        embeds = {{
            title = embed_title,
            color = embed_color,
            fields = fields,
            footer = {
                text = "Punk X Key System (Luarmor)",
                icon_url = "https://cdn.discordapp.com/attachments/1462092249184600240/1465964218082918570/px_icon.png"
            }
        }}
    }
    
    -- Send webhook (wrapped in pcall to prevent errors from blocking execution)
    task.spawn(function()
        pcall(function()
            httpRequest({
                Url = CONFIG.discordWebhook,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

-- // FUNCTION 1: Generate Key URL //
function KeySystem.GetKeyURL()
    return "https://ads.luarmor.net/get_key?for=Punk_X_Key_Linkvertise-dkRIdYhLraNW"
end

-- // FUNCTION 1B: Open Get Key //
function KeySystem.OpenGetKey()
    local url = KeySystem.GetKeyURL()
    if setclipboard then
        setclipboard(url)
        print("[AUTH] Key URL copied to clipboard!")
    end
    return url
end

-- // FUNCTION 2: Validate Key (LUARMOR VERSION) //
function KeySystem.Validate(key, Premium_Verification, silent)
    if not httpRequest then return false, "Executor missing HTTP" end
    
    -- 1. Clean Key
    if not key then return false, "No key provided" end
    key = key:gsub(" ", ""):gsub("\n", ""):gsub("\r", "")
    
    local hwid = getHWID()
    
    -- 2. Call Cloudflare Worker (which calls Luarmor API)
    local success, response = pcall(function()
        return httpRequest({
            Url = CONFIG.workerURL .. "?key=" .. HttpService:UrlEncode(key) .. "&hwid=" .. HttpService:UrlEncode(hwid),
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
    end)
    
    if not success or not response then 
        -- Send webhook notification for connection error (only if not silent)
        if not silent then
            SendDiscordNotification("invalid", {
                key = key,
                hwid = hwid,
                message = "Connection Error"
            })
        end
        return false, "Connection Error" 
    end
    
    -- 3. Decode JSON
    local data = nil
    local decodeSuccess = pcall(function() 
        data = HttpService:JSONDecode(response.Body) 
    end)
    
    if not decodeSuccess or not data then 
        return false, "Invalid JSON response" 
    end
    
    -- 4. Check Luarmor Response Format
    local isValid = false
    local message = "Invalid key"
    local expireDate = nil
    
    if data.success and data.users and #data.users > 0 then
        local user = data.users[1]
        
        -- Check if user is active and not banned
        if user.status == "active" and user.banned == 0 then
            isValid = true
            message = "Key validated successfully"
            expireDate = user.auth_expire
            
            -- Check if expired
            if user.auth_expire ~= -1 and user.auth_expire < os.time() then
                isValid = false
                message = "Key has expired"
            end
        elseif user.status == "reset" then
            isValid = true
            message = "Key validated (HWID will be linked)"
            expireDate = user.auth_expire
        elseif user.banned == 1 then
            isValid = false
            message = user.ban_reason or "Key is banned"
        else
            isValid = false
            message = "Key status: " .. (user.status or "unknown")
        end
    else
        isValid = false
        message = data.message or "Key not found"
    end
    
    -- 5. Send Discord Webhook Notification (ONLY IF NOT SILENT)
    if not silent then
        if isValid then
            SendDiscordNotification("validated", {
                key = key,
                hwid = hwid,
                status = "Active",
                expireDate = expireDate,
                message = message
            })
        else
            SendDiscordNotification("invalid", {
                key = key,
                hwid = hwid,
                message = message
            })
        end
    end
    
    -- 6. Save Key (if valid and auto-save enabled)
    if isValid and CONFIG.autoSave and writefile then
        pcall(function()
            if isfolder and not isfolder("Punk-X-Files") then
                makefolder("Punk-X-Files")
            end
            writefile(CONFIG.fileName, key)
            print("[AUTH] ✅ Key saved to " .. CONFIG.fileName)
        end)
    end
    
    -- 7. Return Result (compatible with old Panda format)
    return isValid, {
        message = message,
        isPremium = false, -- Luarmor doesn't have premium field
        expireDate = expireDate == -1 and "Never" or (expireDate and os.date("%Y-%m-%d", expireDate) or nil),
        rawData = data
    }
end

-- // FUNCTION 3: Auto Load with Migration //
function KeySystem.GetSavedKey()
    if not (isfile and readfile) then return nil end
    
    -- STEP 1: Check OLD location for migration
    if isfile(CONFIG.oldFileName) then
        local success, content = pcall(function()
            return readfile(CONFIG.oldFileName)
        end)
        
        if success and content and #content > 1 then
            -- MIGRATE: Move to new location
            if writefile and delfile then
                pcall(function()
                    if isfolder and not isfolder("Punk-X-Files") then
                        makefolder("Punk-X-Files")
                        print("[AUTH] Created Punk-X-Files folder")
                    end
                    writefile(CONFIG.fileName, content)
                    delfile(CONFIG.oldFileName)
                    print("[AUTH] ✅ Migrated key to Punk-X-Files/")
                end)
            end
            return content
        end
    end
    
    -- STEP 2: Check NEW location
    if isfile(CONFIG.fileName) then
        local success, content = pcall(function()
            return readfile(CONFIG.fileName)
        end)
        if success and content and #content > 1 then
            return content
        end
    end
    
    return nil
end
return KeySystem
