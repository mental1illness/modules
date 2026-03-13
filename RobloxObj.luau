local RobloxGui     = gethui() or cloneref(game:GetService("CoreGui"))
local HttpService   = cloneref(game:GetService("HttpService"))
local TweenService  = cloneref(game:GetService("TweenService"))
local Workspace     = cloneref(game:GetService("Workspace"))

local InstanceNew   = clonefunction(Instance.new)
local FromRGB       = clonefunction(Color3.fromRGB)
local UDim2New      = clonefunction(UDim2.new)

local IsA           = clonefunction(game.IsA)
local Remove        = clonefunction(game.Remove)

type FontStrings    = {[string]: Font}
type FontIndex      = {[number]: string}
type PropertyTable  = {[string]: any}

local Cache: PropertyTable  = {}
local Fonts: FontStrings    = {}

do
    local ImportFont = function(Name: string, Url: string): Font
        writefile(Name .. ".ttf", Url)

        local CustomTable = {
            Name = Name,
            faces = {
                {
                    name = "Regular",
                    weight = 400,
                    style = "normal",
                    assetId = getcustomasset(Name .. ".ttf")
                }
            }
        }

        writefile(Name .. ".json", HttpService:JSONEncode(CustomTable))
        return Font.new(getcustomasset(Name .. ".json"), Enum.FontWeight.Regular)
    end

    Fonts = {
        Tahoma = ImportFont("tahoma", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/old-tahoma.ttf")),
        TahomaBold = ImportFont("tahomabold", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/old-tahoma-bold.ttf")),
        Verdana = ImportFont("verdana", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/verdana.ttf")),
        VerdanaBold = ImportFont("verdanabold", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/verdana_bold.ttf")),
        SmallestPixel7 = ImportFont("smallestpixel7", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/smallest_pixel-7.ttf")),
        ProggyClean = ImportFont("proggyclean", game:HttpGet("https://github.com/mental1illness/storage/raw/refs/heads/main/fonts/proggyclean.ttf"))
    }
end

local FontTable: FontIndex = {
    [0] = "Tahoma",
    [1] = "TahomaBold",
    [2] = "Verdana",
    [3] = "VerdanaBold",
    [4] = "SmallestPixel7",
    [5] = "ProggyClean"
}

local SetFont = function(Number: number): Font?
    if typeof(Number) ~= "number" then return nil end
    local Name = FontTable[Number]
    if not Name then return nil end
    return Fonts[Name]
end

type RobloxObjType = {
    SetRenderProperty: (Object: Instance, Property: string, Value: any) -> Instance,
    GetRenderProperty: (Object: Instance, Property: string) -> any,
    DestroyRenderObject: (Object: Instance) -> boolean,
    new: (ClassName: string, Properties: PropertyTable) -> Instance,
    Fonts: {[string]: number}
}

local SetDefault = function(Object: Instance, ObjectType: string)
    if IsA(Object, "Frame") and ObjectType == "Circle" then
        Object.BorderSizePixel = 0
        Object.BackgroundColor3 = FromRGB(255,255,255)
        Object.Size = UDim2New(0,200,0,200)
        Object.ClipsDescendants = false

        local UICorner = InstanceNew("UICorner")
        UICorner.CornerRadius = UDim.new(1,0)
        UICorner.Parent = Object

    elseif IsA(Object, "Frame") then
        Object.BorderSizePixel = 0
        Object.BackgroundColor3 = FromRGB(255,255,255)
        Object.Size = UDim2New(0,200,0,200)
        Object.ClipsDescendants = false

    elseif IsA(Object, "TextLabel") then
        Object.BackgroundTransparency = 1
        Object.TextSize = 12
        Object.FontFace = Fonts["Tahoma"]
        Object.TextColor3 = FromRGB(255,255,255)
        Object.ClipsDescendants = false
    elseif IsA(Object, "ScreenGui") then
        Object.Parent = RobloxGui
        Object.IgnoreGuiInset = true
        Object.ResetOnSpawn = false
    end
end

local RobloxObj: RobloxObjType = {
    SetRenderProperty = function(Object: Instance, Property: string, Value: any)
        if Object and Object[Property] ~= nil then
            if Property == "Font" then
                Property = "FontFace"
            end

            if Property == "FontFace" and typeof(Value) == "number" then
                Value = SetFont(Value)
            end

            local Current = Object[Property]

            if typeof(Current) == "EnumItem" then
                Value = Current.EnumType[Value]
            end

            Object[Property] = Value
        end

        return Object
    end,
    GetRenderProperty = function(Object: Instance, Property: string)
        if Object then
            return Object[Property]
        end
        return nil
    end,
    DestroyRenderObject = function(Object: Instance)
        if Object and Object.Remove then
            Remove(Object)
        else
            return false
        end
        return true
    end,
    new = function(ClassName: string, Properties: PropertyTable): Instance
        local CustomClass = nil
        if ClassName == "Circle" then
            ClassName = "Frame"
            CustomClass = "Circle"
        end
        local Obj = InstanceNew(ClassName)
        Properties = Properties or {}
        SetDefault(Obj, CustomClass)
        
        -- print(CustomClass)
        
        for Index, Value in Properties do
            pcall(function()
                if Index == "Font" then
                    Index = "FontFace"
                end

                if Index == "FontFace" and typeof(Value) == "number" then
                    Value = SetFont(Value)
                end

                local Current = Obj[Index]

                if typeof(Current) == "EnumItem" then
                    Value = Current.EnumType[Value]
                end

                Obj[Index] = Value
                Cache[Index] = Value
            end)
        end

        return Obj
    end,

    Fonts = {
        Tahoma = 0,
        TahomaBold = 1,
        Verdana = 2,
        VerdanaBold = 3,
        SmallestPixel7 = 4,
        ProggyClean = 5
    }
}

return RobloxObj

--[[
    local ScreenGui = RobloxObj.new("ScreenGui", { DisplayOrder = 999 })
    local txt = RobloxObj.new("TextLabel", {
        Text = "Hello.",
        Size = UDim2.new(0,200,0,50),
        Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5),
        Font = RobloxObj.Fonts.ProggyClean,
        Parent = ScreenGui
    })
    RobloxObj.SetRenderProperty(txt, "Font", 4)
    RobloxObj.SetRenderProperty(txt, "TextSize", 9)
    local stroke = RobloxObj.new("UIStroke", {
        LineJoinMode = "Miter",
        Parent = txt
    })
]]
