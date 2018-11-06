require "graphics"
require "math"

local tmpStr = ""

dataref("b2pt_agl", "sim/flightmodel/position/y_agl")
dataref("b2pt_dist", "sim/flightmodel/controls/dist")

local snapMainX = SCREEN_WIDTH - 225
local snapMainY = SCREEN_HIGHT - 25
local mainX = snapMainX
local mainY = snapMainY
local bDrawControlBox = false
local bDragging = false
local bScreenSizeChanged = true
local bAutoPosition = true


local b2pt_SoftwareVersion = 1
local b2pt_pauseTimerActive = false
local b2pt_epochTimePause = 0
local b2pt_pauseAltActive = false
local b2pt_aglToPause = 0               -- in feet
local b2pt_pauseDistActive = false
local b2pt_distToPause = 0              -- in nm
local b2pt_bWeCausedPause = false

local b2pt_currentTimeX1 = 0
local b2pt_currentTimeY1 = 0
local b2pt_currentTimeX2 = 0
local b2pt_currentTimeY2 = 0
local b2pt_pauseTimeX1 = 0
local b2pt_pauseTimeY1 = 0
local b2pt_pauseTimeX2 = 0
local b2pt_pauseTimeY2 = 0

local b2pt_minUntilPauseX1 = 0
local b2pt_minUntilPauseY1 = 0
local b2pt_minUntilPauseX2 = 0
local b2pt_minUntilPauseY2 = 0

local b2pt_aglX1 = 0
local b2pt_aglY1 = 0
local b2pt_aglX2 = 0
local b2pt_aglY2 = 0

local b2pt_distX1 = 0
local b2pt_distY1 = 0
local b2pt_distX2 = 0
local b2pt_distY2 = 0

local b2pt_apDisconnectEnabled = false
local b2pt_apDisconnectActive = false
local b2pt_apDiscoX1 = 0
local b2pt_apDiscoY1 = 0
local b2pt_apDiscoX2 = 0
local b2pt_apDiscoY2 = 0

local b2pt_fuelFlowActive = false
local b2pt_fuelFlow = {false,false,false,false,false,false,false,false} -- 8 engines
local b2pt_ffX1 = 0
local b2pt_ffY1 = 0
local b2pt_ffX2 = 0
local b2pt_ffY2 = 0
local b2pt_minFuelFlow = 0.00001

local b2pt_stallWarningActive = false
local b2pt_stallWarningX1 = 0
local b2pt_stallWarningY1 = 0
local b2pt_stallWarningX2 = 0
local b2pt_stallWarningY2 = 0


do_every_draw("B2PauseTimer_everyDraw()")
do_on_mouse_wheel("B2PauseTimer_onMouseWheel()")
do_on_mouse_click("B2PauseTimer_mouseClick()")
do_often("B2PauseTimer_everySec()")


--  0/255,0/255,0/255      -- black
--  211/255,10/255,10/255  -- red
--  56/255,181/255,74/255  -- green
--  71/255,71/255,70/255   -- grey

function B2PauseTimer_Meter2Feet(meter)
    return meter * 3.28084
end

function B2PauseTimer_Meter2NM(meter)
    return meter * 0.000539957
end

function B2PauseTimer_NM2Meter(nm)
    return nm * 1852
end

function B2PauseTimer_SetColor(colorNum)
    if     (colorNum == 1) then graphics.set_color(0/255,0/255,0/255,0.8)  -- black
    elseif (colorNum == 2) then graphics.set_color(211/255,10/255,10/255,0.8) -- red
    elseif (colorNum == 3) then graphics.set_color(102/255,102/255,102/255,1)  -- grey40
    elseif (colorNum == 4) then graphics.set_color(0/255,0/255,0/255,1)  -- black
    elseif (colorNum == 5) then graphics.set_color(255/255,255/255,255/255,0.5)  -- white
    elseif (colorNum == 6) then graphics.set_color(140/255,128/255,99/255,0.8)  -- fill in color
    elseif (colorNum == 7) then graphics.set_color(140/255,128/255,99/255,1)  -- fill in color
    elseif (colorNum == 8) then graphics.set_color(66/255, 66/255, 66/255, 1) -- dark gray
    else                        graphics.set_color(71/255,71/255,70/255,0.05)  -- grey and default
    end
end

function B2PauseTimer_DrawHorizontal(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(0) end
    pixW = math.ceil(pixW)
    pixH = math.ceil(pixH)
    graphics.draw_rectangle(x+pixH,y+pixH,x+pixW-pixH,y-pixH)
    graphics.draw_triangle(x,y,x+pixH,y+pixH,x+pixH,y-pixH)
    graphics.draw_triangle(x+pixW,y,x+pixW-pixH,y-pixH,x+pixW-pixH,y+pixH)
end

function B2PauseTimer_DrawVertical(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(0) end
    pixW = math.ceil(pixW)
    pixH = math.ceil(pixH)
    graphics.draw_rectangle(x-pixW,y-pixW,x+pixW,y-pixH+pixW)
    graphics.draw_triangle(x,y,x+pixW,y-pixW,x-pixW,y-pixW)
    graphics.draw_triangle(x-pixW,y-pixH+pixW,x+pixW,y-pixH+pixW,x,y-pixH)
end

function B2PauseTimer_DrawNumber(x,y,cumW,cumH,num,colorNum)
    local index = (num % 10) + 1  -- to adjust num to array index

    local data = { {true,  false, true,  true,  true,  true,  true},  -- 0 [1]
                   {false, false, false, false, true,  false, true},  -- 1 [2]
                   {true,  true,  true,  false, true,  true,  false}, -- 2  .
                   {true,  true,  true,  false, true,  false, true},  -- 3  .
                   {false, true,  false, true,  true,  false, true},  -- 4  .
                   {true,  true,  true,  true,  false, false, true},  -- 5  .
                   {true,  true,  true,  true,  false, true,  true},  -- 6  .
                   {true,  false, false, false, true,  false, true},  -- 7  .
                   {true,  true,  true,  true,  true,  true,  true},  -- 8  .
                   {true,  true,  true,  true,  true,  false, true}   -- 9  .
                   }
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.05*cumH),cumW*0.75,cumH*0.02,data[index][1],colorNum)
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.50*cumH),cumW*0.75,cumH*0.02,data[index][2],colorNum)
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.95*cumH),cumW*0.75,cumH*0.02,data[index][3],colorNum)

    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][4],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.85*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][5],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][6],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.85*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][7],colorNum)
end

function B2PauseTimer_DrawDot(x,y,pixW,pixH,colorNum)
    B2PauseTimer_SetColor(colorNum)
    graphics.draw_triangle(x-pixW,y,x,y+pixH,x+pixW,y)
    graphics.draw_triangle(x-pixW,y,x+pixW,y,x,y-pixH)
end

function B2PauseTimer_DrawDots(x,y,cumW,cumH,colorNum)
    B2PauseTimer_DrawDot(x+(0.50*cumW),y-(0.25*cumH),cumW*0.35,cumW*0.35,colorNum)
    B2PauseTimer_DrawDot(x+(0.50*cumW),y-(0.75*cumH),cumW*0.35,cumW*0.35,colorNum)
end

function B2PauseTimer_DrawTime(hr,m,x,y,oWdth,oHgt,bTimer)
    local cWdth = math.floor(oWdth / 4.25)
    local colorNum = 1
    if (b2pt_pauseTimerActive and bTimer) then
        colorNum = 2
    end

    B2PauseTimer_DrawNumber(x+(cWdth*0.0),y,cWdth,oHgt,math.floor(hr/10),colorNum)  
    B2PauseTimer_DrawNumber(x+(cWdth*1.0),y,cWdth,oHgt,hr % 10,colorNum)            
    if (os.time() % 2 == 1) then
        B2PauseTimer_DrawDots  (x+(cWdth*2.0),y,cWdth*0.25,oHgt,0)          
    else
        B2PauseTimer_DrawDots  (x+(cWdth*2.0),y,cWdth*0.25,oHgt,colorNum)
    end
    B2PauseTimer_DrawNumber(x+(cWdth*2.25),y,cWdth,oHgt,math.floor(m/10),colorNum)   
    B2PauseTimer_DrawNumber(x+(cWdth*3.25),y,cWdth,oHgt,m % 10,colorNum)                         
end

function B2PauseTimer_DrawAlt(alt,x,y,oWdth,oHgt)
    local colorNum = 1
    local cWdth = math.floor(oWdth / 5)
    if (alt < 0) then alt = 0 end
    if (alt > 99999) then alt = 99999 end

    if (b2pt_pauseAltActive) then colorNum = 2 end 

    B2PauseTimer_DrawNumber(x+(cWdth*0),y,cWdth,oHgt,math.floor((alt%100000)/10000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*1),y,cWdth,oHgt,math.floor((alt%10000)/1000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*2),y,cWdth,oHgt,math.floor((alt%1000)/100),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*3),y,cWdth,oHgt,math.floor((alt%100)/10),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*4),y,cWdth,oHgt,math.floor((alt%10)/1),colorNum)
end

function B2PauseTimer_DrawDist(dist,x,y,oWdth,oHgt)
    -- dist given in nm
    local nm = math.ceil(dist) -- round up
    local colorNum = 1
    local cWdth = math.floor(oWdth / 5)
    if (nm < 0) then nm = 0 end
    if (nm > 9999) then nm = 9999 end

    if (b2pt_pauseDistActive) then colorNum = 2 end 

    B2PauseTimer_DrawNumber(x+(cWdth*1),y,cWdth,oHgt,math.floor((nm%10000)/1000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*2),y,cWdth,oHgt,math.floor((nm%1000)/100),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*3),y,cWdth,oHgt,math.floor((nm%100)/10),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*4),y,cWdth,oHgt,math.floor((nm%10)/1),colorNum)
end

function B2PauseTimer_DrawToggleBox(x,y,oWdth,oHgt,active)
    B2PauseTimer_DrawHorizontal(x+(0.10*oWdth),y-(0.30*oHgt),oWdth*0.80,oHgt*0.02,true,1)
    B2PauseTimer_DrawHorizontal(x+(0.10*oWdth),y-(0.95*oHgt),oWdth*0.80,oHgt*0.02,true,1)
    B2PauseTimer_DrawVertical  (x+(0.10*oWdth),y-(0.30*oHgt),oWdth*0.03,oHgt*0.65,true,1)
    B2PauseTimer_DrawVertical  (x+(0.90*oWdth),y-(0.30*oHgt),oWdth*0.03,oHgt*0.65,true,1)

    if (active) then B2PauseTimer_SetColor(2) else B2PauseTimer_SetColor(0) end
    graphics.draw_rectangle(x+(0.17*oWdth),y-(0.35*oHgt),x+(0.83*oWdth),y-(0.90*oHgt))
end

function B2PauseTimer_onMouseWheel()
    if (MOUSE_X >= b2pt_pauseTimeX1 and MOUSE_X <= b2pt_pauseTimeX2 and
        MOUSE_Y >= b2pt_pauseTimeY2 and MOUSE_Y <= b2pt_pauseTimeY1) or 
       (MOUSE_X >= b2pt_minUntilPauseX1 and MOUSE_X <= b2pt_minUntilPauseX2 and
        MOUSE_Y >= b2pt_minUntilPauseY2 and MOUSE_Y <= b2pt_minUntilPauseY1) then
        -- mouse wheel over part of 'pause time' or 'time remaining'
        local referenceX = MOUSE_X - b2pt_pauseTimeX1
        if (MOUSE_X >= b2pt_minUntilPauseX1) then 
            referenceX = MOUSE_X - b2pt_minUntilPauseX1
        end
        local timeChange = 0 -- value depends on which number is changing
        local charWidth = (b2pt_pauseTimeX2 - b2pt_pauseTimeX1) / 4.25
        if     (referenceX <= (charWidth*2.00)) then timeChange = 3600  --   1h
        elseif (referenceX <= (charWidth*2.25)) then timeChange = 0     --    :
        else                                         timeChange = 60    --   1m
        end

        local currentTime = os.time()
        if (b2pt_epochTimePause == 0) then                           -- initialization
            b2pt_epochTimePause = math.floor(currentTime/60) * 60
        end

        b2pt_epochTimePause = b2pt_epochTimePause + (MOUSE_WHEEL_CLICKS * timeChange)

        if (b2pt_epochTimePause > currentTime + 86400) then                  -- protect against 24hr rule
            b2pt_epochTimePause = b2pt_epochTimePause - 86400
        elseif (b2pt_epochTimePause < currentTime) then
            b2pt_epochTimePause = b2pt_epochTimePause + 86400
        end
        if ((b2pt_epochTimePause-currentTime) > 120 and (b2pt_epochTimePause-currentTime) <= 86220) then
            b2pt_pauseTimerActive = true
        end

        RESUME_MOUSE_WHEEL = true
    end

    if (MOUSE_X >= b2pt_aglX1 and MOUSE_X <= b2pt_aglX2 and
        MOUSE_Y >= b2pt_aglY2 and MOUSE_Y <= b2pt_aglY1) then 
        -- mouse wheel over part of 'agl'
        if (b2pt_aglToPause == 0) then b2pt_aglToPause = math.floor(B2PauseTimer_Meter2Feet(b2pt_agl)/100)*100 end
        b2pt_aglToPause = math.max(b2pt_aglToPause + (MOUSE_WHEEL_CLICKS * 100),0)
        if (math.abs(b2pt_aglToPause - B2PauseTimer_Meter2Feet(b2pt_agl)) > 250) then b2pt_pauseAltActive = true end
        RESUME_MOUSE_WHEEL = true
    end

    if (MOUSE_X >= b2pt_distX1 and MOUSE_X <= b2pt_distX2 and
        MOUSE_Y >= b2pt_distY2 and MOUSE_Y <= b2pt_distY1) then 
        -- mouse wheel over part of 'distance'
        if (b2pt_distToPause == 0) then b2pt_distToPause = B2PauseTimer_Meter2NM(b2pt_dist) end
        b2pt_distToPause = math.max(b2pt_distToPause + (MOUSE_WHEEL_CLICKS * 10),0)
        if (b2pt_distToPause <= B2PauseTimer_Meter2NM(b2pt_dist)) then               -- no neg values
            b2pt_distToPause = 0
            b2pt_pauseDistActive = false
        elseif (b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist) > 25) then     -- min 25nm
            b2pt_pauseDistActive = true
        end
        RESUME_MOUSE_WHEEL = true
    end
end

function B2PauseTimer_mouseClick()
    if (MOUSE_STATUS == "up") then bDragging = false end

    -- check if position over time
    if (MOUSE_STATUS == "down" and 
        ((MOUSE_X >= b2pt_currentTimeX1 and MOUSE_X <= b2pt_currentTimeX2 and 
          MOUSE_Y >= b2pt_currentTimeY2 and MOUSE_Y <= b2pt_currentTimeY1) or
         (MOUSE_X >= b2pt_pauseTimeX1 and MOUSE_X <= b2pt_pauseTimeX2 and
          MOUSE_Y >= b2pt_pauseTimeY2 and MOUSE_Y <= b2pt_pauseTimeY1) or 
         (MOUSE_X >= b2pt_minUntilPauseX1 and MOUSE_X <= b2pt_minUntilPauseX2 and
          MOUSE_Y >= b2pt_minUntilPauseY2 and MOUSE_Y <= b2pt_minUntilPauseY1))) then
        RESUME_MOUSE_CLICK = true
        -- disable and reset the pause on timer
        b2pt_pauseTimerActive = false
        b2pt_epochTimePause = 0
    end

    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= b2pt_aglX1 and MOUSE_X <= b2pt_aglX2 and
        MOUSE_Y >= b2pt_aglY2 and MOUSE_Y <= b2pt_aglY1) then 
        -- reset and disable the pause on alt
        RESUME_MOUSE_CLICK = true
        b2pt_pauseAltActive = false
        b2pt_aglToPause = 0
    end

    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= b2pt_apDiscoX1 and MOUSE_X <= b2pt_apDiscoX2 and
        MOUSE_Y >= b2pt_apDiscoY2 and MOUSE_Y <= b2pt_apDiscoY1) then 
        -- reset and disable the pause AP Disconnect
        RESUME_MOUSE_CLICK = true
        if (b2pt_apDisconnectEnabled) then
            b2pt_apDisconnectEnabled = false
            b2pt_apDisconnectActive = false
        else
            b2pt_apDisconnectEnabled = true
        end
    end

    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= b2pt_ffX1 and MOUSE_X <= b2pt_ffX2 and
        MOUSE_Y >= b2pt_ffY2 and MOUSE_Y <= b2pt_ffY1) then 
        -- reset and disable the pause fuel flow
        RESUME_MOUSE_CLICK = true
        if (b2pt_fuelFlowActive) then
            b2pt_fuelFlowActive = false
        else
            b2pt_fuelFlowActive = true
        end
    end

    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= b2pt_stallWarningX1 and MOUSE_X <= b2pt_stallWarningX2 and
        MOUSE_Y >= b2pt_stallWarningY2 and MOUSE_Y <= b2pt_stallWarningY1) then 
        -- reset and disable the pause stall warning
        RESUME_MOUSE_CLICK = true
        if (b2pt_stallWarningActive) then
            b2pt_stallWarningActive = false
        else
            b2pt_stallWarningActive = true
        end
    end

    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= b2pt_distX1 and MOUSE_X <= b2pt_distX2 and
        MOUSE_Y >= b2pt_distY2 and MOUSE_Y <= b2pt_distY1) then 
        -- reset and disable the pause on distance
        RESUME_MOUSE_CLICK = true
        b2pt_pauseDistActive = false
        b2pt_distToPause = 0
    end

    -- check if position over our toggle icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX+55) and MOUSE_X <= (mainX+105) and 
        MOUSE_Y >= (mainY-24) and MOUSE_Y <= (mainY)) then
        RESUME_MOUSE_CLICK = true

        if (bDrawControlBox == true) then
            bDrawControlBox = false
        else 
            bDrawControlBox = true  -- draw the box
        end
    end

    -- check if position over our drag icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX) and MOUSE_X <= (mainX+10) and 
        MOUSE_Y >= (mainY-20) and MOUSE_Y <= (mainY-10)) then
        bDragging = true
        RESUME_MOUSE_CLICK = true
    elseif (bDragging == true and MOUSE_STATUS == "drag") then
        mainX = MOUSE_X - 5
        mainY = MOUSE_Y + 15

        -- see if we are 'close enough' to original default to snap in place
        if (mainX > snapMainX - 20 and mainX < snapMainX + 20 and 
            mainY > snapMainY - 15 and mainY < snapMainY + 15) then
            mainX = snapMainX
            mainY = snapMainY
        end
    end
end

function B2PauseTimer_everySec()
    if (b2pt_fuelFlowActive) then
        -- check fuel flow for going 'active'
        for i = 1,8 do
            if (b2pt_fuelFlow[i] == false) then
                if (get("sim/cockpit2/engine/indicators/fuel_flow_kg_sec",i-1) > b2pt_minFuelFlow) then
                    b2pt_fuelFlow[i] = true
                end
            end
        end
    end

    if (b2pt_apDisconnectEnabled and not(b2pt_apDisconnectActive)) then
        if (get("sim/cockpit/autopilot/autopilot_mode") == 2) then -- only active iff AP 'on' (mode = 2)
            b2pt_apDisconnectActive = true
        end
    end
end

function B2PauseTimer_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)

    if (bDrawControlBox == true or
        (MOUSE_X >= (mainX) and MOUSE_X <= (mainX+200) and 
         MOUSE_Y >= (mainY-100) and MOUSE_Y <= (mainY+100))) then
        -- always draw clickable pause icon
--        graphics.set_color(0,0,0,1) -- black
        B2PauseTimer_SetColor(4)
        graphics.draw_rectangle(mainX+75,mainY-3,mainX+86,mainY-27)
        graphics.draw_rectangle(mainX+89,mainY-3,mainX+100,mainY-27)
        
--        graphics.set_color(0.4,0.4,0.4,1) -- gray
        B2PauseTimer_SetColor(3)
        graphics.draw_rectangle(mainX+76,mainY-4,mainX+85,mainY-26)
        graphics.draw_rectangle(mainX+90,mainY-4,mainX+99,mainY-26)
    end

    if (bDrawControlBox == true) then
        -- draw 'drag' wheel
--        graphics.set_color(1,1,1,0.5) -- white border
        B2PauseTimer_SetColor(5)
        graphics.draw_filled_circle(mainX+5,mainY-15,5)
--        graphics.set_color(140/255,128/255,99/255,0.8) -- fill in color
        B2PauseTimer_SetColor(6)
        graphics.draw_filled_circle(mainX+5,mainY-15,4)

        -- draw 'active' pause icon
--        graphics.set_color(140/255,128/255,99/255,1) -- fill in color
        B2PauseTimer_SetColor(7)
        graphics.draw_rectangle(mainX+76,mainY-4,mainX+85,mainY-26)
        graphics.draw_rectangle(mainX+90,mainY-4,mainX+99,mainY-26)

        -- draw background workspace box
--        graphics.set_color(66/255, 66/255, 66/255, 1) -- dark gray
        B2PauseTimer_SetColor(8)
        graphics.draw_rectangle(mainX,mainY-35,mainX+105,mainY-200)

        draw_string(mainX+2,mainY-45,"PAUSE ON...",239/255,219/255,172/255)
        draw_string(mainX+20,mainY-55,"...time",239/255,219/255,172/255)
        draw_string(mainX+20,mainY-65,"...altitude",239/255,219/255,172/255)
        draw_string(mainX+20,mainY-75,"...autopilot",239/255,219/255,172/255)
        draw_string(mainX+20,mainY-85,"...fuel flow",239/255,219/255,172/255)
        draw_string(mainX+20,mainY-95,"...stall",239/255,219/255,172/255)

    end

    if (b2pt_bWeCausedPause) then
        if ((os.time() % 2) == 1) then 
            graphics.set_color(54/255,186/255,27/255,0.8)
        else
            graphics.set_color(186/255,143/255,27/255,0.8)
        end
    graphics.draw_rectangle(b2pt_currentTimeX1-10,b2pt_currentTimeY1+10,b2pt_aglX2+10,b2pt_aglY2-10)
    end

    graphics.set_width(1)  -- protect against any previous settings
    local tTime = os.date("*t", os.time())
    local minsUntilPause = math.floor(b2pt_epochTimePause/60) - (math.floor(os.time()/60))
    if (b2pt_bWeCausedPause) then
        if (get("sim/time/sim_speed") > 0) then -- no longer paused
            b2pt_bWeCausedPause = false
        end
    end

--draw_string(800,1300,"tmpStr: " .. tmpStr , "yellow")

--draw_string(800,1270,"dist " .. get("sim/flightmodel/controls/dist") , "yellow")
--draw_string(800,1250,"dist " .. B2PauseTimer_Meter2NM(get("sim/flightmodel/controls/dist")) , "yellow")
--draw_string(800,1230,"b2pt_distToPause " .. b2pt_distToPause , "yellow")

    local timeHeight = 25
    local timeWidth = timeHeight*0.7*4.25  -- 0.7 makes readout nicer, 4x chars, .25x blinky dots

    b2pt_currentTimeX1 = SCREEN_WIDTH*0.4
    b2pt_currentTimeY1 = SCREEN_HIGHT - 35
    b2pt_currentTimeX2 = b2pt_currentTimeX1 + timeWidth
    b2pt_currentTimeY2 = b2pt_currentTimeY1 - timeHeight

    -- width of 'time' is 6.5xwidth
    B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],b2pt_currentTimeX1,b2pt_currentTimeY1,timeWidth,timeHeight,false)

    -- ========================================================================================
    -- pause time
    b2pt_pauseTimeX1 = b2pt_currentTimeX1 + (timeWidth * 1.4)
    b2pt_pauseTimeY1 = b2pt_currentTimeY1
    b2pt_pauseTimeX2 = b2pt_pauseTimeX1 + timeWidth
    b2pt_pauseTimeY2 = b2pt_pauseTimeY1 - timeHeight

    b2pt_minUntilPauseX1 = b2pt_pauseTimeX1 + (timeWidth * 1.4)
    b2pt_minUntilPauseY1 = b2pt_currentTimeY1
    b2pt_minUntilPauseX2 = b2pt_minUntilPauseX1 + timeWidth
    b2pt_minUntilPauseY2 = b2pt_minUntilPauseY1 - timeHeight

    if (b2pt_epochTimePause == 0) then
        B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],b2pt_pauseTimeX1,b2pt_pauseTimeY1,timeWidth,timeHeight,false)
        B2PauseTimer_DrawTime (0,0,b2pt_minUntilPauseX1,b2pt_minUntilPauseY1,timeWidth,timeHeight,false)
    else
        B2PauseTimer_DrawTime (os.date("%H",b2pt_epochTimePause),os.date("%M",b2pt_epochTimePause),b2pt_pauseTimeX1,b2pt_pauseTimeY1,timeWidth,timeHeight,true)
        B2PauseTimer_DrawTime (math.floor(minsUntilPause/60),minsUntilPause%60,b2pt_minUntilPauseX1,b2pt_minUntilPauseY1,timeWidth,timeHeight,true)

        -- do we pause?
        if (b2pt_pauseTimerActive and minsUntilPause == 0) then 
            b2pt_pauseTimerActive = false
            b2pt_epochTimePause = 0
            
            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
                b2pt_bWeCausedPause = true
            end
        end
    end

    -- ========================================================================================
    b2pt_aglX1 = b2pt_minUntilPauseX1 + (timeWidth * 1.4)
    b2pt_aglY1 = b2pt_currentTimeY1
    b2pt_aglX2 = b2pt_aglX1 + timeHeight*0.7*5  -- 0.7 makes readout nicer, 5x chars
    b2pt_aglY2 = b2pt_aglY1 - timeHeight

    if (b2pt_aglToPause == 0) then
        B2PauseTimer_DrawAlt(B2PauseTimer_Meter2Feet(b2pt_agl),b2pt_aglX1,b2pt_aglY1,b2pt_aglX2-b2pt_aglX1,timeHeight)
--B2PauseTimer_DrawAlt(B2PauseTimer_Meter2Feet(b2pt_agl),100,1000,400*0.70*5,500)
    else
        B2PauseTimer_DrawAlt(b2pt_aglToPause,b2pt_aglX1,b2pt_aglY1,b2pt_aglX2-b2pt_aglX1,timeHeight)
        -- do we pause?
        if (b2pt_pauseAltActive and math.floor(B2PauseTimer_Meter2Feet(b2pt_agl)) == b2pt_aglToPause) then
            b2pt_aglToPause = 0
            b2pt_pauseAltActive = false

            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
                b2pt_bWeCausedPause = true
            end
        end
    end

    -- ========================================================================================
    b2pt_apDiscoX1 = b2pt_aglX1 + (timeWidth * 1.4)
    b2pt_apDiscoY1 = b2pt_currentTimeY1
    b2pt_apDiscoX2 = b2pt_apDiscoX1 + timeHeight*0.7      -- 0.7 makes readout nicer
    b2pt_apDiscoY2 = b2pt_apDiscoY1 - timeHeight 

    B2PauseTimer_DrawToggleBox(b2pt_apDiscoX1,b2pt_apDiscoY1,timeHeight*0.7,timeHeight,b2pt_apDisconnectEnabled)
--B2PauseTimer_DrawToggleBox(1800,1000,500*0.7,500)
    
    if (b2pt_apDisconnectActive) then
        if (get("sim/cockpit/warnings/annunciators/autopilot_disconnect") == 1) then
            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
                b2pt_bWeCausedPause = true
            end
            b2pt_apDisconnectEnabled = false
            b2pt_apDisconnectActive = false
        end
    end

    -- ========================================================================================
    b2pt_ffX1 = b2pt_apDiscoX2 + ((b2pt_apDiscoX2-b2pt_apDiscoX1)* 0.5)
    b2pt_ffY1 = b2pt_currentTimeY1
    b2pt_ffX2 = b2pt_ffX1 + timeHeight*0.7      -- 0.7 makes readout nicer
    b2pt_ffY2 = b2pt_ffY1 - timeHeight 

    B2PauseTimer_DrawToggleBox(b2pt_ffX1,b2pt_ffY1,timeHeight*0.7,timeHeight,b2pt_fuelFlowActive)
    
    if (b2pt_fuelFlowActive) then
        for i = 1,8 do
            if (b2pt_fuelFlow[i] == true) then
                if (get("sim/cockpit2/engine/indicators/fuel_flow_kg_sec",i-1) < b2pt_minFuelFlow) then
                    if (get("sim/time/sim_speed") > 0) then
                        command_once("sim/operation/pause_toggle")
                        b2pt_bWeCausedPause = true
                    end
                b2pt_fuelFlowActive = false
                end
            end
        end
    end

    -- ========================================================================================
    b2pt_stallWarningX1 = b2pt_ffX2 + ((b2pt_ffX2-b2pt_ffX1)* 0.5)
    b2pt_stallWarningY1 = b2pt_currentTimeY1
    b2pt_stallWarningX2 = b2pt_stallWarningX1 + timeHeight*0.7      -- 0.7 makes readout nicer
    b2pt_stallWarningY2 = b2pt_stallWarningY1 - timeHeight 

    B2PauseTimer_DrawToggleBox(b2pt_stallWarningX1,b2pt_stallWarningY1,timeHeight*0.7,timeHeight,b2pt_stallWarningActive)
    
    if (b2pt_stallWarningActive) then
        if (get("sim/flightmodel/failures/stallwarning") == 1) then
            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
                b2pt_bWeCausedPause = true
            end
            b2pt_stallWarningActive = false
        end
    end

    -- ========================================================================================
    b2pt_distX1 = b2pt_stallWarningX2 + (timeWidth * 0.4)
    b2pt_distY1 = b2pt_currentTimeY1
    b2pt_distX2 = b2pt_distX1 + timeHeight*0.7*4  -- 0.7 makes readout nicer, 4x chars
    b2pt_distY2 = b2pt_distY1 - timeHeight

    if (b2pt_distToPause == 0) then
        B2PauseTimer_DrawDist(0,b2pt_distX1,b2pt_distY1,b2pt_distX2-b2pt_distX1,timeHeight)
    else
        local distanceRemaining = b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist)   -- in nm
        B2PauseTimer_DrawDist(distanceRemaining,b2pt_distX1,b2pt_distY1,b2pt_distX2-b2pt_distX1,timeHeight)
        -- do we pause?
        if (b2pt_pauseDistActive and (distanceRemaining <= 0)) then
            b2pt_distToPause = 0
            b2pt_pauseDistActive = false

            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
                b2pt_bWeCausedPause = true
            end
        end
    end
end


