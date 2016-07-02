local device = require("loader.device")
local display = {}


local ResolutionPolicy = {
    EXACT_FIT = 0,
    NO_BORDER = 1,
    SHOW_ALL  = 2,
    FIXED_HEIGHT  = 3,
    FIXED_WIDTH  = 4,
    FILL_ALL = 5,
    UNKNOWN  = 6,
}

--Color3B
local function c3b( _r,_g,_b )
    return { r = _r, g = _g, b = _b }
end
display.c3b = c3b

--Color4B
local function c4b( _r,_g,_b,_a )
    return { r = _r, g = _g, b = _b, a = _a }
end
display.c4b = c4b

--Color4F
local function c4f( _r,_g,_b,_a )
    return { r = _r, g = _g, b = _b, a = _a }
end
display.c4f = c4f

--Point
local function ccp(_x,_y)
    if nil == _y then
         return { x = _x.x, y = _x.y }
    else
         return { x = _x, y = _y }
    end
end
display.ccp = ccp

local sharedDirector         = cc.Director:getInstance()
local sharedTextureCache     = cc.Director:getInstance():getTextureCache()
local sharedSpriteFrameCache = cc.SpriteFrameCache:getInstance()
local sharedAnimationCache   = cc.AnimationCache:getInstance()

if DEBUG_FPS then
    sharedDirector:setDisplayStats(true)
else
    sharedDirector:setDisplayStats(false)
end

-- check device screen size
local glview = sharedDirector:getOpenGLView()
if nil == glview then
    glview = cc.GLViewImpl:createWithRect("QuickCocos",
        cc.rect(0, 0, CONFIG_SCREEN_WIDTH or 900, CONFIG_SCREEN_HEIGHT or 640))
    sharedDirector:setOpenGLView(glview)
end

local size = glview:getFrameSize()
display.sizeInPixels = {width = size.width, height = size.height}

local w = display.sizeInPixels.width
local h = display.sizeInPixels.height

if CONFIG_SCREEN_WIDTH == nil or CONFIG_SCREEN_HEIGHT == nil then
    CONFIG_SCREEN_WIDTH = w
    CONFIG_SCREEN_HEIGHT = h
end

if not CONFIG_SCREEN_AUTOSCALE then
    if w > h then
        CONFIG_SCREEN_AUTOSCALE = "FIXED_HEIGHT"
    else
        CONFIG_SCREEN_AUTOSCALE = "FIXED_WIDTH"
    end
else
    CONFIG_SCREEN_AUTOSCALE = string.upper(CONFIG_SCREEN_AUTOSCALE)
end

local scale, scaleX, scaleY

if CONFIG_SCREEN_AUTOSCALE and CONFIG_SCREEN_AUTOSCALE ~="NONE" then
    if type(CONFIG_SCREEN_AUTOSCALE_CALLBACK) == "function" then
        scaleX, scaleY = CONFIG_SCREEN_AUTOSCALE_CALLBACK(w, h, device.model)
    end

    if CONFIG_SCREEN_AUTOSCALE == "FILL_ALL" then
        CONFIG_SCREEN_WIDTH = w
        CONFIG_SCREEN_HEIGHT = h
        scale = 1.0
        if cc.bPlugin_ then
            glview:setDesignResolutionSize(CONFIG_SCREEN_WIDTH, CONFIG_SCREEN_HEIGHT, ResolutionPolicy.NO_BORDER)
        else
            glview:setDesignResolutionSize(CONFIG_SCREEN_WIDTH, CONFIG_SCREEN_HEIGHT, ResolutionPolicy.FILL_ALL)
        end
    else
        if not scaleX or not scaleY then
            scaleX, scaleY = w / CONFIG_SCREEN_WIDTH, h / CONFIG_SCREEN_HEIGHT
        end

        if CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
            scale = scaleX
            CONFIG_SCREEN_HEIGHT = h / scale
        elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
            scale = scaleY
            CONFIG_SCREEN_WIDTH = w / scale
        else
            scale = 1.0
            print(string.format("display - invalid CONFIG_SCREEN_AUTOSCALE \"%s\"", CONFIG_SCREEN_AUTOSCALE))
        end
        glview:setDesignResolutionSize(CONFIG_SCREEN_WIDTH, CONFIG_SCREEN_HEIGHT, ResolutionPolicy.NO_BORDER)
    end
else
    CONFIG_SCREEN_WIDTH = w
    CONFIG_SCREEN_HEIGHT = h
    scale = 1.0
end

local winSize = sharedDirector:getWinSize()
display.screenScale        = 2.0
display.contentScaleFactor = scale
display.size               = {width = winSize.width, height = winSize.height}
display.width              = display.size.width
display.height             = display.size.height
display.cx                 = display.width / 2
display.cy                 = display.height / 2
display.c_left             = -display.width / 2
display.c_right            = display.width / 2
display.c_top              = display.height / 2
display.c_bottom           = -display.height / 2
display.left               = 0
display.right              = display.width
display.top                = display.height
display.bottom             = 0
display.widthInPixels      = display.sizeInPixels.width
display.heightInPixels     = display.sizeInPixels.height

display.COLOR_WHITE = c3b(255, 255, 255)
display.COLOR_BLACK = c3b(0, 0, 0)
display.COLOR_RED   = c3b(255, 0, 0)
display.COLOR_GREEN = c3b(0, 255, 0)
display.COLOR_BLUE  = c3b(0, 0, 255)

display.AUTO_SIZE      = 0
display.FIXED_SIZE     = 1
display.LEFT_TO_RIGHT  = 0
display.RIGHT_TO_LEFT  = 1
display.TOP_TO_BOTTOM  = 2
display.BOTTOM_TO_TOP  = 3

display.CENTER        = 1
display.LEFT_TOP      = 2; display.TOP_LEFT      = 2
display.CENTER_TOP    = 3; display.TOP_CENTER    = 3
display.RIGHT_TOP     = 4; display.TOP_RIGHT     = 4
display.CENTER_LEFT   = 5; display.LEFT_CENTER   = 5
display.CENTER_RIGHT  = 6; display.RIGHT_CENTER  = 6
display.BOTTOM_LEFT   = 7; display.LEFT_BOTTOM   = 7
display.BOTTOM_RIGHT  = 8; display.RIGHT_BOTTOM  = 8
display.BOTTOM_CENTER = 9; display.CENTER_BOTTOM = 9

display.ANCHOR_POINTS = {
    ccp(0.5, 0.5),  -- CENTER
    ccp(0, 1),      -- TOP_LEFT
    ccp(0.5, 1),    -- TOP_CENTER
    ccp(1, 1),      -- TOP_RIGHT
    ccp(0, 0.5),    -- CENTER_LEFT
    ccp(1, 0.5),    -- CENTER_RIGHT
    ccp(0, 0),      -- BOTTOM_LEFT
    ccp(1, 0),      -- BOTTOM_RIGHT
    ccp(0.5, 0),    -- BOTTOM_CENTER
}

display.SCENE_TRANSITIONS = {
    CROSSFADE       = {cc.TransitionCrossFade, 2},
    FADE            = {cc.TransitionFade, 3, c3b(0, 0, 0)},
    FADEBL          = {cc.TransitionFadeBL, 2},
    FADEDOWN        = {cc.TransitionFadeDown, 2},
    FADETR          = {cc.TransitionFadeTR, 2},
    FADEUP          = {cc.TransitionFadeUp, 2},
    FLIPANGULAR     = {cc.TransitionFlipAngular, 3, cc.TRANSITION_ORIENTATION_LEFT_OVER},
    FLIPX           = {cc.TransitionFlipX, 3, cc.TRANSITION_ORIENTATION_LEFT_OVER},
    FLIPY           = {cc.TransitionFlipY, 3, cc.TRANSITION_ORIENTATION_UP_OVER},
    JUMPZOOM        = {cc.TransitionJumpZoom, 2},
    MOVEINB         = {cc.TransitionMoveInB, 2},
    MOVEINL         = {cc.TransitionMoveInL, 2},
    MOVEINR         = {cc.TransitionMoveInR, 2},
    MOVEINT         = {cc.TransitionMoveInT, 2},
    PAGETURN        = {cc.TransitionPageTurn, 3, false},
    ROTOZOOM        = {cc.TransitionRotoZoom, 2},
    SHRINKGROW      = {cc.TransitionShrinkGrow, 2},
    SLIDEINB        = {cc.TransitionSlideInB, 2},
    SLIDEINL        = {cc.TransitionSlideInL, 2},
    SLIDEINR        = {cc.TransitionSlideInR, 2},
    SLIDEINT        = {cc.TransitionSlideInT, 2},
    SPLITCOLS       = {cc.TransitionSplitCols, 2},
    SPLITROWS       = {cc.TransitionSplitRows, 2},
    TURNOFFTILES    = {cc.TransitionTurnOffTiles, 2},
    ZOOMFLIPANGULAR = {cc.TransitionZoomFlipAngular, 2},
    ZOOMFLIPX       = {cc.TransitionZoomFlipX, 3, cc.TRANSITION_ORIENTATION_LEFT_OVER},
    ZOOMFLIPY       = {cc.TransitionZoomFlipY, 3, cc.TRANSITION_ORIENTATION_UP_OVER},
}

display.TEXTURES_PIXEL_FORMAT = {}

display.DEFAULT_TTF_FONT        = "Arial"
display.DEFAULT_TTF_FONT_SIZE   = 24


-- start --

--------------------------------
-- 创建一个新场景，并返回 Scene 场景对象。
-- @function [parent=#display] newScene
-- @param string name 场景名称
-- @return Scene#Scene ret (return value: cc.Scene)  场景对象
-- @see Scene

-- end --

function display.newScene(name)
    local scene = cc.Scene:create()
    scene:setNodeEventEnabled(true)
    scene:setAutoCleanupEnabled()
    scene.name = name or "<unknown-scene>"
    return scene
end

-- start --

--------------------------------
-- 切换到新场景
-- @function [parent=#display] replaceScene
-- @param Scene newScene 场景对象
-- @param string transitionType 过渡效果名
-- @param number time 过渡时间
-- @param mixed more 过渡效果附加参数

--[[--

切换到新场景

~~~ lua

-- 使用红色做过渡色
display.replaceScene(nextScene, "fade", 0.5, c3b(255, 0, 0))

~~~

]]
-- end --

function display.replaceScene(newScene, transitionType, time, more)
    if sharedDirector:getRunningScene() then
        sharedDirector:replaceScene(newScene)
    else
        sharedDirector:runWithScene(newScene)
    end
end

-- start --

--------------------------------
-- 返回当前正在运行的场景对象
-- @function [parent=#display] getRunningScene
-- @return Scene#Scene ret (return value: cc.Scene)  场景对象

-- end --

function display.getRunningScene()
    return sharedDirector:getRunningScene()
end

-- start --

--------------------------------
-- 暂停当前场景
-- @function [parent=#display] pause

-- end --

function display.pause()
    sharedDirector:pause()
end

-- start --

--------------------------------
-- 恢复当前暂停的场景
-- @function [parent=#display] resume

-- end --

function display.resume()
    sharedDirector:resume()
end

-- start --

--------------------------------
-- 创建并返回一个 Layer 层对象
-- @function [parent=#display] newLayer
-- @see Layer

-- end --

function display.newLayer()
    local layer

    if cc.bPlugin_ then
        layer = display.newNode()
        layer:setContentSize(display.width, display.height)
        layer:setTouchEnabled(true)
    else
        layer = cc.Layer:create()
    end

    return layer
end

-- start --

--------------------------------
-- 创建一个颜色填充层
-- @function [parent=#display] newColorLayer
-- @param ccColor4B color
-- @return LayerColor#LayerColor ret (return value: cc.LayerColor) 
-- @see LayerColor

-- end --

function display.newColorLayer(color)
    local node

    if cc.bPlugin_ then
        node = display.newNode()
        local layer = cc.LayerColor:create(color)
        node:addChild(layer)
        node:setTouchEnabled(true)
        node:setTouchSwallowEnabled(true)

        node.setContentSize = function(_, ...)
            layer:setContentSize(...)
        end
        node.getContentSize = function()
            return layer:getContentSize()
        end
    else
        node = cc.LayerColor:create(color)
    end

    return node
end

-- start --

--------------------------------
-- 创建并返回一个 Node 对象
-- @function [parent=#display] newNode
-- @return Node#Node ret (return value: cc.Node)  Node对象
-- @see Node


--[[--

创建并返回一个 Node 对象

Node 对象并不能显示对象，但可以作为其他显示对象的容器（起到群组的作用）。具体请参考 Node 。

~~~ lua

local group = display.newNode()     -- 创建一个容器
group:addChild(sprite1)             -- 添加显示对象到容器中
group:addChild(sprite2)             -- 添加显示对象到容器中

-- 移动容器时，其中包含的子对象也会同时移动
transition.moveBy(group, {time = 2.0, x = 100})

~~~

]]
-- end --

function display.newNode()
    return cc.Node:create()
end

if cc.ClippingRectangleNode then
    cc.ClippingRegionNode = cc.ClippingRectangleNode
else
    cc.ClippingRectangleNode = cc.ClippingRegionNode
end

-- start --

--------------------------------
-- 创建并返回一个 ClippingRectangleNode 对象。
-- @function [parent=#display] newClippingRectangleNode
-- @param table rect 指定的区域
-- @return ClippingRectangleNode#ClippingRectangleNode ret (return value: cc.ClippingRectangleNode)  ClippingRectangleNode


--[[--

创建并返回一个 ClippingRectangleNode 对象。

创建 ClippingRectangleNode 对象时需要指定一个屏幕区域，然后在显示时，所以加入 ClippingRectangleNode 对象的内容都会进行剪裁，超出指定区域的内容不会显示。

~~~ lua

-- 剪裁区域从屏幕左下角靠内 100 点，到屏幕右上角
local rect = cc.rect(display.left + 100,
                    display.bottom + 100,
                    display.width - 200,
                    display.height - 200)
local clipnode = display.newClippingRegionNode(rect)

clipnode:addChild(sprite1)
clipnode:addChild(sprite2)

scene:addChild(clipnode)

~~~

注意：ClippingRectangleNode 的父对象其坐标必须是 0, 0。

]]
-- end --

function display.newClippingRectangleNode(rect)
    if rect then
        return cc.ClippingRegionNode:create(rect)
    else
        return cc.ClippingRegionNode:create()
    end
end

-- start --

--------------------------------
-- 创建并返回一个 ClippingRectangleNode 对象。
-- @function [parent=#display] newClippingRegionNode
-- @param table rect 指定的区域
-- @return ClippingRectangleNode#ClippingRectangleNode ret (return value: cc.ClippingRectangleNode)  ClippingRectangleNode

--[[--
旧接口,建议用display.newClippingRectangleNode代替
]]
-- end --

display.newClippingRegionNode = display.newClippingRectangleNode

-- start --

--------------------------------
-- 创建并返回一个 Sprite 显示对象。
-- @function [parent=#display] newSprite
-- @param mixed 图像名或SpriteFrame对象
-- @param number x
-- @param number y
-- @param table params
-- @return Sprite#Sprite ret (return value: cc.Sprite) 
-- @see Sprite


--[[--

创建并返回一个 Sprite 显示对象。

display.newSprite() 有三种方式创建显示对象：

-   从图片文件创建
-   从缓存的图像帧创建
-   从 SpriteFrame 对象创建

~~~ lua

-- 从图片文件创建显示对象
local sprite1 = display.newSprite("hello1.png")

-- 从缓存的图像帧创建显示对象
-- 图像帧的名字就是图片文件名，但为了和图片文件名区分，所以此处需要在文件名前添加 “#” 字符
-- 添加 “#” 的规则适用于所有需要区分图像和图像帧的地方
local sprite2 = display.newSprite("#frame0001.png")

-- 从 SpriteFrame 对象创建
local frame = display.newFrame("frame0002.png")
local sprite3 = display.newSprite(frame)

~~~

如果指定了 x,y 参数，那么创建显示对象后会调用对象的 setPosition() 方法设置对象位置。

]]
-- end --

function display.newSprite(filename, x, y, params)
    local spriteClass = nil
    local size = nil

    if params then
        spriteClass = params.class
        size = params.size
    end
    if not spriteClass then spriteClass = cc.Sprite end

    local t = type(filename)
    if t == "userdata" then t = tolua.type(filename) end
    local sprite

    if not filename then
        sprite = spriteClass:create()
    elseif t == "string" then
        if string.byte(filename) == 35 then -- first char is #
            local frame = display.newSpriteFrame(string.sub(filename, 2))
            if frame then
                if params and params.capInsets then
                    sprite = spriteClass:createWithSpriteFrame(frame, params.capInsets)
                else
                    sprite = spriteClass:createWithSpriteFrame(frame)
                end
            end
        else
            if display.TEXTURES_PIXEL_FORMAT[filename] then
                cc.Texture2D:setDefaultAlphaPixelFormat(display.TEXTURES_PIXEL_FORMAT[filename])
                sprite = spriteClass:create(filename)
                cc.Texture2D:setDefaultAlphaPixelFormat(cc.TEXTURE2D_PIXEL_FORMAT_RGBA8888)
            else
                if params and params.capInsets then
                    sprite = spriteClass:create(params.capInsets, filename)
                else
                    sprite = spriteClass:create(filename)
                end
            end
        end
    elseif t == "cc.SpriteFrame" then
        sprite = spriteClass:createWithSpriteFrame(filename)
    elseif t == "cc.Texture2D" then
        sprite = spriteClass:createWithTexture(filename)
    else
        print("display.newSprite() - invalid filename value type")
        sprite = spriteClass:create()
    end

    if sprite then
        if x and y then sprite:setPosition(x, y) end
        if size then sprite:setContentSize(size) end
    else
        print("display.newSprite() - create sprite failure, filename %s", tostring(filename))
        sprite = spriteClass:create()
    end

    return sprite
end

-- start --

--------------------------------
-- 创建并返回一个 Sprite9Scale 显示对象。
-- @function [parent=#display] newScale9Sprite
-- @param string filename 图像名
-- @param integer x
-- @param integer y
-- @param table size
-- @return Scale9Sprite#Scale9Sprite ret (return value: ccui.Scale9Sprite) Sprite9Scale显示对象


--[[--

创建并返回一个 Sprite9Scale 显示对象。

格式：

sprite = display.newScale9Sprite(图像名, [x, y], [size 对象])

Sprite9Scale 就是通常所說的“九宫格”图像。一个矩形图像会被分为 9 部分，然后根据要求拉伸图像，同时保证拉伸后的图像四边不变形。

~~~ lua

-- 创建一个 Scale9 图像，并拉伸到 400, 300 点大小
local sprite = display.newScale9Sprite("Box.png", 0, 0, cc.size(400, 300))

~~~

]]
-- end --

function display.newScale9Sprite(filename, x, y, size, capInsets)
    local scale9sp = ccui.Scale9Sprite or cc.Scale9Sprite
    return display.newSprite(filename, x, y, {class = scale9sp, size = size, capInsets = capInsets})
end

-- start --

--------------------------------
-- 创建并返回一个平铺的 Sprite 显示对象
-- @function [parent=#display] newTilesSprite
-- @param string filename 图像名
-- @param cc.rect rect    平铺范围
-- @return Sprite#Sprite ret (return value: cc.Sprite)

-- end --

function display.newTilesSprite(filename, rect)
    if not rect then
        rect = cc.rect(0, 0, display.width, display.height)
    end
    local sprite = cc.Sprite:create(filename, rect)
    if not sprite then
        print("display.newTilesSprite() - create sprite failure, filename %s", tostring(filename))
        return
    end

    sprite:getTexture():setTexParameters(gl.LINEAR, gl.LINEAR, gl.REPEAT, gl.REPEAT)

    display.align(sprite, display.LEFT_BOTTOM, 0, 0)

    return sprite
end

-- start --

--------------------------------
-- 用位图字体创建文本显示对象，并返回 Label 对象。
-- @function [parent=#display] newBMFontLabel
-- @param table params 参数表格对象
-- @return Label#Label ret (return value: cc.Label)  Label对象

--[[--

用位图字体创建文本显示对象，并返回 Label 对象。

BMFont 通常用于显示英文内容，因为英文字母加数字和常用符号也不多，生成的 BMFont 文件较小。如果是中文，应该用 TTFLabel。

可用参数：

-    text: 要显示的文本
-    font: 字体文件名
-    align: 文字的水平对齐方式（可选）
-    maxLineWidth: 最大行宽（可选）
-    offsetX: 图像的X偏移量（可选）
-    offsetY: 图像的Y偏移量（可选）
-    x, y: 坐标（可选）

~~~ lua

local label = display.newBMFontLabel({
    text = "Hello",
    font = "UIFont.fnt",
})

~~~

]]
-- end --

function display.newBMFontLabel(params)
    assert(type(params) == "table",
           "[framework.display] newBMFontLabel() invalid params")

    local text      = tostring(params.text)
    local font      = params.font
    local textAlign = params.align or cc.TEXT_ALIGNMENT_LEFT
    local maxLineW  = params.maxLineWidth or 0
    local offsetX   = params.offsetX or 0
    local offsetY   = params.offsetY or 0
    local x, y      = params.x, params.y
    assert(font ~= nil, "framework.display.newBMFontLabel() - not set font")

    local label = cc.Label:createWithBMFont(font, text, textAlign, maxLineW, ccp(offsetX, offsetY));
    if not label then return end

    if type(x) == "number" and type(y) == "number" then
        label:setPosition(x, y)
    end

    return label
end

-- start --

--------------------------------
-- 使用 TTF 字体创建文字显示对象，并返回 Label 对象。
-- @function [parent=#display] newTTFLabel
-- @param table params 参数表格对象
-- @return Label#Label ret (return value: cc.Label)  Label对象

--[[--

使用 TTF 字体创建文字显示对象，并返回 Label 对象。

可用参数：

-    text: 要显示的文本
-    font: 字体名，如果是非系统自带的 TTF 字体，那么指定为字体文件名
-    size: 文字尺寸，因为是 TTF 字体，所以可以任意指定尺寸
-    color: 文字颜色（可选），用 c3b() 指定，默认为白色
-    align: 文字的水平对齐方式（可选）
-    valign: 文字的垂直对齐方式（可选），仅在指定了 dimensions 参数时有效
-    dimensions: 文字显示对象的尺寸（可选），使用 cc.size() 指定
-    x, y: 坐标（可选）

align 和 valign 参数可用的值：

-    cc.TEXT_ALIGNMENT_LEFT 左对齐
-    cc.TEXT_ALIGNMENT_CENTER 水平居中对齐
-    cc.TEXT_ALIGNMENT_RIGHT 右对齐
-    cc.VERTICAL_TEXT_ALIGNMENT_TOP 垂直顶部对齐
-    cc.VERTICAL_TEXT_ALIGNMENT_CENTER 垂直居中对齐
-    cc.VERTICAL_TEXT_ALIGNMENT_BOTTOM 垂直底部对齐

~~~ lua

-- 创建一个居中对齐的文字显示对象
local label = display.newTTFLabel({
    text = "Hello, World",
    font = "Marker Felt",
    size = 64,
    align = cc.TEXT_ALIGNMENT_CENTER -- 文字内部居中对齐
})

-- 左对齐，并且多行文字顶部对齐
local label = display.newTTFLabel({
    text = "Hello, World\n您好，世界",
    font = "Arial",
    size = 64,
    color = c3b(255, 0, 0), -- 使用纯红色
    align = cc.TEXT_ALIGNMENT_LEFT,
    valign = cc.VERTICAL_TEXT_ALIGNMENT_TOP,
    dimensions = cc.size(400, 200)
})

~~~

]]
-- end --

function display.newTTFLabel(params)
    assert(type(params) == "table",
           "[framework.display] newTTFLabel() invalid params")

    local text       = tostring(params.text)
    local font       = params.font or display.DEFAULT_TTF_FONT
    local size       = params.size or display.DEFAULT_TTF_FONT_SIZE
    local color      = params.color or display.COLOR_WHITE
    local textAlign  = params.align or cc.TEXT_ALIGNMENT_LEFT
    local textValign = params.valign or cc.VERTICAL_TEXT_ALIGNMENT_TOP
    local x, y       = params.x, params.y
    local dimensions = params.dimensions or cc.size(0, 0)

    assert(type(size) == "number",
           "[framework.display] newTTFLabel() invalid params.size")

    local label
    if cc.FileUtils:getInstance():isFileExist(font) then
        label = cc.Label:createWithTTF(text, font, size, dimensions, textAlign, textValign)
        if label then
            label:setColor(color)
        end
    else
        label = cc.Label:createWithSystemFont(text, font, size, dimensions, textAlign, textValign)
        if label then
            label:setTextColor(color)
        end
    end

    if label then
        if x and y then label:setPosition(x, y) end
    end

    return label
end

-- start --

--------------------------------
-- 将指定的显示对象按照特定锚点对齐。
-- @function [parent=#display] align
-- @param Sprite target 显示对象
-- @param integer anchorPoint 锚点位置
-- @param integer x
-- @param integer y


--[[--

将指定的显示对象按照特定锚点对齐。

格式：

display.align(显示对象, 锚点位置, [x, y])

显示对象锚点位置：

-   display.CENTER 图像中央
-   display.LEFT_TOP,
-   display.TOP_LEFT 图像左上角
-   display.CENTER_TOP,
-   display.TOP_CENTER 图像顶部的中间
-   display.RIGHT_TOP,
-   display.TOP_RIGHT 图像顶部的中间
-   display.CENTER_LEFT,
-   display.LEFT_CENTER 图像左边的中间
-   display.CENTER_RIGHT,
-   display.RIGHT_CENTER 图像右边的中间
-   display.BOTTOM_LEFT,
-   display.LEFT_BOTTOM 图像左边的底部
-   display.BOTTOM_RIGHT,
-   display.RIGHT_BOTTOM 图像右边的底部
-   display.BOTTOM_CENTER,
-   display.CENTER_BOTTOM 图像中间的底部

~~~ lua

-- 将图像按左上角对齐，并放置在屏幕左上角
display.align(sprite, display.LEFT_TOP, 0, 0)

~~~

]]
-- end --

function display.align(target, anchorPoint, x, y)
    target:setAnchorPoint(display.ANCHOR_POINTS[anchorPoint])
    if x and y then target:setPosition(x, y) end
end

function display.addImageAsync(imagePath, callback)
    sharedTextureCache:addImageAsync(imagePath, callback)
end

-- start --

--------------------------------
-- 将指定的 Sprite Sheets 材质文件及其数据文件载入图像帧缓存。
-- @function [parent=#display] addSpriteFrames
-- @param string plistFilename 数据文件名
-- @param string image 材质文件名
-- @see Sprite Sheets


--[[--

将指定的 Sprite Sheets 材质文件及其数据文件载入图像帧缓存。

格式：

display.addSpriteFrames(数据文件名, 材质文件名)

~~~ lua

-- 同步加载纹理
display.addSpriteFrames("Sprites.plist", "Sprites.png")

-- 异步加载纹理
local cb = function(plist, image)
    -- do something
end
display.addSpriteFrames("Sprites.plist", "Sprites.png", cb)

~~~

Sprite Sheets 通俗一点解释就是包含多张图片的集合。Sprite Sheets 材质文件由多张图片组成，而数据文件则记录了图片在材质文件中的位置等信息。

]]
-- end --

function display.addSpriteFrames(plistFilename, image, handler)
    local async = type(handler) == "function"
    local asyncHandler = nil
    if async then
        asyncHandler = function()
            local texture = sharedTextureCache:getTextureForKey(image)
            assert(texture, string.format("The texture %s, %s is unavailable.", plistFilename, image))
            sharedSpriteFrameCache:addSpriteFrames(plistFilename, texture)
            handler(plistFilename, image)
        end
    end

    if display.TEXTURES_PIXEL_FORMAT[image] then
        cc.Texture2D:setDefaultAlphaPixelFormat(display.TEXTURES_PIXEL_FORMAT[image])
        if async then
            sharedTextureCache:addImageAsync(image, asyncHandler)
        else
            sharedSpriteFrameCache:addSpriteFrames(plistFilename, image)
        end
        cc.Texture2D:setDefaultAlphaPixelFormat(cc.TEXTURE2_D_PIXEL_FORMAT_BGR_A8888)
    else
        if async then
            sharedTextureCache:addImageAsync(image, asyncHandler)
        else
            sharedSpriteFrameCache:addSpriteFrames(plistFilename, image)
        end
    end
end

-- start --

--------------------------------
-- 从内存中卸载 Sprite Sheets 材质和数据文件
-- @function [parent=#display] removeSpriteFramesWithFile
-- @param string plistFilename 数据文件名
-- @param string image 材质文件名

-- end --

function display.removeSpriteFramesWithFile(plistFilename, imageName)
    sharedSpriteFrameCache:removeSpriteFramesFromFile(plistFilename)
    if imageName then
        display.removeSpriteFrameByImageName(imageName)
    end
end

-- start --

--------------------------------
-- 设置材质格式。
-- @function [parent=#display] setTexturePixelFormat
-- @param string filename 材质文件名
-- @param integer format 材质格式
-- @see Texture Pixel Format


--[[--

设置材质格式。

为了节约内存，我们会使用一些颜色品质较低的材质格式，例如针对背景图使用 cc.TEXTURE2_D_PIXEL_FORMAT_RG_B565 格式。

display.setTexturePixelFormat() 可以指定材质文件的材质格式，这样在加载材质文件时就会使用指定的格式。

]]
-- end --

function display.setTexturePixelFormat(filename, format)
    display.TEXTURES_PIXEL_FORMAT[filename] = format
end

-- start --

--------------------------------
-- 从图像帧缓存中删除一个图像。
-- @function [parent=#display] removeSpriteFrameByImageName
-- @param string imageName 图像文件名

--[[--

从图像帧缓存中删除一个图像。

有时候，某些图像仅在特定场景中使用，例如背景图。那么在场景退出时，就可以用 display.removeSpriteFrameByImageName() 从缓存里删除不再使用的图像数据。

此外，Scene 提供了 markAutoCleanupImage() 接口，可以指定场景退出时需要自动清理的图像，推荐使用。

]]
-- end --

function display.removeSpriteFrameByImageName(imageName)
    sharedSpriteFrameCache:removeSpriteFrameByName(imageName)
    cc.Director:getInstance():getTextureCache():removeTextureForKey(imageName)
end

-- start --

--------------------------------
-- 从指定的图像文件创建并返回一个批量渲染对象。
-- @function [parent=#display] newBatchNode
-- @param string image 图像文件名
-- @param integer capacity
-- @return SpriteBatchNode#SpriteBatchNode ret (return value: cc.SpriteBatchNode) 
-- @see Batch Node

--[[--

从指定的图像文件创建并返回一个批量渲染对象。

~~~ lua

local imageName = "Sprites.png"
display.addSpriteFrames("Sprites.plist", imageName) -- 载入图像到帧缓存

-- 下面的代码绘制 100 个图像只用了 1 次 OpenGL draw call
local batch = display.newBatchNode(imageName)
for i = 1, 100 do
    local sprite = display.newSprite("#Sprite0001.png")
    batch:addChild(sprite)
end

-- 下面的代码绘制 100 个图像则要使用 100 次 OpenGL draw call
local group = display.newNode()
for i = 1, 100 do
    local sprite = display.newSprite("#Sprite0001.png")
    group:addChild(sprite)
end

~~~

]]
-- end --

function display.newBatchNode(image, capacity)
    return cc.SpriteBatchNode:create(image, capacity or 100)
end

-- start --

--------------------------------
-- 创建并返回一个图像帧对象。
-- @function [parent=#display] newSpriteFrame
-- @param string 图像帧名称
-- @return SpriteFrameCache#SpriteFrameCache ret (return value: cc.SpriteFrameCache) 

--[[--

创建并返回一个图像帧对象。

~~~ lua

display.addSpriteFrames("Sprites.plist", "Sprites.png")

-- 创建一个 Sprite
local sprite = display.newSprite("#Yes.png")

-- 创建一个图像帧
local frameNo = display.newSpriteFrame("No.png")

-- 在需要时，修改 Sprite 的显示内容
sprite:setSpriteFrame(frameNo)

~~~

]]
-- end --

function display.newSpriteFrame(frameName)
    local frame = sharedSpriteFrameCache:getSpriteFrame(frameName)
    if not frame then
        print("display.newSpriteFrame() - invalid frameName %s", tostring(frameName))
    end
    return frame
end

-- start --

--------------------------------
-- 以特定模式创建一个包含多个图像帧对象的数组。
-- @function [parent=#display] newFrames
-- @param string pattern 模式字符串
-- @param integer begin 起始索引
-- @param integer length 长度
-- @param boolean isReversed 是否是递减索引
-- @return table#table ret (return value: table)  图像帧数组


--[[--

以特定模式创建一个包含多个图像帧对象的数组。

~~~ lua

-- 创建一个数组，包含 Walk0001.png 到 Walk0008.png 的 8 个图像帧对象
local frames = display.newFrames("Walk%04d.png", 1, 8)

-- 创建一个数组，包含 Walk0008.png 到 Walk0001.png 的 8 个图像帧对象
local frames = display.newFrames("Walk%04d.png", 1, 8, true)

~~~

]]
-- end --

function display.newFrames(pattern, begin, length, isReversed)
    local frames = {}
    local step = 1
    local last = begin + length - 1
    if isReversed then
        last, begin = begin, last
        step = -1
    end

    for index = begin, last, step do
        local frameName = string.format(pattern, index)
        local frame = sharedSpriteFrameCache:getSpriteFrame(frameName)
        if not frame then
            print("display.newFrames() - invalid frame, name %s", tostring(frameName))
            return
        end

        frames[#frames + 1] = frame
    end
    return frames
end

-- start --

--------------------------------
-- 以包含图像帧的数组创建一个动画对象。
-- @function [parent=#display] newAnimation
-- @param table frames 图像帧的数组
-- @param number time 每一桢动画之间的间隔时间
-- @return Animation#Animation ret (return value: cc.Animation)  Animation对象

--[[--

以包含图像帧的数组创建一个动画对象。

~~~ lua

local frames = display.newFrames("Walk%04d.png", 1, 8)
local animation = display.newAnimation(frames, 0.5 / 8) -- 0.5 秒播放 8 桢
sprite:playAnimationOnce(animation) -- 播放一次动画

~~~

]]
-- end --

function display.newAnimation(frames, time)
    local count = #frames
    -- local array = Array:create()
    -- for i = 1, count do
    --     array:addObject(frames[i])
    -- end
    time = time or 1.0 / count
    return cc.Animation:createWithSpriteFrames(frames, time)
end

-- start --

--------------------------------
-- 以指定名字缓存创建好的动画对象，以便后续反复使用。
-- @function [parent=#display] setAnimationCache
-- @param string name 名字
-- @param Animation animation 动画对象

--[[--

以指定名字缓存创建好的动画对象，以便后续反复使用。

~~~ lua

local frames = display.newFrames("Walk%04d.png", 1, 8)
local animation = display.newAnimation(frames, 0.5 / 8) -- 0.5 秒播放 8 桢
display.setAnimationCache("Walk", animation)

-- 在需要使用 Walk 动画的地方
sprite:playAnimationOnce(display.getAnimationCache("Walk")) -- 播放一次动画

~~~

]]
-- end --

function display.setAnimationCache(name, animation)
    sharedAnimationCache:addAnimation(animation, name)
end

-- start --

--------------------------------
-- 取得以指定名字缓存的动画对象，如果不存在则返回 nil。
-- @function [parent=#display] getAnimationCache
-- @param string name
-- @return Animation#Animation ret (return value: cc.Animation) 

-- end --

function display.getAnimationCache(name)
    return sharedAnimationCache:getAnimation(name)
end

-- start --

--------------------------------
-- 删除指定名字缓存的动画对象。
-- @function [parent=#display] removeAnimationCache
-- @param string name

-- end --

function display.removeAnimationCache(name)
    sharedAnimationCache:removeAnimation(name)
end

-- start --

--------------------------------
-- 从内存中卸载没有使用 Sprite Sheets 材质
-- @function [parent=#display] removeUnusedSpriteFrames

-- end --

function display.removeUnusedSpriteFrames()
    sharedSpriteFrameCache:removeUnusedSpriteFrames()
    sharedTextureCache:removeUnusedTextures()
end

-- start --

--------------------------------
-- 创建一个进度条的节点
-- @function [parent=#display] newProgressTimer
-- @param mixed image
-- @param number progressType

--[[--

创建一个进度条的节点

进度条类型有:

- display.PROGRESS_TIMER_BAR
- display.PROGRESS_TIMER_RADIAL 环形

]]

-- end --

display.PROGRESS_TIMER_BAR = 1
display.PROGRESS_TIMER_RADIAL = 0

function display.newProgressTimer(image, progresssType)
    if type(image) == "string" then
        image = display.newSprite(image)
    end

    local progress = ccprogressTimer:create(image)
    progress:setType(progresssType)
    return progress
end

-- start --

--------------------------------
-- 截屏并保存为一个文件
-- @function [parent=#display] captureScreen
-- @param function callback 截屏的回调函数
-- @param string fileName 保存的文件, 绝对路径就直接保存, 只有文件名会保存在writePath下

--[[--

~~~ lua

display.captureScreen(
    function (bSuc, filePath)
        --bSuc 截屏是否成功
        --filePath 文件保存所在的绝对路径
    end, "screen.png")

~~~

]]

-- end --

function display.captureScreen(callback, fileName)
    cc.utils:captureScreen(callback, fileName)
end

return display
