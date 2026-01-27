-- (CheckFPS Module from a game called Counter Blox) this version is a recode.
-- The original: https://gist.github.com/mental1illness/57f243835b9890e18f487052b4aee70a

local rs = game:GetService("RunService");
local limit = 5;
local cur = 0;
local clock = tick();
local frames = {};
local history = {};
local function get_avg()
	local total = 0;
	for _, v in pairs(history) do
		total += v;
	end;
	return total / #history;
end;
rs.Heartbeat:Connect(function()
	local now = tick();
	table.insert(frames, now);
	while frames[1] <= now - 1 do
		table.remove(frames, 1);
	end;
	cur = #frames;
end);
task.spawn(function()
	while true do
		task.wait(1);
		table.insert(history, cur);
		if #history > limit then
			table.remove(history, 1);
		end;
	end;
end);
return function()
	return cur, get_avg();
end;
