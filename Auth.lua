-- ==========================================
-- 🛡️ ANTI-DETECTION: SILENT CONSOLE
-- ==========================================
-- CHANGE: Added silent console to hide print statements from BAC
--local _original_print = print
--print = function(...) end -- All prints are now silent

-- Optional: Keep original for debugging
--if getgenv then
   -- getgenv()._debug_print = _original_print
--end
--_G._debug_print = _original_print
--_G._original_print = _original_print  -- ✅ ADD THIS LINE
--_G._original_warn = warn  -- ✅ ADD THIS LINE TOO
-- ==========================================

local KeySystem = {}

-- // CONFIGURATION //
local CONFIG = { 
    serviceId = "punkxreleasekey", -- Your service ID
    fileName = "Punk-X-Files/punk-x-key.txt",
    oldFileName = "punk-x-key.txt",
    autoSave = true,
    discordWebhook = "https://discord.com/api/webhooks/1462092315190624330/BQy7iAZ8q5mnh18vIE3LLj2H9gaUnbvbo0jlscALQ3D5t5PXn1YBENHe_7kGk_Xb8vtu" -- Your Discord webhook
}

-- // API CONFIGURATION //
local API = {
    baseURL = "https://new.pandadevelopment.net/api/v1",
    keyPageURL = "https://new.pandadevelopment.net/getkey/"
}

-- ==========================================
-- 🛡️ ANTI-DETECTION: CLONEREF SERVICES
-- ==========================================
-- CHANGE: Added cloneref to protect service references from detection
local cloneref = cloneref or function(obj) return obj end

-- // SERVICES //
local HttpService = cloneref(game:GetService("HttpService"))
local RbxAnalytics = cloneref(game:GetService("RbxAnalyticsService"))
-- ==========================================

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
    elseif eventType == "generated" then
        embed_color = 3447003 -- Blue
        embed_title = "🔑 Key Generated"
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
    
    if keyData.isPremium ~= nil then
        table.insert(fields, {
            name = "Type",
            value = keyData.isPremium and "💎 Premium" or "⭐ Free",
            inline = true
        })
    end
    
    if keyData.expireDate then
        table.insert(fields, {
            name = "Expires",
            value = keyData.expireDate,
            inline = false
        })
    end
    
    if keyData.message then
        table.insert(fields, {
            name = "Status",
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
                text = "Punk X Key System",
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
    local hwid = getHWID()
    return API.keyPageURL .. CONFIG.serviceId .. "?hwid=" .. hwid
end

-- // FUNCTION 1B: Open Get Key (NEW FEATURE) //
function KeySystem.OpenGetKey()
    local url = KeySystem.GetKeyURL()
    if setclipboard then
        setclipboard(url)
       -- print("[AUTH] Key URL copied to clipboard!")
    end
    return url
end

-- // FUNCTION 2: Validate Key (WITH SILENT MODE TO PREVENT DUPLICATE WEBHOOKS) //
function KeySystem.Validate(key, Premium_Verification, silent)
    if not httpRequest then return false, "Executor missing HTTP" end
    
    -- 1. Clean Key
    if not key then return false, "No key provided" end
    key = key:gsub(" ", ""):gsub("\n", ""):gsub("\r", "")
    
    local hwid = getHWID()
    
    -- 2. Build Request Body
    local requestBody = {
        ServiceID = CONFIG.serviceId,
        HWID = hwid,
        Key = key
    }
    
    -- ==========================================
    -- 🛡️ ANTI-DETECTION: GENERIC USER-AGENT
    -- ==========================================
    -- 3. Send Request
    local success, response = pcall(function()
        return httpRequest({
            Url = API.baseURL .. "/keys/validate",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/WinInet" -- CHANGE: Generic User-Agent (was "PunkX-Loader")
            },
            Body = HttpService:JSONEncode(requestBody)
        })
    end)
    -- ==========================================
    
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
    
    -- 4. Decode JSON
    local data = nil
    local decodeSuccess = pcall(function() 
        data = HttpService:JSONDecode(response.Body) 
    end)
    
    if not decodeSuccess or not data then 
        return false, "Invalid JSON response" 
    end
    
    -- 5. Check Authentication
    local isAuthenticated = data.Authenticated_Status == "Success"
    local isPremium = data.Key_Premium or false
    
    -- 6. Apply Premium Verification (if requested)
    local isValid = isAuthenticated
    local message = data.Note or (isAuthenticated and "Key validated!" or "Invalid key")
    
    if Premium_Verification and isAuthenticated and not isPremium then
        isValid = false
        message = "Premium key required"
    end
    
    -- 7. Send Discord Webhook Notification (ONLY IF NOT SILENT)
    if not silent then
        if isValid then
            -- Send success notification
            SendDiscordNotification("validated", {
                key = key,
                hwid = hwid,
                isPremium = isPremium,
                expireDate = data.Expire_Date,
                message = message
            })
        else
            -- Send failure notification
            SendDiscordNotification("invalid", {
                key = key,
                hwid = hwid,
                message = message
            })
        end
    end
    
    -- 8. Save Key (if valid and auto-save enabled)
    if isValid and CONFIG.autoSave and writefile then
        pcall(function()
            if isfolder and not isfolder("Punk-X-Files") then
                makefolder("Punk-X-Files")
            end
            writefile(CONFIG.fileName, key)
           -- print("[AUTH] ✅ Key saved to " .. CONFIG.fileName)
        end)
    end
    
    -- 9. Return Result
    return isValid, {
        message = message,
        isPremium = isPremium,
        expireDate = data.Expire_Date,
        rawData = data
    }
end

-- // FUNCTION 3: Auto Load with Migration (UNCHANGED) //
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
                      --  print("[AUTH] Created Punk-X-Files folder")
                    end
                    writefile(CONFIG.fileName, content)
                    delfile(CONFIG.oldFileName)
                  --  print("[AUTH] ✅ Migrated key to Punk-X-Files/")
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
