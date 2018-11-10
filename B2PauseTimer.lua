require "graphics"
require "math"

local b2pt_SoftwareVersion = 2.1

local tmpStr = ""
local tmpStr2 = ""

dataref("b2pt_agl", "sim/flightmodel/position/y_agl")
dataref("b2pt_dist", "sim/flightmodel/controls/dist")

local snapMainX = SCREEN_WIDTH - 225
local snapMainY = SCREEN_HIGHT - 25
local mainX = snapMainX
local mainY = snapMainY
local mainY2 = SCREEN_HIGHT              -- lowest coor 'y' we draw to
local bDrawControlBox = false
local bDragging = false
local bScreenSizeChanged = true
local bAutoPosition = true
local bComputeBoxes = false

local b2pt_SoftwareVersion = 1
local b2pt_epochTimePause = 0
local b2pt_pauseAltActive = false
local b2pt_aglToPause = 0               -- in feet
local b2pt_distToPause = 0              -- in nm
local b2pt_bWeCausedPause = nil


local b2pt_fuelFlow = {false,false,false,false,false,false,false,false} -- 8 engines
local b2pt_minFuelFlow = 0.00001



-- dataRows 
local dataRows = {onTime         = {name="...on Time",      bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=115, drawFunc, mWheel}, pauseCheck},
                  onAltitude     = {name="...on Altitude",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=45, drawFunc, mWheel}, pauseCheck},
                  onDistance     = {name="...on Distance",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=45, drawFunc, mWheel}, pauseCheck},
                  onAPDisconnect = {name="...on AP Disco",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck},
                  onFuelFlow     = {name="...on Fuel Flow", bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck},
                  onStall        = {name="...on Stall",     bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck}
                  }

do_every_draw("B2PauseTimer_everyDraw()")
do_on_mouse_wheel("B2PauseTimer_onMouseWheel()")
do_on_mouse_click("B2PauseTimer_mouseClick()")
do_often("B2PauseTimer_everySec()")


--  0/255,0/255,0/255      -- black
--  211/255,10/255,10/255  -- red
--  56/255,181/255,74/255  -- green
--  71/255,71/255,70/255   -- grey

function B2PauseTimer_SetColor(colorNum)
    if     (colorNum == 1) then graphics.set_color(0/255,0/255,0/255,0.8)  -- black
    elseif (colorNum == 2) then graphics.set_color(211/255,10/255,10/255,0.8) -- red
    elseif (colorNum == 3) then graphics.set_color(102/255,102/255,102/255,1)  -- grey40
    elseif (colorNum == 4) then graphics.set_color(0/255,0/255,0/255,1)  -- black
    elseif (colorNum == 5) then graphics.set_color(255/255,255/255,255/255,0.5)  -- white
    elseif (colorNum == 6) then graphics.set_color(140/255,128/255,99/255,0.8)  -- fill in color
    elseif (colorNum == 7) then graphics.set_color(140/255,128/255,99/255,1)  -- fill in color
    elseif (colorNum == 8) then graphics.set_color(66/255, 66/255, 66/255, 1) -- dark gray
    elseif (colorNum == 9) then graphics.set_color(239/255,219/255,172/255, 1) -- text
    elseif (colorNum ==10) then graphics.set_color(140/255,128/255,99/255,0.2)  -- fill in color (related to 6 and 7)
    elseif (colorNum ==11) then graphics.set_color(82/255,221/255,91/255,0.8) -- green
    else                        graphics.set_color(71/255,71/255,70/255,0.05)  -- grey and default
    end
end

function B2PauseTimer_Meter2Feet(meter)
    return meter * 3.28084
end
function B2PauseTimer_Meter2NM(meter)
    return meter * 0.000539957
end
function B2PauseTimer_NM2Meter(nm)
    return nm * 1852
end

function B2PauseTimer_DrawHorizontal(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(10) end
    pixW = math.ceil(pixW)
    pixH = math.ceil(pixH)
    graphics.draw_rectangle(x+pixH,y+pixH,x+pixW-pixH,y-pixH)
    graphics.draw_triangle(x,y,x+pixH,y+pixH,x+pixH,y-pixH)
    graphics.draw_triangle(x+pixW,y,x+pixW-pixH,y-pixH,x+pixW-pixH,y+pixH)
end
function B2PauseTimer_DrawVertical(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(10) end
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
    local colorNum = 7
    if (dataRows.onTime.bActive and bTimer) then
        colorNum = 11
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
    local colorNum = 7
    local cWdth = math.floor(oWdth / 5)
    if (alt < 0) then alt = 0 end
    if (alt > 99999) then alt = 99999 end

    if (dataRows.onAltitude.bActive) then colorNum = 11 end 

    B2PauseTimer_DrawNumber(x+(cWdth*0),y,cWdth,oHgt,math.floor((alt%100000)/10000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*1),y,cWdth,oHgt,math.floor((alt%10000)/1000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*2),y,cWdth,oHgt,math.floor((alt%1000)/100),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*3),y,cWdth,oHgt,math.floor((alt%100)/10),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*4),y,cWdth,oHgt,math.floor((alt%10)/1),colorNum)
end
function B2PauseTimer_DrawDist(dist,x,y,oWdth,oHgt)
    -- dist given in nm
    local nm = math.ceil(dist) -- round up
    local colorNum = 7
    local cWdth = math.floor(oWdth / 4)
    if (nm < 0) then nm = 0 end
    if (nm > 9999) then nm = 9999 end

    if (dataRows.onDistance.bActive) then colorNum = 11 end 

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
function B2PauseTimer_DrawBoxSolid(x1,y1,x2,y2,colorNum)
    B2PauseTimer_SetColor(colorNum)
    graphics.draw_rectangle(x1,y1,x2,y2)
end
function B2PauseTimer_DrawBoxBorder(x1,y1,x2,y2,thickness,colorNum)
    B2PauseTimer_SetColor(colorNum)
    graphics.draw_rectangle(x1,y1,x2,y1-thickness)
    graphics.draw_rectangle(x2-thickness,y1-thickness,x2,y2+thickness)
    graphics.draw_rectangle(x1,y2+thickness,x2,y2)
    graphics.draw_rectangle(x1,y1-thickness,x1+thickness,y2+thickness)

end
function B2PauseTimer_DrawCircle(x,y,radius,colorNum,bFilled)
    B2PauseTimer_SetColor(colorNum)
    if (bFilled) then
        graphics.draw_filled_circle(x,y,radius)
    else
        graphics.set_width(1)
        graphics.draw_circle(x,y,radius)
    end
end
function B2PauseTimer_DrawToggleRow(x,y,row) -- standard toggle box row
    if (row.bActive) then 
        B2PauseTimer_DrawBoxSolid(x,y,x+105,y-15,3)         -- background, color 3
    else
        B2PauseTimer_DrawBoxSolid(x,y,x+105,y-15,8)         -- background, color 8
    end
    local flashColor = 3
    local flashWidth = 1
    if (b2pt_bWeCausedPause and b2pt_bWeCausedPause == row) then
        if ((os.time() % 2) == 1) then 
            flashColor = 2
            flashWidth = 2
        end
    end
    B2PauseTimer_DrawBoxBorder(x,y,x+105,y-15,flashWidth,flashColor)      -- background border, width/color variable
    B2PauseTimer_DrawBoxSolid(x+91,y-3,x+102,y-12,6)    -- toggle box, color 6
    B2PauseTimer_DrawBoxBorder(x+91,y-3,x+102,y-12,1,5) -- toggle box border, width 1, color 5
    draw_string(x+4,y-11,row.name,239/255,219/255,172/255)
    if (row.box.bClicked) then
        B2PauseTimer_DrawBoxSolid(x+93,y-5,x+100,y-10,2)    -- toggle box active, color 2
    end
    if (bComputeBoxes) then -- store location of the toggle boxes
        row.box.x = x+91
        row.box.y = y-3
        if (mainY2 > y - 15) then mainY2 = y - 15 end -- store absolute lowest of drawn area
    end
    return y - 15   -- return bottom of box we drew
end
function B2PauseTimer_DrawOptionalRow(x,yIn,row,colorNum) -- toggle box of optional height
    local y = yIn
    if (row.box.bClicked and row.opt) then
        if (row.bActive) then 
            B2PauseTimer_DrawBoxSolid(x,y,x+105,y-row.opt.height,3)      -- background, color 3
        else
            B2PauseTimer_DrawBoxSolid(x,y,x+105,y-row.opt.height,8)      -- background, color 8
        end

        local flashColor = 3
        local flashWidth = 1
        if (b2pt_bWeCausedPause and b2pt_bWeCausedPause == row) then
            if ((os.time() % 2) == 1) then 
                flashColor = 2
                flashWidth = 2
            end
        end
        B2PauseTimer_DrawBoxBorder(x,y,x+105,y-row.opt.height,flashWidth,flashColor)   -- background border, width/color variable
        if (bComputeBoxes) then -- store location of the optional boxes
            row.opt.x = x
            row.opt.y = yIn
        end
        y = y - row.opt.height
        row.opt.drawFunc()
    end
    return y - 1    -- return bottom of box we drew
end

function B2PauseTimer_PauseCheck(caller)
    if (get("sim/time/sim_speed") > 0) then
        command_once("sim/operation/pause_toggle")
        b2pt_bWeCausedPause = caller
    end
end
dataRows.onTime.pauseCheck = function()
    if not(b2pt_epochTimePause == 0) then
        if ((math.floor(b2pt_epochTimePause/60) - (math.floor(os.time()/60))) == 0) then 
            dataRows.onTime.bActive = false
            b2pt_epochTimePause = 0
            B2PauseTimer_PauseCheck(dataRows.onTime)
        end
    end

end
dataRows.onAltitude.pauseCheck = function()
    if not(b2pt_aglToPause == 0) then
        if (math.floor(B2PauseTimer_Meter2Feet(b2pt_agl)) == b2pt_aglToPause) then
            b2pt_aglToPause = 0
            dataRows.onAltitude.bActive = false
            B2PauseTimer_PauseCheck(dataRows.onAltitude)
        end
    end
end
dataRows.onDistance.pauseCheck = function()
    if not(b2pt_distToPause == 0) then
        if ((b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist)) <= 0) then
            b2pt_distToPause = 0
            dataRows.onDistance.bActive = false
            B2PauseTimer_PauseCheck(dataRows.onDistance)
        end
    end
end
dataRows.onAPDisconnect.pauseCheck = function()
    if (get("sim/cockpit/warnings/annunciators/autopilot_disconnect") == 1) then
        B2PauseTimer_PauseCheck(dataRows.onAPDisconnect)
        dataRows.onAPDisconnect.bActive = false
        dataRows.onAPDisconnect.box.bClicked = false
    end
end
dataRows.onFuelFlow.pauseCheck = function()
    for i,val in ipairs(b2pt_fuelFlow) do
        if (val == true) then
            if (get("sim/cockpit2/engine/indicators/fuel_flow_kg_sec",i-1) < b2pt_minFuelFlow) then
                B2PauseTimer_PauseCheck(dataRows.onFuelFlow)
                dataRows.onFuelFlow.bActive = false
                dataRows.onFuelFlow.box.bClicked = false
                for i in ipairs(b2pt_fuelFlow) do
                    b2pt_fuelFlow[i] = false
                end
            end
        end
    end
end
dataRows.onStall.pauseCheck = function()
    if (get("sim/flightmodel/failures/stallwarning") == 1) then
        B2PauseTimer_PauseCheck(dataRows.onStall)
        dataRows.onStall.bActive = false
        dataRows.onStall.box.bClicked = false
    end
end


dataRows.onTime.opt.drawFunc = function()
    local y = dataRows.onTime.opt.y
    local tTime = os.date("*t", os.time())
    local minsUntilPause = math.floor(b2pt_epochTimePause/60) - (math.floor(os.time()/60))

-- time
    B2PauseTimer_DrawTime (tTime["hour"],
                            tTime["min"],dataRows.onTime.opt.x+15,
                            y-10,74.4,25,false)
    y = y - 10 - 25  --offset and char height

--pause time
    if (b2pt_epochTimePause == 0) then
        B2PauseTimer_DrawTime(tTime["hour"],tTime["min"],dataRows.onTime.opt.x+15,y-10,74.4,25,false)
    else
        B2PauseTimer_DrawTime(os.date("%H",b2pt_epochTimePause),os.date("%M",b2pt_epochTimePause),dataRows.onTime.opt.x+15,y-10,74.4,25,true)
    end
    y = y - 10 - 25  --offset and char height

--time from now
    if (b2pt_epochTimePause == 0) then
        B2PauseTimer_DrawTime(0,0,dataRows.onTime.opt.x+15,y-10,74.4,25,false)
    else
        B2PauseTimer_DrawTime(math.floor(minsUntilPause/60),minsUntilPause%60,dataRows.onTime.opt.x+15,y-10,74.4,25,true)
    end
end
dataRows.onAltitude.opt.drawFunc = function()
    local agl = b2pt_aglToPause
    if (b2pt_aglToPause == 0) then agl = B2PauseTimer_Meter2Feet(b2pt_agl) end
    B2PauseTimer_DrawAlt(agl,dataRows.onAltitude.opt.x + 15,dataRows.onAltitude.opt.y - 10 , 87, 25)
end
dataRows.onDistance.opt.drawFunc = function()
    local dist = b2pt_distToPause
    if not(b2pt_distToPause == 0) then dist = b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist) end
    B2PauseTimer_DrawDist(dist, dataRows.onDistance.opt.x + 20,dataRows.onDistance.opt.y - 10, 67, 25)
end

dataRows.onTime.opt.mWheel = function()
    local timeChange = 60 -- in secs
    if (MOUSE_X < dataRows.onTime.opt.x+50) then -- adjust or calc off where the 'dots' are
        timeChange = 3600 -- in secs
    end

    -- need to determine if MOUSE_Y is over current time, pause time, or time until pause
    if (MOUSE_Y > dataRows.onTime.opt.y - (dataRows.onTime.opt.height / 3)) then
        -- just ignore this area
        return nil
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
        dataRows.onTime.bActive = true
    end
end
dataRows.onAltitude.opt.mWheel = function()
    if (b2pt_aglToPause == 0) then b2pt_aglToPause = math.floor(B2PauseTimer_Meter2Feet(b2pt_agl)/100)*100 end
    b2pt_aglToPause = math.max(b2pt_aglToPause + (MOUSE_WHEEL_CLICKS * 100),0)
    if (math.abs(b2pt_aglToPause - B2PauseTimer_Meter2Feet(b2pt_agl)) > 250) then dataRows.onAltitude.bActive = true end
    if (dataRows.onAltitude.bActive and b2pt_aglToPause <= 0) then
        b2pt_aglToPause = 0
        dataRows.onAltitude.bActive = false
    end
end
dataRows.onDistance.opt.mWheel = function()
    if (b2pt_distToPause == 0) then b2pt_distToPause = B2PauseTimer_Meter2NM(b2pt_dist) end
    b2pt_distToPause = math.max(b2pt_distToPause + (MOUSE_WHEEL_CLICKS * 10),0)
    if (b2pt_distToPause <= B2PauseTimer_Meter2NM(b2pt_dist)) then              -- no neg values
        b2pt_distToPause = 0
        dataRows.onDistance.bActive = false
    elseif (b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist) > 25) then      -- min 25nm
        dataRows.onDistance.bActive = true
    end
end
function B2PauseTimer_onMouseWheel()
    if (bDrawControlBox) then
        for k,val in pairs(dataRows) do
            if (val.box.bClicked and val.opt) then 
                if ( MOUSE_X > val.opt.x and MOUSE_X < val.opt.x+105 and
                     MOUSE_Y < val.opt.y and MOUSE_Y > val.opt.y - val.opt.height) then
                    val.opt.mWheel()
                    RESUME_MOUSE_WHEEL = true
                    return
                end
            end
        end
    end
end


dataRows.onTime.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onTime"
    b2pt_epochTimePause = 0
    if not(dataRows.onTime.box.bClicked) then dataRows.onTime.bActive = false end
    return nil
end
dataRows.onAltitude.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onAltitude"
    b2pt_aglToPause = 0
    if not (dataRows.onAltitude.box.bClicked) then dataRows.onAltitude.bActive = false end
    return nil
end
dataRows.onDistance.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onDistance"
    b2pt_distToPause = 0
    if not(dataRows.onDistance.box.bClicked) then dataRows.onDistance.bActive = false end
    return nil
end
dataRows.onAPDisconnect.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onAPDisco"
    if not(dataRows.onAPDisconnect.box.bClicked) then dataRows.onAPDisconnect.bActive = false end
    return nil
end
dataRows.onFuelFlow.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onFuelFlow"
    dataRows.onFuelFlow.bActive = dataRows.onFuelFlow.box.bClicked
    return nil
end
dataRows.onStall.box.mClick = function () 
    tmpStr2 = tmpStr2 .. "onStall"
    dataRows.onStall.bActive = dataRows.onStall.box.bClicked
    return nil
end
function B2PauseTimer_mouseClick()
    if (MOUSE_STATUS == "up") then if (bDragging) then bComputeBoxes = true end bDragging = false end

    if (MOUSE_STATUS == "down" and bDrawControlBox) then
        for k,val in pairs(dataRows) do
            if ( MOUSE_X > val.box.x and MOUSE_X < val.box.x+11 and
                 MOUSE_Y < val.box.y and MOUSE_Y > val.box.y-11) then
                val.box.bClicked = not val.box.bClicked
                val.box.mClick()
                RESUME_MOUSE_CLICK = true
                bComputeBoxes = true        -- click changes locations of everything
                return
            end
        end
    end

    -- check if position over our toggle icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX+55) and MOUSE_X <= (mainX+105) and 
        MOUSE_Y >= (mainY-24) and MOUSE_Y <= (mainY)) then
        RESUME_MOUSE_CLICK = true
        if (b2pt_bWeCausedPause) then b2pt_bWeCausedPause = nil end
        bDrawControlBox = not bDrawControlBox
        if (bDrawControlBox) then bComputeBoxes = true end
        return
    end

    -- check if position over our drag icon
    if (MOUSE_STATUS == "down" and bDrawControlBox and 
        MOUSE_X >= (mainX) and MOUSE_X <= (mainX+10) and 
        MOUSE_Y >= (mainY-20) and MOUSE_Y <= (mainY-10)) then
        bDragging = true
        RESUME_MOUSE_CLICK = true
        return
    elseif (bDragging == true and MOUSE_STATUS == "drag") then
        mainX = MOUSE_X - 5
        mainY = MOUSE_Y + 15
        bAutoPosition = false

        -- see if we are 'close enough' to original default to snap in place
        if (mainX > snapMainX - 20 and mainX < snapMainX + 20 and 
            mainY > snapMainY - 15 and mainY < snapMainY + 15) then
            mainX = snapMainX
            mainY = snapMainY
            bAutoPosition = true
        end
        return
    end
end

function B2PauseTimer_everySec()
    if not(snapMainX == (SCREEN_WIDTH - 225)) then
        bScreenSizeChanged = true
        snapMainX = SCREEN_WIDTH - 225
        bComputeBoxes = true
    end
    if not(snapMainY == (SCREEN_HIGHT - 25)) then
        bScreenSizeChanged = true
        snapMainY = SCREEN_HIGHT - 25
        bComputeBoxes = true
    end

    if (dataRows.onFuelFlow.bActive) then
        -- check fuel flow for going 'active'
        for i,val in ipairs(b2pt_fuelFlow) do
            if (val == false) then
                if (get("sim/cockpit2/engine/indicators/fuel_flow_kg_sec",i-1) > b2pt_minFuelFlow) then
                    b2pt_fuelFlow[i] = true
                end
            end
        end
    end

    if (dataRows.onAPDisconnect.box.bClicked and not(dataRows.onAPDisconnect.bActive)) then
        if (get("sim/cockpit/autopilot/autopilot_mode") == 2) then -- only active iff AP 'on' (mode = 2)
            dataRows.onAPDisconnect.bActive = true
        end
    end

    if (bAutoPosition == true) then
        -- handle screen width changes
        if (bScreenSizeChanged) then
            mainX = snapMainX
            mainY = snapMainY
        end
    else -- manual position
        -- make sure we aren't drawing off the screen
        -- X:: from mainX to mainX+105
        -- Y:: from mainY to mainY-200
        if (mainX < 0) then
            mainX = 0
            bComputeBoxes = true
        elseif (mainX+105 > SCREEN_WIDTH) then 
            mainX = SCREEN_WIDTH-105
            bComputeBoxes = true
        end
        if (mainY2 < 0) then
            mainY = mainY - mainY2
            mainY2 = 0
            bComputeBoxes = true
        elseif (mainY+25 > SCREEN_HIGHT) then
            mainY = SCREEN_HIGHT - 25
            bComputeBoxes = true
        end
    end

    -- check to see if pause conditions are met
    for k,val in pairs(dataRows) do
        if (val.bActive) then 
            val.pauseCheck()
        end
    end
end
function B2PauseTimer_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)
    graphics.set_width(1)  -- protect against any previous settings

    if (b2pt_bWeCausedPause) then bDrawControlBox = true end

    if (bDrawControlBox == true or
        (MOUSE_X >= (mainX) and MOUSE_X <= (mainX+200) and 
         MOUSE_Y >= (mainY-100) and MOUSE_Y <= (mainY+100))) then
        -- always draw clickable pause icon, active gets different color
        local colorNum = 3
        if (bDrawControlBox == true) then colorNum = 7 end
        B2PauseTimer_DrawBoxSolid(mainX+75,mainY-3,mainX+86,mainY-27,colorNum)
        B2PauseTimer_DrawBoxSolid(mainX+89,mainY-3,mainX+100,mainY-27,colorNum)
        B2PauseTimer_DrawBoxBorder(mainX+75,mainY-3,mainX+86,mainY-27,1,4)
        B2PauseTimer_DrawBoxBorder(mainX+89,mainY-3,mainX+100,mainY-27,1,4)
    end

    if (bDrawControlBox == true) then
        -- draw 'drag' wheel (when this small, two solids look better than solid w/ border)
        B2PauseTimer_DrawCircle(mainX+5,mainY-15,5,5,true)
        B2PauseTimer_DrawCircle(mainX+5,mainY-15,4,6,true)

    local x = mainX
    local y = mainY-35
    graphics.set_width(1)  -- protect against any previous settings

    ----
    if (bComputeBoxes) then mainY2 = SCREEN_HIGHT end -- require new position of mainY2
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onTime)
        y = B2PauseTimer_DrawOptionalRow(x,y,dataRows.onTime,8)
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onAltitude)
        y = B2PauseTimer_DrawOptionalRow(x,y,dataRows.onAltitude,8)
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onDistance)
        y = B2PauseTimer_DrawOptionalRow(x,y,dataRows.onDistance,8)
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onAPDisconnect)
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onFuelFlow)
        y = B2PauseTimer_DrawToggleRow(x,y,dataRows.onStall)
        bComputeBoxes = false -- DrawToggleRow calls do it
    end

    if (b2pt_bWeCausedPause) then
        if (get("sim/time/sim_speed") > 0) then -- no longer paused
            b2pt_bWeCausedPause = nil
        end
    end
end


