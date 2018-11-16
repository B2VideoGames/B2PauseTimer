require "graphics"
require "math"

local b2pt_SoftwareVersion = 1.0
local b2pt_FileFormat = 1

dataref("b2pt_agl", "sim/flightmodel/position/y_agl")
dataref("b2pt_dist", "sim/flightmodel/controls/dist")

local wgtW = 120            -- designed: 105
local wgtRowH = 30          -- designed:  25
local tBoxH = wgtRowH - 14
local perDigital = 0.70
local perDigitsPad = 8

local snapMainX = SCREEN_WIDTH - 120 - wgtW
local snapMainY = SCREEN_HIGHT - 25
local mainX = snapMainX
local mainY = snapMainY
local mainY2 = SCREEN_HIGHT              -- lowest coor 'y' we draw to

local bDrawControlBox = false
local bDragging = false
local bScreenSizeChanged = true
local bAutoPosition = true
local bComputeBoxes = false
local bNewLoad = true
local bSaveRequired = false

local b2pt_epochTimePause = 0
local b2pt_pauseAltActive = false
local b2pt_aglToPause = 0               -- in feet
local b2pt_prevAglChecked = 0               -- in feet
local b2pt_distToPause = 0              -- in nm
local b2pt_bWeCausedPause = nil

local b2pt_fuelFlow = {false,false,false,false,false,false,false,false} -- 8 engines
local b2pt_minFuelFlow = 0.00001

-- dataRows 
local dataRows = {onTime         = {name="...on Time",      bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=(wgtRowH*3)+40, drawFunc, mWheel, mClick}, pauseCheck},
                  onAltitude     = {name="...on Altitude",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=wgtRowH+20, drawFunc, mWheel, mClick}, pauseCheck},
                  onDistance     = {name="...on Distance",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt={x=0, y=0, height=wgtRowH+20, drawFunc, mWheel, mClick}, pauseCheck},
                  onAPDisconnect = {name="...on AP Disco",  bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck},
                  onFuelFlow     = {name="...on Fuel Flow", bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck},
                  onStall        = {name="...on Stall",     bActive=false, box={bClicked=false, x=0, y=0, mClick}, opt=nil, pauseCheck}
                  }

do_every_draw("B2PauseTimer_everyDraw()")
do_on_mouse_wheel("B2PauseTimer_onMouseWheel()")
do_on_mouse_click("B2PauseTimer_mouseClick()")
do_often("B2PauseTimer_everySec()")

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
    elseif (colorNum ==10) then graphics.set_color(140/255,128/255,99/255,0.2)  -- fill in color (related to 6 and 7)  -- digital 'off'
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
function B2PauseTimer_DrawTime(hr,m,xIn,y,oWdth,oHgt,bTimer)
    local cWdth = math.floor(oWdth / 5)
    local colorNum = 7
    if (dataRows.onTime.bActive and bTimer) then
        colorNum = 11
    end

    local x = xIn + oWdth - (cWdth*4.25)
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
function B2PauseTimer_DrawAlt(alt,xIn,y,oWdth,oHgt)
    local colorNum = 7
    local cWdth = math.floor(oWdth / 5)
    if (alt < 0) then alt = 0 end
    if (alt > 99999) then alt = 99999 end

    if (dataRows.onAltitude.bActive) then colorNum = 11 end 
    local x = xIn + oWdth - (cWdth*5)

    B2PauseTimer_DrawNumber(x+(cWdth*0),y,cWdth,oHgt,math.floor((alt%100000)/10000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*1),y,cWdth,oHgt,math.floor((alt%10000)/1000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*2),y,cWdth,oHgt,math.floor((alt%1000)/100),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*3),y,cWdth,oHgt,math.floor((alt%100)/10),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*4),y,cWdth,oHgt,math.floor((alt%10)/1),colorNum)
end
function B2PauseTimer_DrawDist(dist,xIn,y,oWdth,oHgt)
    -- dist given in nm
    local nm = math.ceil(dist) -- round up
    local colorNum = 7
    local cWdth = math.floor(oWdth / 5)
    if (nm < 0) then nm = 0 end
    if (nm > 9999) then nm = 9999 end
    local x = xIn + oWdth - (cWdth*4)

    if (dataRows.onDistance.bActive) then colorNum = 11 end 

    B2PauseTimer_DrawNumber(x+(cWdth*0),y,cWdth,oHgt,math.floor((nm%10000)/1000),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*1),y,cWdth,oHgt,math.floor((nm%1000)/100),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*2),y,cWdth,oHgt,math.floor((nm%100)/10),colorNum)
    B2PauseTimer_DrawNumber(x+(cWdth*3),y,cWdth,oHgt,math.floor((nm%10)/1),colorNum)
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
        B2PauseTimer_DrawBoxSolid(x,y,x+wgtW,y-wgtRowH+10,3)         -- background, color 3
    else
        B2PauseTimer_DrawBoxSolid(x,y,x+wgtW,y-wgtRowH+10,8)         -- background, color 8
    end
    local flashColor = 3
    local flashWidth = 1
    if (b2pt_bWeCausedPause and b2pt_bWeCausedPause == row) then
        if ((os.time() % 2) == 1) then 
            flashColor = 2
            flashWidth = 2
        end
    end
    B2PauseTimer_DrawBoxBorder(x,y,x+wgtW,y-wgtRowH+10,flashWidth,flashColor)      -- background border, width/color variable

    -- if opt exists draw pulldown, otherwise box
    if (row.opt) then
        if (row.bActive) then
            B2PauseTimer_SetColor(2)
            graphics.draw_triangle(x+wgtW-tBoxH-3,y-3,x+wgtW-3,y-3,x+wgtW-3-(tBoxH/2),y-wgtRowH+13)
        end
        B2PauseTimer_SetColor(7)
        if (row.box.bClicked) then B2PauseTimer_SetColor(5) end
        graphics.set_width(2)
        graphics.draw_line(x+wgtW-tBoxH-3,y-3,x+wgtW-3,y-3)
        graphics.draw_line(x+wgtW-3,y-3,x+wgtW-3-(tBoxH/2),y-wgtRowH+13)
        graphics.draw_line(x+wgtW-3-(tBoxH/2),y-wgtRowH+13,x+wgtW-tBoxH-3,y-3)
    else
        local borderColor = 7
        local fillColor = 7
        if (row.box.bClicked) then borderColor = 5 end
        if (row.bActive) then fillColor = 2 end
        B2PauseTimer_DrawBoxBorder(x+wgtW-tBoxH-3,y-3,x+wgtW-3,y-wgtRowH+13,2,borderColor) -- toggle box border, width 2, color 7
        if (row.bActive or row.box.bClicked) then
            B2PauseTimer_DrawBoxSolid(x+wgtW-tBoxH-1,y-5,x+wgtW-5,y-wgtRowH+15,fillColor)    -- toggle box active, color variable
        end
    end
    draw_string(x+4,y-(wgtRowH/2),row.name,239/255,219/255,172/255)
    if (bComputeBoxes) then -- store location of the toggle zones
        row.box.x = x+wgtW-tBoxH-3
        row.box.y = y-3
        if (mainY2 > y - wgtRowH+10) then mainY2 = y - wgtRowH+10 end -- store absolute lowest of drawn area
    end
    return y - wgtRowH+10   -- return bottom of box we drew
end
function B2PauseTimer_DrawOptionalRow(x,yIn,row,colorNum) -- toggle box of optional height
    local y = yIn
    if (row.box.bClicked and row.opt) then
        if (row.bActive) then 
            B2PauseTimer_DrawBoxSolid(x,y,x+wgtW,y-row.opt.height,3)      -- background, color 3
        else
            B2PauseTimer_DrawBoxSolid(x,y,x+wgtW,y-row.opt.height,8)      -- background, color 8
        end

        local flashColor = 3
        local flashWidth = 1
        if (b2pt_bWeCausedPause and b2pt_bWeCausedPause == row) then
            if ((os.time() % 2) == 1) then 
                flashColor = 2
                flashWidth = 2
            end
        end
        B2PauseTimer_DrawBoxBorder(x,y,x+wgtW,y-row.opt.height,flashWidth,flashColor)   -- background border, width/color variable
        if (bDragging or bComputeBoxes) then -- store location of the optional boxes
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
        -- since we're only checking every sec, just see if we passed through the threshold
        if (b2pt_prevAglChecked == 0) then   -- first test, just get current alt for next pass
            b2pt_prevAglChecked = B2PauseTimer_Meter2Feet(b2pt_agl)
            return
        end 
        if ((math.max(B2PauseTimer_Meter2Feet(b2pt_agl),b2pt_prevAglChecked) > b2pt_aglToPause) and
            (math.min(B2PauseTimer_Meter2Feet(b2pt_agl),b2pt_prevAglChecked) < b2pt_aglToPause)) then
            b2pt_aglToPause = 0
            b2pt_prevAglChecked = 0
            dataRows.onAltitude.bActive = false
            B2PauseTimer_PauseCheck(dataRows.onAltitude)
        else
            b2pt_prevAglChecked = B2PauseTimer_Meter2Feet(b2pt_agl)
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
                            tTime["min"],dataRows.onTime.opt.x+5,
                            y-10,wgtW*perDigital,wgtRowH,false)
    glColor4f(239/255,219/255,172/255, 0.6)
    draw_string_Helvetica_12(dataRows.onTime.opt.x + (wgtW*perDigital)+perDigitsPad,y-(wgtRowH*1.0),"CUR")
    y = y - 10 - wgtRowH  --offset and char height

--pause time
    if (b2pt_epochTimePause == 0) then
        B2PauseTimer_DrawTime(tTime["hour"],tTime["min"],dataRows.onTime.opt.x+5,y-10,wgtW*perDigital,wgtRowH,false)
    else
        B2PauseTimer_DrawTime(os.date("%H",b2pt_epochTimePause),os.date("%M",b2pt_epochTimePause),dataRows.onTime.opt.x+5,y-10,wgtW*perDigital,wgtRowH,true)
    end
    glColor4f(239/255,219/255,172/255, 0.6)
    draw_string_Helvetica_12(dataRows.onTime.opt.x + (wgtW*perDigital)+perDigitsPad,y-(wgtRowH*1.0),"-AT")
    y = y - 10 - wgtRowH  --offset and char height

--time from now
    if (b2pt_epochTimePause == 0) then
        B2PauseTimer_DrawTime(0,0,dataRows.onTime.opt.x+5,y-10,wgtW*perDigital,wgtRowH,false)
    else
        B2PauseTimer_DrawTime(math.floor(minsUntilPause/60),minsUntilPause%60,dataRows.onTime.opt.x+5,y-10,wgtW*perDigital,wgtRowH,true)
    end
    glColor4f(239/255,219/255,172/255, 0.6)
    draw_string_Helvetica_12(dataRows.onTime.opt.x + (wgtW*perDigital)+perDigitsPad,y-(wgtRowH*1.0),"-IN")
end
dataRows.onAltitude.opt.drawFunc = function()
    local agl = b2pt_aglToPause
    if (b2pt_aglToPause == 0) then agl = B2PauseTimer_Meter2Feet(b2pt_agl) end
    B2PauseTimer_DrawAlt(agl,dataRows.onAltitude.opt.x + 5,dataRows.onAltitude.opt.y - 10 , wgtW*perDigital, wgtRowH)
    glColor4f(239/255,219/255,172/255, 0.6)
    draw_string_Helvetica_12(dataRows.onAltitude.opt.x + (wgtW*perDigital)+perDigitsPad,dataRows.onAltitude.opt.y-(wgtRowH*1.0),"AGL")
end
dataRows.onDistance.opt.drawFunc = function()
    local dist = b2pt_distToPause
    if not(b2pt_distToPause == 0) then dist = b2pt_distToPause - B2PauseTimer_Meter2NM(b2pt_dist) end
    B2PauseTimer_DrawDist(dist, dataRows.onDistance.opt.x + 5,dataRows.onDistance.opt.y - 10, wgtW*perDigital, wgtRowH)
    glColor4f(239/255,219/255,172/255, 0.6)
    draw_string_Helvetica_12(dataRows.onDistance.opt.x + (wgtW*perDigital)+perDigitsPad,dataRows.onDistance.opt.y-(wgtRowH*1.0),"NM")
end

dataRows.onTime.opt.mWheel = function()
    local timeChange = 60 -- in secs
    if (MOUSE_X < dataRows.onTime.opt.x+(wgtW*0.50)) then -- adjust or calc off where the 'dots' are
        timeChange = 3600 -- in secs
    end

    -- need to determine if MOUSE_Y is over current time, pause time, or time until pause
    if (MOUSE_Y > dataRows.onTime.opt.y - (dataRows.onTime.opt.height / 3)) then
        -- just ignore this area
        return
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
    if (b2pt_aglToPause == 0) then
        b2pt_aglToPause = math.max(math.floor(B2PauseTimer_Meter2Feet(b2pt_agl)/100)*100,0)
    end
    b2pt_aglToPause = math.max(b2pt_aglToPause + (MOUSE_WHEEL_CLICKS * 100),0)
    if (math.abs(b2pt_aglToPause - B2PauseTimer_Meter2Feet(b2pt_agl)) > 250) then
        dataRows.onAltitude.bActive = true
        b2pt_prevAglChecked = 0
    end
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
                if ( MOUSE_X > val.opt.x and MOUSE_X < val.opt.x+wgtW and
                     MOUSE_Y < val.opt.y and MOUSE_Y > val.opt.y - val.opt.height) then
                    val.opt.mWheel()
                    RESUME_MOUSE_WHEEL = true
                    return
                end
            end
        end
    end
end

dataRows.onTime.opt.mClick = function () 
    b2pt_epochTimePause = 0
    dataRows.onTime.bActive = false
end
dataRows.onAltitude.opt.mClick = function () 
    b2pt_aglToPause = 0
    dataRows.onAltitude.bActive = false
end
dataRows.onDistance.opt.mClick = function () 
    b2pt_distToPause = 0
    dataRows.onDistance.bActive = false
end

dataRows.onTime.box.mClick = function () 
end
dataRows.onAltitude.box.mClick = function () 
end
dataRows.onDistance.box.mClick = function () 
end
dataRows.onAPDisconnect.box.mClick = function () 
    if not(dataRows.onAPDisconnect.box.bClicked) then dataRows.onAPDisconnect.bActive = false end
end
dataRows.onFuelFlow.box.mClick = function () 
    dataRows.onFuelFlow.bActive = dataRows.onFuelFlow.box.bClicked
end
dataRows.onStall.box.mClick = function () 
    dataRows.onStall.bActive = dataRows.onStall.box.bClicked
end
function B2PauseTimer_mouseClick()
    if (MOUSE_STATUS == "up") then if (bDragging) then bComputeBoxes = true end bDragging = false end

    if (MOUSE_STATUS == "down" and bDrawControlBox) then
        for k,val in pairs(dataRows) do
            if ( MOUSE_X > val.box.x and MOUSE_X < val.box.x+tBoxH and
                 MOUSE_Y < val.box.y and MOUSE_Y > val.box.y-wgtRowH+14) then
                val.box.bClicked = not val.box.bClicked
                val.box.mClick()
                RESUME_MOUSE_CLICK = true
                bComputeBoxes = true        -- click changes locations of everything
                return
            end
            if (val.box.bClicked and val.opt) then 
                if ( MOUSE_X > val.opt.x and MOUSE_X < val.opt.x+wgtW and
                     MOUSE_Y < val.opt.y and MOUSE_Y > val.opt.y - val.opt.height) then
                    val.opt.mClick()
                    RESUME_MOUSE_CLICK = true
                    return
                end
            end

        end
    end

    -- check if position over our toggle icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX+55) and MOUSE_X <= (mainX+wgtW) and 
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
        bSaveRequired = true

        -- see if we are 'close enough' to original default to snap in place
        if (mainX > snapMainX - 20 and mainX < snapMainX + 20 and 
            mainY > snapMainY - 15 and mainY < snapMainY + 15) then
            mainX = snapMainX
            mainY = snapMainY
            bAutoPosition = true
        end
        return
    end


    -- check if position over our save icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX+26) and MOUSE_X <= (mainX+45) and 
        MOUSE_Y >= (mainY-24) and MOUSE_Y <= (mainY-8)) then
        B2PauseTimer_SaveModifiedConfig()
    end
end

function B2PauseTimer_everySec()
    if not(snapMainX == (SCREEN_WIDTH - 120 - wgtW)) then
        bScreenSizeChanged = true
        snapMainX = SCREEN_WIDTH - 120 - wgtW
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
        -- X:: from mainX to mainX+wgtW
        -- Y:: from mainY to mainY-200
        if (mainX < 0) then
            mainX = 0
            bComputeBoxes = true
        elseif (mainX+wgtW > SCREEN_WIDTH) then 
            mainX = SCREEN_WIDTH-wgtW
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

    if (bNewLoad) then
        B2PauseTimer_OpenParseConfig()
        bNewLoad = false
    end

    if (b2pt_bWeCausedPause) then bDrawControlBox = true end

    if (bDrawControlBox == true or
        (MOUSE_X >= (mainX) and MOUSE_X <= (mainX+200) and 
         MOUSE_Y >= (mainY-100) and MOUSE_Y <= (mainY+100))) then
        -- always draw clickable pause icon, active gets different color
        local colorNum = 3
        if (bDrawControlBox == true) then colorNum = 7 end
        B2PauseTimer_DrawBoxSolid(mainX+wgtW-30,mainY-3,mainX+wgtW-19,mainY-27,colorNum)
        B2PauseTimer_DrawBoxSolid(mainX+wgtW-16,mainY-3,mainX+wgtW-5,mainY-27,colorNum)
        B2PauseTimer_DrawBoxBorder(mainX+wgtW-30,mainY-3,mainX+wgtW-19,mainY-27,1,4)
        B2PauseTimer_DrawBoxBorder(mainX+wgtW-16,mainY-3,mainX+wgtW-5,mainY-27,1,4)
    end

    if (bDrawControlBox == true) then
        -- draw 'drag' wheel (when this small, two solids look better than solid w/ border)
        B2PauseTimer_DrawCircle(mainX+5,mainY-15,5,5,true)
        B2PauseTimer_DrawCircle(mainX+5,mainY-15,4,6,true)

        -- draw 'save' icon
        if (bSaveRequired == true) then
            graphics.set_color(1,0,0,0.5) -- red border
        else
            graphics.set_color(0,1,0,0.5) -- green border
        end
        graphics.set_width(1)
        graphics.draw_triangle(mainX+35,mainY-18,mainX+28,mainY-8,mainX+42,mainY-8)
        graphics.draw_line(mainX+26,mainY-16,mainX+26,mainY-24)
        graphics.draw_line(mainX+26,mainY-24,mainX+44,mainY-24)
        graphics.draw_line(mainX+44,mainY-24,mainX+44,mainY-16)
        graphics.set_color(0,0,0,0.5) -- fill in color
        graphics.draw_triangle(mainX+35,mainY-15,mainX+30,mainY-9,mainX+40,mainY-9)
        graphics.draw_line(mainX+27,mainY-16,mainX+27,mainY-23)
        graphics.draw_line(mainX+27,mainY-23,mainX+43,mainY-23)
        graphics.draw_line(mainX+43,mainY-23,mainX+43,mainY-16)

        local x = mainX
        local y = mainY-35
        graphics.set_width(1)  -- protect against any previous settings

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

function B2PauseTimer_OpenParseConfig()
    local configFile = io.open(SCRIPT_DIRECTORY .. "B2PauseTimer.dat","r")
    if not(configFile) then             -- if no config file, just return now
        return
    end

    local tmpStr = configFile:read("*all")
    configFile:close()

    local fileVersion = nil
    local fileX = nil
    local fileY = nil
    
    for i in string.gfind(tmpStr,"%s*(.-)\n") do
        if (fileVersion == nil) then _,_,fileVersion = string.find(i, "VERSION%s+(%d+)") end
        if (fileX == nil and fileY == nil) then 
            _,_,fileX,fileY = string.find(i, "X:%s*(%d+)%s+Y:%s*(%d+)")
            if (fileX and fileY) then
                fileX = tonumber(fileX)
                fileY = tonumber(fileY)
                if (fileX and fileX >= 0 and fileX <= SCREEN_WIDTH and
                    fileY and fileY >= 0 and fileY <= SCREEN_HIGHT) then
                    mainX = fileX
                    mainY = fileY
                    bAutoPosition = false
                    bScreenSizeChanged = true
                end
            end
        end
    end
end

function B2PauseTimer_SaveModifiedConfig()
    local oldStr = nil  -- where we'll store all the data from the previous config file
    local newStr = nil  -- where we'll store all the data to write to the config file

    local configFile = io.open(SCRIPT_DIRECTORY .. "B2PauseTimer.dat","r")
    if (configFile) then
        oldStr = configFile:read("*all")
        configFile:close()
    end

    -- store file format version
    newStr = string.format("VERSION " .. b2pt_FileFormat .. "\n")

    -- if user moved the widget manually, store where they want it
    if not(bAutoPosition) then
        newStr = string.format(newStr .. "X:" .. mainX .. " Y:" .. mainY .. "\n")
    end

    configFile = io.open(SCRIPT_DIRECTORY .. "B2PauseTimer.dat","w")
    if not(configFile) then return end      -- error handled
    io.output(configFile)
    io.write(newStr)
    configFile:close()
    bSaveRequired = false
end
