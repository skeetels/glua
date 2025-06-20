-- Hacking Device CMD Interface Script for Garry's Mod
-- This script creates a CMD-style hacking interface when a player uses a special device near certain points.
-- It is a single-file script including both server and client logic, to be placed in autorun.
-- 
-- Configuration: define hacking points (as Vectors) and the required weapon class below.
if SERVER then
    AddCSLuaFile()  -- make the script available to clients
end

-- Define hackable coordinate points (Vector positions) and their state
local hackPoints = {
    { pos = Vector(-10842.984375, -5028.040527, -10584.201172), hacked = false, hacker = nil },  -- example point 1
    { pos = Vector(-10653.181641, -5521.907715, -10585.047852), hacked = false, hacker = nil },    -- example point 2
    { pos = Vector(-10549.229492, -5689.946777, -10583.992188), hacked = false, hacker = nil }   -- example point 3
}

-- Settings
local hackRadius = 120         -- distance (in units) within which the use key will trigger the hack
local requiredWeapon = "weapon_hdevice"  -- class name of the device required to be held to initiate hack
local hackDuration = 120       -- hack duration in seconds
local logInterval = 0.25       -- interval for log output lines (seconds)

-- Server-side state tracking
if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("StartHack")
    util.AddNetworkString("StopHack")
    util.AddNetworkString("CompleteHack")

    local hackingPlayers = {}
    local hackingPlayer = nil

    local function StartPlayerHack(ply, idx)
        hackingPlayers[ply] = idx
        hackingPlayer = ply
        hackPoints[idx].active = true
        ply:Freeze(true)

        net.Start("StartHack")
        net.WriteUInt(idx, 8)
        net.Send(ply)

        timer.Create("HackTimer_" .. ply:SteamID64(), hackDuration, 1, function()
            if IsValid(ply) then
                hackPoints[idx].hacked = true
                hackPoints[idx].active = false
                hackingPlayers[ply] = nil
                hackingPlayer = nil
                ply:Freeze(false)

                net.Start("CompleteHack")
                net.Send(ply)
            end
        end)
    end

    local function CancelPlayerHack(ply)
        local idx = hackingPlayers[ply]
        if not idx then return end

        timer.Remove("HackTimer_" .. ply:SteamID64())
        hackPoints[idx].active = false
        hackingPlayers[ply] = nil
        hackingPlayer = nil
        ply:Freeze(false)

        net.Start("StopHack")
        net.Send(ply)
    end

    hook.Add("KeyPress", "HackDeviceUseKey", function(ply, key)
        if key ~= IN_USE then return end
        if hackingPlayer then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= requiredWeapon then return end

        local plyPos = ply:GetPos()
        for idx, point in ipairs(hackPoints) do
            if not point.hacked and not point.active and plyPos:Distance(point.pos) <= hackRadius then
                StartPlayerHack(ply, idx)
                return
            end
        end
    end)

    hook.Add("PlayerDisconnected", "HackDevicePlayerLeave", CancelPlayerHack)
    hook.Add("PlayerDeath", "HackDevicePlayerDied", CancelPlayerHack)

    net.Receive("StopHack", function(len, ply)
        CancelPlayerHack(ply)
    end)
end -- Вот это правильно закрывает весь блок if SERVER

-- Client-side code: handle UI and simulated hacking interface
if CLIENT then
    -- Font for the console text (monospaced, green color will be applied via RichText)
    surface.CreateFont("HackDeviceFont", {
        font = "Consolas",
        size = 16,
        weight = 500,
        antialias = true
    })

    -- Keep track of the hacking UI frame and state
    local hackFrame, console
    local hackActive = false
    local hackingPlayer = nil -- Глобально в серверном блоке

    local function StartHack(ply, idx)
        hackingPlayer = ply -- устанавливаем текущего взломщика
        hackPoints[idx].active = true
        ply:Freeze(true)

        net.Start("StartHack")
        net.WriteUInt(idx, 8)
        net.Send(ply)

        timer.Create("HackTimer_" .. ply:SteamID64(), hackDuration, 1, function()
            if IsValid(ply) and hackPoints[idx].active then
                ply:Freeze(false)
                hackPoints[idx].active = false
                hackPoints[idx].hacked = true
                hackingPlayer = nil -- освобождаем при завершении
                net.Start("CompleteHack")
                net.Send(ply)
            end
        end)
    end

    hook.Add("KeyPress", "HackUseKey", function(ply, key)
        if key ~= IN_USE then return end

        if hackingPlayer then return end -- проверка на наличие активного взлома

    -- проверка оружия
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= requiredWeapon then return end

        local plyPos = ply:GetPos()
        for idx, point in ipairs(hackPoints) do
            if not point.hacked and not point.active and plyPos:Distance(point.pos) <= hackRadius then
                StartHack(ply, idx)
                return
            end
        end
    end)


    -- Function to close the hacking UI and cleanup (called on stop or complete)
    local function CloseHackUI()
        if IsValid(hackFrame) then
            hackFrame:Close()
        end
        hackFrame = nil
        hackActive = false
    end

    -- Listen for server instructing hack start
    net.Receive("StartHack", function()
        local pointIndex = net.ReadUInt(8)  -- which point is being hacked (not strictly needed for UI display)
        if hackActive then
            -- If somehow already active, avoid opening another
            CloseHackUI()
        end
        hackActive = true

        -- Create the Derma frame for the hacking interface
        hackFrame = vgui.Create("DFrame")
        hackFrame:SetSize(700, 500)
        hackFrame:SetTitle("HACKING DEVICE - ACCESS TERMINAL")  -- custom title
        hackFrame:SetVisible(true)
        hackFrame:SetDraggable(true)
        hackFrame:ShowCloseButton(true)  -- this will show the close button (and possibly minimize/maximize by default):contentReference[oaicite:13]{index=13}
        hackFrame:Center()
        hackFrame:MakePopup()

        -- Customize the appearance of the frame to resemble a CMD window
        hackFrame.Paint = function(self, w, h)
            -- Draw solid black background for the frame
            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 255))
            -- Draw the title text in green on black (to mimic old console title)
            draw.SimpleText(self:GetTitle(), "DermaDefault", w/2, 8, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER)
        end

        -- Access the default close button and override its behavior to cancel hack
        if IsValid(hackFrame.btnClose) then
            hackFrame.btnClose:SetVisible(true)
            hackFrame.btnClose:SetText("")  -- remove default text (the skin might draw an X icon by default)
            hackFrame.btnClose.DoClick = function()
                -- Send cancellation request to server
                net.Start("StopHack")
                net.SendToServer()
                -- Close the UI
                CloseHackUI()
            end
            -- Customize close button look (draw a red [X])
            hackFrame.btnClose.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(200, 60, 60) or Color(150, 50, 50)
                draw.RoundedBox(0, 0, 0, w, h, bgColor)
                draw.SimpleText("X", "DermaDefault", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Create a minimize button (simulate a Windows-style minimize)
        local btnMinimize = vgui.Create("DButton", hackFrame)
        btnMinimize:SetText("")
        btnMinimize:SetSize(24, 24)
        -- Position it to the left of the close button
        btnMinimize:SetPos(hackFrame:GetWide() - 24*2 - 5, 0)  -- 5px padding from close
        btnMinimize.DoClick = function()
            -- Minimize: just hide the frame (and show a notification maybe)
            hackFrame:SetVisible(false)
            -- We won't fully close; user can press E again to bring back? (optional)
        end
        btnMinimize.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 100, 100) or Color(70, 70, 70)
            draw.RoundedBox(0, 0, 0, w, h, bgColor)
            draw.SimpleText("_", "DermaDefault", w/2, h/2 - 2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Create RichText control for the console output
        local console = vgui.Create("RichText", hackFrame)
        console:SetSize(hackFrame:GetWide() - 20, hackFrame:GetTall() - 60)
        console:SetPos(10, 30)
        console:SetVerticalScrollbarEnabled(true)  -- enable scroll bar for text:contentReference[oaicite:14]{index=14}
        -- Make the console text appear in green on black background
        console.PerformLayout = function(self)
            self:SetFontInternal("HackDeviceFont")
            self:SetFGColor(Color(0, 255, 0))
        end

        -- Create a progress bar at the bottom to show hacking progress
        local progressBar = vgui.Create("DPanel", hackFrame)
        progressBar:SetSize(hackFrame:GetWide() - 20, 20)
        progressBar:SetPos(10, hackFrame:GetTall() - 30)
        progressBar.Progress = 0  -- custom field to store progress fraction (0.0 to 1.0)
        progressBar.Paint = function(self, w, h)
            -- Draw background of progress bar (dark gray)
            draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 255))
            -- Draw the filled part (green)
            local pw = math.Clamp(w * self.Progress, 0, w)
            draw.RoundedBox(0, 0, 0, pw, h, Color(0, 255, 0, 255))
            -- Optional: draw percentage text
            draw.SimpleText(math.floor(self.Progress * 100) .. "%", "DermaDefault", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Show the frame (if it was hidden from minimize, ensure visible now)
        hackFrame:SetVisible(true)

        -- Set up key press handling: if player presses E while UI focused, treat as cancel
        hackFrame.OnKeyCodePressed = function(self, keyCode)
            if keyCode == KEY_E then
                -- Emulate pressing the close button (cancel)
                if IsValid(self.btnClose) then
                    self.btnClose:DoClick()
                end
            end
        end

        -- Start the hacking log simulation
        local startTime = CurTime()
        local nextLogTime = 0
        -- Lists of fake hacking log lines for variety
        local scanLogs = {
            "Connecting to remote host... ", 
            "Scanning open ports...", 
            "Port 22 open (SSH)", 
            "Port 80 open (HTTP)", 
            "Port 445 open (SMB)", 
            "Enumerating services...", 
            "OS: Windows 10 Enterprise x64", 
            "Discovered vulnerable service on port 445 (SMB)"
        }
        local exploitLogs = {
            "Launching exploit for MS17-010 (EternalBlue)...", 
            "Sending crafted packets...", 
            "Heap spray in progress...", 
            "Executing shellcode...", 
            "Remote code execution successful!", 
            "Gaining administrator privileges...", 
            "Privilege escalation successful (NT AUTHORITY\\SYSTEM)"
        }
        local dataLogs = {
            "Dumping SAM database...", 
            "Admin hash: 5f4dcc3b5aa765d61d8327deb882cf99", 
            "User hash: e99a18c428cb38d5f260853678922e03", 
            "Downloading sensitive files...", 
            "Downloading secret_docs.zip (1.2 MB)...", 
            "File downloaded: secret_docs.zip", 
            "Extracting files...", 
            "File contents: TopSecret.pdf, passwords.txt"
        }
        local postLogs = {
            "Installing backdoor...", 
            "Backdoor installed at C:\\Windows\\system32\\svchost.exe", 
            "Cleaning up logs...", 
            "Clearing Windows Event Logs...", 
            "Event Logs cleared", 
            "Disabling antivirus...", 
            "Antivirus disabled", 
            "Establishing persistence (registry run key)...", 
            "Persistence established"
        }
        local finalLogs = {
            "Hack complete. System compromised.", 
            "Disconnecting from target..."
        }

        -- Function to append a line to the console log
        local function AppendLogLine(text)
            console:AppendText(text .. "\n")
            console:GotoTextEnd()  -- auto-scroll to bottom for each new line:contentReference[oaicite:15]{index=15}
        end

        -- Set up a timer to output log lines periodically
        timer.Create("HackLogTimer", logInterval, 0, function()
            if not IsValid(hackFrame) or not hackActive then
                timer.Remove("HackLogTimer")
                return
            end
            local elapsed = CurTime() - startTime
            local fraction = math.Clamp(elapsed / hackDuration, 0, 1)
            -- Update progress bar
            progressBar.Progress = fraction
            -- Determine which category of log to display based on elapsed time
            if fraction < 0.25 then
                -- Scanning phase
                local line = scanLogs[math.random(#scanLogs)]
                AppendLogLine(line)
            elseif fraction < 0.5 then
                -- Exploitation phase
                local line = exploitLogs[math.random(#exploitLogs)]
                AppendLogLine(line)
            elseif fraction < 0.75 then
                -- Data extraction phase
                local line = dataLogs[math.random(#dataLogs)]
                AppendLogLine(line)
            elseif fraction < 0.95 then
                -- Post-exploitation phase
                local line = postLogs[math.random(#postLogs)]
                AppendLogLine(line)
            else
                -- Final phase (almost done)
                if #finalLogs > 0 then
                    AppendLogLine(finalLogs[1])
                    table.remove(finalLogs, 1)  -- remove the line after printing
                end
            end

            -- If hack duration completed, stop the timer (the server will send completion net message)
            if fraction >= 1 then
                timer.Remove("HackLogTimer")
            end
        end)
    end)

    -- Listen for server instructing hack completion (success)
    net.Receive("CompleteHack", function()
        if hackActive and IsValid(hackFrame) then
            -- Optionally, append a final success message
            -- (If not already shown in finalLogs)
            console:AppendText("ACCESS GRANTED. Terminal unlocked.\n")
            console:GotoTextEnd()
            -- Close the UI a moment later to allow player to see the message
            timer.Simple(1, function()
                CloseHackUI()
            end)
        end
    end)

    -- Listen for server instructing to stop/cancel the hack
    net.Receive("StopHack", function()
        if hackActive then
            CloseHackUI()
        end
    end)
end
