require "graphics"
require "math"

local b2pt_SoftwareVersion = 1
local b2pt_timeToPause = 0              -- in epoch time
local b2pt_pauseTimerActive = false

local b2pt_currentTimeX = 0
local b2pt_currentTimeY = 0
local b2pt_pauseTimeX1 = 0
local b2pt_pauseTimeY1 = 0
local b2pt_pauseTimeX2 = 0
local b2pt_pauseTimeY2 = 0


do_every_draw("B2PauseTimer_everyDraw()")
do_on_mouse_wheel("B2PauseTimer_onMouseWheel()")


--  0/255,0/255,0/255      -- black
--  211/255,10/255,10/255  -- red
--  56/255,181/255,74/255  -- green
--  71/255,71/255,70/255   -- grey


function B2PauseTimer_SetColor(colorNum)
    if     (colorNum == 1) then graphics.set_color(0/255,0/255,0/255,0.8)  -- black
    elseif (colorNum == 2) then graphics.set_color(211/255,10/255,10/255,0.8) -- red
    else                        graphics.set_color(71/255,71/255,70/255,0.05)  -- grey and default
    end
end

function B2PauseTimer_DrawHorizontal(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(0) end
    graphics.draw_rectangle(x+pixH,y+pixH,x+pixW-pixH,y-pixH)
    graphics.draw_triangle(x,y,x+pixH,y+pixH,x+pixH,y-pixH)
    graphics.draw_triangle(x+pixW,y,x+pixW-pixH,y-pixH,x+pixW-pixH,y+pixH)
end

function B2PauseTimer_DrawVertical(x, y, pixW, pixH, bActive, colorNum)
    if (bActive) then B2PauseTimer_SetColor(colorNum) else B2PauseTimer_SetColor(0) end
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
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.05*cumH),cumW*0.80,cumH*0.04,data[index][1],colorNum)
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.50*cumH),cumW*0.80,cumH*0.04,data[index][2],colorNum)
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.95*cumH),cumW*0.80,cumH*0.04,data[index][3],colorNum)

    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][4],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.90*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][5],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][6],colorNum)
    B2PauseTimer_DrawVertical  (x+(0.90*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][7],colorNum)
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

function B2PauseTimer_DrawTime(hr,m,s,x,y,wh,ht,bTimer)
    local colorNum = 1
    if (b2pt_pauseTimerActive and bTimer) then
        colorNum = 2
    end
-- draw_string(800,1100,"colorNum  " .. colorNum, "yellow")

    B2PauseTimer_DrawNumber(x+(wh*0.0),y,wh,ht,math.floor(hr/10),colorNum)  
    B2PauseTimer_DrawNumber(x+(wh*1.0),y,wh,ht,hr % 10,colorNum)            
    if (os.time() % 2 == 1) then
        B2PauseTimer_DrawDots  (x+(wh*2.0),y,wh*0.25,ht,0)          
    else
        B2PauseTimer_DrawDots  (x+(wh*2.0),y,wh*0.25,ht,colorNum)
    end
    B2PauseTimer_DrawNumber(x+(wh*2.25),y,wh,ht,math.floor(m/10),colorNum)   
    B2PauseTimer_DrawNumber(x+(wh*3.25),y,wh,ht,m % 10,colorNum)             
    if (os.time() % 2 == 1) then
        B2PauseTimer_DrawDots  (x+(wh*4.25),y,wh*0.25,ht,0)          
    else
        B2PauseTimer_DrawDots  (x+(wh*4.25),y,wh*0.25,ht,colorNum)
    end
    B2PauseTimer_DrawNumber(x+(wh*4.5),y,wh,ht,math.floor(s/10),colorNum)   
    B2PauseTimer_DrawNumber(x+(wh*5.5),y,wh,ht,s % 10,colorNum)             
end

function B2PauseTimer_onMouseWheel()
    if (MOUSE_X >= b2pt_pauseTimeX1 and MOUSE_X <= b2pt_pauseTimeX2 and
        MOUSE_Y >= b2pt_pauseTimeY2 and MOUSE_Y <= b2pt_pauseTimeY1) then
        -- mouse wheel over part of 'pause time' 
        local timeChange = 0 -- depends on which number is changing
        local charWidth = (b2pt_pauseTimeX2 - b2pt_pauseTimeX1) / 6.5
        if     (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*1.00)) then timeChange = 36000 --  10h
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*2.00)) then timeChange = 3600  --   1h
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*2.25)) then timeChange = 0     -- :
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*3.25)) then timeChange = 600   --  10m
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*4.25)) then timeChange = 60    --   1m
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*4.50)) then timeChange = 0     -- :
        elseif (MOUSE_X - b2pt_pauseTimeX1 <= (charWidth*5.50)) then timeChange = 10    --  10s
        else                                                         timeChange = 1     --   1s
        end

        if (b2pt_timeToPause == 0) then b2pt_timeToPause = os.time() end -- first time setting
        b2pt_timeToPause = b2pt_timeToPause + (MOUSE_WHEEL_CLICKS * timeChange)

        if (b2pt_timeToPause > (os.time()+86400)) then                  -- protect against 24hr rule
            b2pt_timeToPause = b2pt_timeToPause - 86400
        elseif (b2pt_timeToPause < os.time()) then
            b2pt_timeToPause = b2pt_timeToPause + 86400
        end

        RESUME_MOUSE_WHEEL = true
    end
end

function B2PauseTimer_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)

    graphics.set_width(1)  -- protect against any previous settings
    local tTime = os.date("*t", os.time())
--    draw_string(800,1300,"now: " .. os.date("%X"), "black")

--    if (b2pt_timeToPause == 0) then
--        draw_string(800,1270,"pause at: " .. os.date("%X",os.time()),"black")
--    else
--        draw_string(800,1270,"pause at: " .. os.date("%X",b2pt_timeToPause),"black")
--    end

    b2pt_currentTimeX = SCREEN_WIDTH*0.4
    b2pt_currentTimeY = SCREEN_HIGHT - 35

    -- width of 'time' is 6.5xwidth
    B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],tTime["sec"],b2pt_currentTimeX,b2pt_currentTimeY,25*0.8,25,false)
--  B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],tTime["sec"],1000,1250,75*0.8,75,false)

    -- pause time
    -- b2pt_timeToPause
    b2pt_pauseTimeX1 = b2pt_currentTimeX + (25*8)
    b2pt_pauseTimeY1 = b2pt_currentTimeY
    b2pt_pauseTimeX2 = b2pt_pauseTimeX1 + ((25*0.8) * 6.5)
    b2pt_pauseTimeY2 = b2pt_pauseTimeY1 - 25
    if (b2pt_timeToPause == 0) then
        B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],tTime["sec"],b2pt_pauseTimeX1,b2pt_pauseTimeY1,25*0.8,25,false)
    else
        B2PauseTimer_DrawTime (os.date("%H",b2pt_timeToPause),os.date("%M",b2pt_timeToPause),os.date("%S",b2pt_timeToPause),b2pt_pauseTimeX1,b2pt_pauseTimeY1,25*0.8,25,true)
        -- do we pause?
        if (b2pt_timeToPause - os.time() > 9) then b2pt_pauseTimerActive = true end
        if (b2pt_pauseTimerActive and b2pt_timeToPause == os.time()) then 
            b2pt_pauseTimerActive = false
            b2pt_timeToPause = 0
            
            if (get("sim/time/sim_speed") > 0) then
                command_once("sim/operation/pause_toggle")
            end
        end
    end

end