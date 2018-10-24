require "graphics"
require "math"

local b2pt_SoftwareVersion = 1
local b2pt_timeToPause = 0              -- in epoch time

dataref("b2pt_simSpeed", "sim/time/sim_speed")

do_every_draw("B2PauseTimer_everyDraw()")

function B2PauseTimer_SetColor(bLit)
    if (bLit == true) then
        graphics.set_color(211/255,10/255,10/255,0.8)
    else
        graphics.set_color(71/255,71/255,70/255,0.05)
    end
end

function B2PauseTimer_DrawHorizontal(x, y, pixW, pixH, bLit)
    B2PauseTimer_SetColor(bLit)
    graphics.draw_rectangle(x+pixH,y+pixH,x+pixW-pixH,y-pixH)
    graphics.draw_triangle(x,y,x+pixH,y+pixH,x+pixH,y-pixH)
    graphics.draw_triangle(x+pixW,y,x+pixW-pixH,y-pixH,x+pixW-pixH,y+pixH)
end

function B2PauseTimer_DrawVertical(x, y, pixW, pixH, bLit)
    B2PauseTimer_SetColor(bLit)
    graphics.draw_rectangle(x-pixW,y-pixW,x+pixW,y-pixH+pixW)
    graphics.draw_triangle(x,y,x+pixW,y-pixW,x-pixW,y-pixW)
    graphics.draw_triangle(x-pixW,y-pixH+pixW,x+pixW,y-pixH+pixW,x,y-pixH)
end

function B2PauseTimer_DrawNumber(x,y,cumW,cumH,num)
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

    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.05*cumH),cumW*0.80,cumH*0.04,data[index][1])
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.50*cumH),cumW*0.80,cumH*0.04,data[index][2])
    B2PauseTimer_DrawHorizontal(x+(0.10*cumW),y-(0.95*cumH),cumW*0.80,cumH*0.04,data[index][3])

    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][4])
    B2PauseTimer_DrawVertical  (x+(0.90*cumW),y-(0.05*cumH),cumW*0.04,cumH*0.45,data[index][5])
    B2PauseTimer_DrawVertical  (x+(0.10*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][6])
    B2PauseTimer_DrawVertical  (x+(0.90*cumW),y-(0.50*cumH),cumW*0.04,cumH*0.45,data[index][7])
end

function B2PauseTimer_DrawDot(x,y,pixW,pixH,bLit)
    B2PauseTimer_SetColor(bLit)
    graphics.draw_triangle(x-pixW,y,x,y+pixH,x+pixW,y)
    graphics.draw_triangle(x-pixW,y,x+pixW,y,x,y-pixH)
end
function B2PauseTimer_DrawDots(x,y,cumW,cumH,bLit)
    B2PauseTimer_DrawDot(x+(0.50*cumW),y-(0.25*cumH),cumW*0.35,cumW*0.35,bLit)
    B2PauseTimer_DrawDot(x+(0.50*cumW),y-(0.75*cumH),cumW*0.35,cumW*0.35,bLit)
end

function B2PauseTimer_DrawTime(hr,m,s,x,y,ht)
    B2PauseTimer_DrawNumber(x+(ht*0.0),y,ht,ht,math.floor(hr/10))  
    B2PauseTimer_DrawNumber(x+(ht*1.0),y,ht,ht,hr % 10)            
    if (os.time() % 2 == 1) then
        B2PauseTimer_DrawDots  (x+(ht*2.0),y,ht*0.2,ht,false)          
    else
        B2PauseTimer_DrawDots  (x+(ht*2.0),y,ht*0.2,ht,true)
    end
    B2PauseTimer_DrawNumber(x+(ht*2.2),y,ht,ht,math.floor(m/10))   
    B2PauseTimer_DrawNumber(x+(ht*3.2),y,ht,ht,m % 10)             
    if (os.time() % 2 == 1) then
        B2PauseTimer_DrawDots  (x+(ht*4.2),y,ht*0.2,ht,false)          
    else
        B2PauseTimer_DrawDots  (x+(ht*4.2),y,ht*0.2,ht,true)
    end
    B2PauseTimer_DrawNumber(x+(ht*4.4),y,ht,ht,math.floor(s/10))   
    B2PauseTimer_DrawNumber(x+(ht*5.4),y,ht,ht,s % 10)             
end

function B2PauseTimer_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)

    graphics.set_width(1)
    graphics.set_color(0,1,0,1)
    local tTime = os.date("*t", os.time())
    draw_string(800,1300,"now: " .. os.date("%X") , "black")

    if (b2pt_timeToPause == 0) then
        draw_string(800,1270,"pause at: " .. os.date("%X",os.time()),"black")
    else
        draw_string(800,1270,"pause at: " .. os.date("%X",b2pt_timeToPause),"black")
    end

    B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],tTime["sec"],1000,1300,25)
    B2PauseTimer_DrawTime (tTime["hour"],tTime["min"],tTime["sec"],1000,1100,75)

end