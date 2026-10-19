PTNewCustomGroup = PTGuiComponent:Extend("puppeteer_new_custom_group")

function PTNewCustomGroup:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)

    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("New Custom Group")
    obj:AddComponent("Title", title)

    local nameLabel = PTGuiLib.GetText(frame, "Group Name")
        :SetPoint("RIGHT", frame, "TOPLEFT", 115, -35)
    local nameEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", nameLabel, "RIGHT", 5, 0)
        :SetSize(150, 20)
        :SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
    obj:AddComponent("NameEditbox", nameEditbox)

    local cancelButton = PTGuiLib.Get("button", frame)
        :SetText("Cancel")
        :SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
        :SetSize(150, 20)
        :OnClick(function()
            PTSettingsGui.PopOverlayFrame()
            obj:Dispose()
        end)
    cancelButton:SetClickSound(PlaySound, "igMainMenuClose")

    local createButton = PTGuiLib.Get("button", frame)
        :SetText("Create Group")
        :SetPoint("BOTTOM", cancelButton, "TOP", 0, 5)
        :SetSize(150, 20)
        :OnClick(function()
            local _, _, name = string.find(nameEditbox:GetText(), "^%s*(.-)%s*$")
            local group, err = Puppeteer.CreateCustomGroup(name)
            if not group then
                if err then
                    Puppeteer.Info(err)
                end
                return
            end
            Puppeteer.Info("Created \""..name.."\". Add people with the \"Custom Groups\" binding or /pt group add "..name)
            PTSettingsGui.SelectFrameGroup(name)
            PTSettingsGui.PopOverlayFrame()
            obj:Dispose()
        end)
    createButton:SetClickSound(PlaySound, "igMainMenuClose")

    return obj
end

function PTNewCustomGroup:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(300, 120)
    self:GetNameEditbox():SetText("")
end

PTNewCustomGroup:CreateGetter("NameEditbox")

PTGuiLib.RegisterComponent(PTNewCustomGroup)
