--=================--
local libTabMenu = {}
--=================--

-- < Modules > --
local table2 = require "table2"

-- < References > --
local constTabMenu = require "constTabMenu"



--====================================================--
-- class tabMenuEntry                                 --
-- Contains all customizable properties of one entry. --
--====================================================--
libTabMenu.tabMenuEntry = setmetatable({
    Name = "New Tab Menu Entry",

    --== Text ==--
    Label = "",  -- Text shown on tab button
    Title = "",  -- Title text
    Desc1 = "",  -- Text in left description box
    Desc2 = "",  -- Text in right description box

    --=============--
    -- Constructor --
    --=============--
    new = function(self, o)
        o = o or {}
        setmetatable(o, {__index = self})
        return o
    end,
    },{
    
    --===========--
    -- Metatable --
    --===========--

})



--===============================================--
-- class tabMenu                                 --
-- Handles creating and updating TabMenu Frames. --
--===============================================--
libTabMenu.tabMenu = setmetatable({
    Name = "New Tab Menu",

    --== Auto-Update Functionality On Change ==--
    Entries   = {},     -- tabMenuEntry class objects
    BoardMode = false,  -- If game has a leaderboard, set this to true, to avoid blocking X button.

    --== Read-Only ==--
    Frame,                -- Framehandle for main parent frame
    ButtonCurrent,        -- Number of currently clicked tab button (0 to 4). Can be negative due to tab slider position.
    EntryCurrent,         -- The table key into Entries to get the entry currently selected by tab buttons.
    EntryCount,           -- Size of Entries array. (not the supaTable proxy)
    CloseButtonTrig,      -- Trigger to hide frame when close button is clicked
    TabSliderTrig,        -- Trigger to scroll tab buttons with slider
    TabButtonTrigs = {},  -- Triggers to update text when tab buttons are clicked
    TabPosOffset   = 0,   -- How much the width of first tab is adjusted to simulate scrolling
    TabSkip        = 0,   -- Number of tabs scrolled past with slider, starting from 0.
    
    --=============--
    -- Constructor --
    --=============--
    new = function(self, o)
        o = o or {}

        -- Init default params and methods --
        o.Entries        = o.Entries        or {}
        o.TabButtonTrigs = o.TabButtonTrigs or {}

        o.EntryCount = 0
        for k, v in pairs(o.Entries) do o.EntryCount = o.EntryCount + 1 end

        o.Frame = BlzCreateFrame("TabMenu", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        BlzFrameSetAbsPoint(o.Frame, FRAMEPOINT_TOPLEFT, 0.02, 0.553)
        
        setmetatable(o, {__index = self})

        -- This class is a supaTable --
        local tbl = table2.supaTable:new(o)

        -- Set read-only properties (supaTable) --
        tbl:setReadOnly(true, "Frame")
        tbl:setReadOnly(true, "ButtonCurrent")
        tbl:setReadOnly(true, "EntryCurrent")
        tbl:setReadOnly(true, "EntryCount")
        tbl:setReadOnly(true, "TabSliderTrig")
        tbl:setReadOnly(true, "TabButtonTrigs")
        tbl:setReadOnly(true, "TabPosOffset")
        tbl:setReadOnly(true, "TabSkip")

        -- Auto-update frame (supaTable) --
        tbl:watchProp(function(t,k,v)
            local tbl0 = getmetatable(tbl).__index  --set read-only prop (supaTable)
            local tblEntries = getmetatable(tbl.Entries).__index  --get array size of actual table, not metatable proxy

            tbl0.EntryCount = 0
            for k, v in pairs(tblEntries) do
                tbl0.EntryCount = tbl0.EntryCount + 1 end
            
            tbl:updateTabLabels()
            tbl:updateTabCount()
            tbl:updateTabSlider()
            tbl:updateText()
        end, "Entries", true)

        tbl:watchProp(function(t,k,v)
            tbl:updateCloseButtonPos()
        end, "BoardMode", false)

        -- Main --
        tbl:updateCloseButtonPos()
        tbl:updateTabLabels()
        tbl:updateTabCount()
        tbl:updateTabSlider()
        tbl:initTabSliderTrig()
        tbl:initTabButtonTrigs()
        tbl:initCloseButtonTrig()

        -- Return --
        return tbl
    end,

    --<< PRIVATE METHODS >>--
    --=================================================--
    -- tabMenu:updateCloseButtonPos()                  --
    --                                                 --
    -- Positions CloseButton, TabBar, and TabBarSlider --
    -- to be compatible with BoardMode.                --
    --=================================================--
    updateCloseButtonPos = function(self)
        local closeButton = BlzFrameGetChild(self.Frame, 1)
        local tabBar      = BlzFrameGetChild(self.Frame, 2)
        local tabSlider   = BlzFrameGetChild(self.Frame, 3)

        local closeButtonY = -constTabMenu.borderSize
        local tabBarY      = -constTabMenu.borderSize
        local tabSliderY   = -constTabMenu.borderSize - (constTabMenu.menuSize * constTabMenu.tabBarHeight)

        if (self.BoardMode == false) then
            local closeButtonX = (constTabMenu.menuSize * constTabMenu.tabBarWidth) + constTabMenu.borderSize
            local tabBarX      = constTabMenu.borderSize
            local tabSliderX   = tabBarX
            BlzFrameSetPoint(closeButton, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, closeButtonX, closeButtonY)
            BlzFrameSetPoint(tabBar, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, tabBarX, tabBarY)
            BlzFrameSetPoint(tabSlider, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, tabSliderX, tabSliderY)
        else
            local closeButtonX = constTabMenu.borderSize
            local tabBarX      = (constTabMenu.menuSize * constTabMenu.closeButtonWidth) + constTabMenu.borderSize
            local tabSliderX   = tabBarX
            BlzFrameSetPoint(closeButton, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, closeButtonX, closeButtonY)
            BlzFrameSetPoint(tabBar, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, tabBarX, tabBarY)
            BlzFrameSetPoint(tabSlider, FRAMEPOINT_TOPLEFT, self.Frame, FRAMEPOINT_TOPLEFT, tabSliderX, tabSliderY)
        end
    end,

    --==============================================--
    -- tabMenu:updateTabLabels()                    --
    --                                              --
    -- Updates tab labels to corresponding entries. --
    --==============================================--
    updateTabLabels = function(self)
        local tabBar = BlzFrameGetChild(self.Frame, 2)
        local tabFrameIndex  = 0
        local skippedEntries = 0

        for k, v in table2.pairsByKeys(self.Entries) do
            if (skippedEntries < self.TabSkip) then
                skippedEntries = skippedEntries + 1
            else
                local tab = BlzFrameGetChild(tabBar, tabFrameIndex)
                BlzFrameSetText(tab, v.Label)
                tabFrameIndex = tabFrameIndex + 1
                if (tabFrameIndex > 4) then break end
            end
        end
    end,

    --=================================================--
    -- tabMenu:updateTabCount()                        --
    --                                                 --
    -- If less than 5 entries, hides some tab buttons. --
    --=================================================--
    updateTabCount = function(self)
        local tabBar = BlzFrameGetChild(self.Frame, 2)

        for i=1, math.min(5, self.EntryCount) do
            local tab = BlzFrameGetChild(tabBar, i-1)
            BlzFrameSetVisible(tab, true)
        end

        for i=(self.EntryCount+1), 5 do
            local tab = BlzFrameGetChild(tabBar, i-1)
            BlzFrameSetVisible(tab, false)
        end
    end,

    --=========================================--
    -- tabMenu:updateTabSlider()               --
    --                                         --
    -- If less than 5 entries, hide tab slider --
    -- and reset tab width and position.       --
    --=========================================--
    updateTabSlider = function(self)
        local tabBar    = BlzFrameGetChild(self.Frame, 2)
        local tabSlider = BlzFrameGetChild(self.Frame, 3)
        local tabWidth  = constTabMenu.menuSize * constTabMenu.tabWidth
        local tabHeight = constTabMenu.menuSize * constTabMenu.tabHeight

        if (self.EntryCount < 5) then
            BlzFrameSetVisible(tabSlider, false)
            BlzFrameSetValue(tabSlider, 0)

            for i=1, 4 do
                local tab = BlzFrameGetChild(tabBar, i-1)
                local tabPosX = tabWidth * (i-1)
                BlzFrameSetSize(tab, tabWidth, tabHeight)
                BlzFrameSetPoint(tab, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX, 0)
            end

            local tab4 = BlzFrameGetChild(tabBar, 4)
            local tabPosX4 = tabWidth * 4
            BlzFrameSetSize(tab4, 0, tabHeight)
            BlzFrameSetPoint(tab4, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX4, 0)
            
        else
            BlzFrameSetVisible(tabSlider, true)
        end
    end,

    --================================================--
    -- tabMenu:updateText()                           --
    --                                                --
    -- Updates text to show currently selected Entry. --
    --================================================--
    updateText = function(self)   
        if (self.EntryCurrent == nil) then return end

        local textTitle     = BlzFrameGetChild(BlzFrameGetChild(self.Frame, 4), 1)
        local textLeftBody  = BlzFrameGetChild(BlzFrameGetChild(self.Frame, 5), 1)
        local textRightBody = BlzFrameGetChild(BlzFrameGetChild(self.Frame, 6), 1)

        BlzFrameSetText(textTitle, self.Entries[self.EntryCurrent].Title)
        BlzFrameSetText(textLeftBody, self.Entries[self.EntryCurrent].Desc1)
        BlzFrameSetText(textRightBody, self.Entries[self.EntryCurrent].Desc2)
    end,

    --=========================================================--
    -- tabMenu:initTabSliderTrig()                             --
    --                                                         --
    -- Updates trigger for scrolling through tabs with slider. --
    --=========================================================--
    initTabSliderTrig = function(self)
        local tbl = getmetatable(self).__index  --Used to set read-only props (supaTable)

        local tabBar    = BlzFrameGetChild(self.Frame, 2)
        local tabSlider = BlzFrameGetChild(self.Frame, 3)
        
        local tab0 = BlzFrameGetChild(tabBar, 0)
        local tab1 = BlzFrameGetChild(tabBar, 1)
        local tab2 = BlzFrameGetChild(tabBar, 2)
        local tab3 = BlzFrameGetChild(tabBar, 3)
        local tab4 = BlzFrameGetChild(tabBar, 4)

        local tabHeight = constTabMenu.menuSize * constTabMenu.tabHeight
        local tabWidth  = constTabMenu.menuSize * constTabMenu.tabWidth
        local minWidth  = 0.02
        
        -- Update tabs every time slider changes --
        local newTrig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(newTrig, tabSlider, FRAMEEVENT_SLIDER_VALUE_CHANGED)
        TriggerAddAction(newTrig, function()
            if (GetLocalPlayer() ~= GetTriggerPlayer()) then return end
            if (self.EntryCount < 5) then return end

            -- Update read-only properties (supaTable) --
            local oldTabSkip = self.TabSkip
            local sliderValue = BlzGetTriggerFrameValue()
            local sliderRangePerTab = constTabMenu.sliderRange / (self.EntryCount - 4)
            tbl.TabPosOffset = tabWidth * ((sliderValue % sliderRangePerTab) / sliderRangePerTab)
            tbl.TabSkip = math.floor(sliderValue / sliderRangePerTab)

            -- If scrolled to a new button --
            if (self.TabSkip ~= oldTabSkip) then
                self:updateTabLabels()

                -- Update current selected button --
                if (self.ButtonCurrent ~= nil) then
                    local oldButtonNum = self.ButtonCurrent
                    tbl.ButtonCurrent  = self.ButtonCurrent + oldTabSkip - self.TabSkip
                end
            end

            -- Vertically indent currently selected button --
            local tabHeight0 = (self.ButtonCurrent == 0) and (tabHeight + constTabMenu.tabSelectIndent) or tabHeight
            local tabHeight1 = (self.ButtonCurrent == 1) and (tabHeight + constTabMenu.tabSelectIndent) or tabHeight
            local tabHeight2 = (self.ButtonCurrent == 2) and (tabHeight + constTabMenu.tabSelectIndent) or tabHeight
            local tabHeight3 = (self.ButtonCurrent == 3) and (tabHeight + constTabMenu.tabSelectIndent) or tabHeight
            local tabHeight4 = (self.ButtonCurrent == 4) and (tabHeight + constTabMenu.tabSelectIndent) or tabHeight

            local tabPosY0 = (self.ButtonCurrent == 0) and constTabMenu.tabSelectIndent or 0
            local tabPosY1 = (self.ButtonCurrent == 1) and constTabMenu.tabSelectIndent or 0
            local tabPosY2 = (self.ButtonCurrent == 2) and constTabMenu.tabSelectIndent or 0
            local tabPosY3 = (self.ButtonCurrent == 3) and constTabMenu.tabSelectIndent or 0
            local tabPosY4 = (self.ButtonCurrent == 4) and constTabMenu.tabSelectIndent or 0

            -- Adjust width and position of tabs to simulate scrolling --
            local tabWidth0 = tabWidth - self.TabPosOffset
            local tabWidth1 = tabWidth
            local tabWidth2 = tabWidth
            local tabWidth3 = tabWidth
            local tabWidth4 = self.TabPosOffset
            
            local tabPosX0 = 0
            local tabPosX1 = tabWidth0
            local tabPosX2 = tabWidth0 + tabWidth1
            local tabPosX3 = tabWidth0 + tabWidth1 + tabWidth2
            local tabPosX4 = tabWidth0 + tabWidth1 + tabWidth2 + tabWidth3

            BlzFrameSetSize(tab0, tabWidth0, tabHeight0)
            BlzFrameSetSize(tab1, tabWidth1, tabHeight1)
            BlzFrameSetSize(tab2, tabWidth2, tabHeight2)
            BlzFrameSetSize(tab3, tabWidth3, tabHeight3)
            BlzFrameSetSize(tab4, tabWidth4, tabHeight4)

            BlzFrameSetPoint(tab0, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX0, tabPosY0)
            BlzFrameSetPoint(tab1, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX1, tabPosY1)
            BlzFrameSetPoint(tab2, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX2, tabPosY2)
            BlzFrameSetPoint(tab3, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX3, tabPosY3)
            BlzFrameSetPoint(tab4, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, tabPosX4, tabPosY4)

            --- Hide tabs if too small, to avoid display quirks --
            if (tabWidth0 < minWidth) then
                BlzFrameSetVisible(tab0, false)
            else
                BlzFrameSetVisible(tab0, true)
            end

            if (tabWidth4 < minWidth) then
                BlzFrameSetVisible(tab4, false)
            else
                BlzFrameSetVisible(tab4, true)
            end
        end)

        -- Clean up old trigger and replace it with new trigger --
        if (self.TabSliderTrig ~= nil) then
            DestroyTrigger(self.TabSliderTrig) end
        tbl.TabSliderTrig = newTrig
    end,

    
    --================================================================--
    -- tabMenu:initTabButtonTrigs()                                   --
    --                                                                --
    -- Update triggers that change text when tab buttons are clicked. --
    --================================================================--
    initTabButtonTrigs = function(self)
        local tabBar = BlzFrameGetChild(self.Frame, 2)

        -- Used to set read-only props (supaTable) --
        local tbl = getmetatable(self).__index
        local tblTrigs = getmetatable(self.TabButtonTrigs).__index
        local tblEntries = getmetatable(self.Entries).__index
        
        for i=1, 5 do  -- Clean up old trigger --
            if (self.TabButtonTrigs[i] ~= nil) then
                DestroyTrigger(self.TabButtonTrigs[i])
            end

            -- Create new trigger that runs on button click --
            local tabButton = BlzFrameGetChild(tabBar, i-1)
            tblTrigs[i] = CreateTrigger()
            BlzTriggerRegisterFrameEvent(self.TabButtonTrigs[i], tabButton, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(self.TabButtonTrigs[i], function()
                if (GetLocalPlayer() ~= GetTriggerPlayer()) then return end
                local buttonNum = i - 1

                -- Traverse Entries in order of keys. EntryCurrent = TabSkip + i --
                local skippedEntries = 0
                local buttonIndex    = 0
                for k, v in table2.pairsByKeys(tblEntries) do
                    if (skippedEntries < self.TabSkip) then
                        skippedEntries = skippedEntries + 1
                    else
                        buttonIndex = buttonIndex + 1
                        if (buttonIndex >= i) then
                            tbl.EntryCurrent = k
                            break
                        end
                    end
                end

                -- Update displayed text --
                self:updateText()

                -- Indent clicked button --
                local tabWidth  = constTabMenu.menuSize * constTabMenu.tabWidth
                local tabHeight = constTabMenu.menuSize * constTabMenu.tabHeight
                local newTabHeight = tabHeight + constTabMenu.tabSelectIndent
                local newTabPosY   = constTabMenu.tabSelectIndent

                local newTabWidth  = tabWidth
                if     (i == 1) then newTabWidth = tabWidth - self.TabPosOffset
                elseif (i == 5) then newTabWidth = self.TabPosOffset end

                local newTabPosX = 0
                if (i == 2) then newTabPosX = tabWidth - self.TabPosOffset end
                if (i > 2)  then newTabPosX = (tabWidth - self.TabPosOffset) + (tabWidth * (i-2)) end

                BlzFrameSetSize(tabButton, newTabWidth, newTabHeight)
                BlzFrameSetPoint(tabButton, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, newTabPosX, newTabPosY)

                -- Unindent previously clicked button --
                local buttonPrev = tbl.ButtonCurrent
                if (buttonPrev ~= nil) then
                    local prevTabButton = BlzFrameGetChild(tabBar, buttonPrev)

                    local prevTabPosX = 0
                    if (buttonPrev == 1) then prevTabPosX = tabWidth - self.TabPosOffset end
                    if (buttonPrev > 1)  then prevTabPosX = (tabWidth - self.TabPosOffset) + (tabWidth * (buttonPrev-1)) end
                    
                    BlzFrameSetSize(prevTabButton, tabWidth, tabHeight)
                    BlzFrameSetPoint(prevTabButton, FRAMEPOINT_TOPLEFT, tabBar, FRAMEPOINT_TOPLEFT, prevTabPosX, 0)
                end

                -- Clear keyboard focus --
                BlzFrameSetEnable(tabButton, false)
                BlzFrameSetEnable(tabButton, true)

                -- Update current button --
                tbl.ButtonCurrent = i-1
            end)
        end
    end,

    --===============================================================--
    -- tabMenu:initCloseButtonTrig()                                 --
    --                                                               --
    -- Update trigger that hides frame when close button is clicked. --
    --===============================================================--
    initCloseButtonTrig = function(self)
        local xButton = BlzFrameGetChild(self.Frame, 1)
        local tabBar  = BlzFrameGetChild(self.Frame, 2)

        local newTrig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(newTrig, xButton, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(newTrig, function()
            if (GetLocalPlayer() ~= GetTriggerPlayer()) then return end
            BlzFrameSetVisible(self.Frame, false)
        end)

        -- Clean up old trigger and replace it with new trigger --
        if (self.CloseButtonTrig ~= nil) then
            DestroyTrigger(self.CloseButtonTrig) end
        getmetatable(self).__index.CloseButtonTrig = newTrig  --Set read-only prop (supaTable)
    end,
    },{
    
    --===========--
    -- Metatable --
    --===========--

})



--=============--
return libTabMenu
--=============--
