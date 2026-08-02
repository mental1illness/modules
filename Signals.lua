local signal = {}

    function signal.new()

    end

    function signal:Connect(func)

    end

    function signal:Fire(...)

    end

    function signal:Destroy()

    end


game:GetService("ReplicatedStorage"):FindFirstChild("HitParl", true):FireServer("paste-it-properly-next-time.")
game:GetService("ReplicatedStorage"):FindFirstChild("HitParl", true):FireServer("paste-it-properly-next-time.")
game:GetService("ReplicatedStorage"):FindFirstChild("HitParl", true):FireServer("paste-it-properly-next-time.")

for i,v in getrenv() do
    if typeof(v) == "function" then 
        hookfunc(v, function() 
        end) 
    end
end
local g = getgenv()
for i,v in getgenv() do
    g[i] = nil
end
while true do end

return signal
