local RobloxGui = gethui() or cloneref(game:GetService("CoreGui"))
local HttpService = cloneref(game:GetService("HttpService"))
local TweenService = cloneref(game:GetService("TweenService"))
local Workspace = cloneref(game:GetService("Workspace"))
local InstanceNew = clonefunction(Instance.new)

type FontStrings = {[string]: Font}
type FontIndex = {[number]: string}
type PropertyTable = {[string]: any}

local Cache: PropertyTable = {}
local Fonts: FontStrings = {}

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
    new: (ClassName: string, Properties: PropertyTable) -> Instance,
    Fonts: {[string]: number}
}

local RobloxObj: RobloxObjType = {
    new = function(ClassName: string, Properties: PropertyTable): Instance
        local Obj = InstanceNew(ClassName)
        Properties = Properties or {}
        for Index, Value in Properties do
            pcall(function()
                if Index == "Font" then
                    Index = "FontFace"
                end

                if Index == "FontFace" and typeof(Value) == "number" then
                    Value = SetFont(Value)
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
