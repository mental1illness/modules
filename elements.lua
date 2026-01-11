local Utility = {} do
	function Utility:Create(_ClassName, _Properties, _Parent)
		local _Object = Instance.new(_ClassName);
		if _Properties and _Object then
			for Key, Value in pairs(_Properties) do
				_Object[Key] = Value;
			end
		end
		if _Parent then
			_Object.Parent = _Parent;
		end
		return _Object
	end
	function Utility:Tween(_Object, _TweenInfo, _Properties)
		local TweenService = game:GetService("TweenService");
		local Tween = TweenService:Create(_Object, _TweenInfo, _Properties);
		Tween:Play()
		return Tween
	end
	function Utility:AddShadow(_Instance, _Properties)
		if not _Instance then
			return
		end
		_Properties = _Properties or {}
		local Cfg = {
			PixelX = _Properties.Pixel or 1;
			PixelY = _Properties.Pixel or 1;
			Color = _Properties.Color or Color3.fromRGB(0, 0, 0);
		}
		local Shadow = _Instance:Clone();
		if _Instance:IsA("TextLabel") then
			Shadow.ZIndex = _Instance.ZIndex - 1;
			Shadow.Size = UDim2.new(1, 0, 1, 0);
			Shadow.AnchorPoint = Vector2.new(0, 0);
			Shadow.Position = UDim2.new(0, Cfg.PixelX, 0, Cfg.PixelY);
			Shadow.TextColor3 = Cfg.Color;
			Shadow.Text = _Instance.Text;
			_Instance:GetPropertyChangedSignal("Text"):Connect(function()
				Shadow.Text = _Instance.Text
			end)
			Shadow.Parent = _Instance
		elseif _Instance:IsA("Frame") then
			Shadow.ZIndex = _Instance.ZIndex - 1;
			Shadow.Size = UDim2.new(1, 0, 1, 0);
			Shadow.AnchorPoint = Vector2.new(0, 0);
			Shadow.Position = UDim2.new(0, Cfg.PixelX, 0, Cfg.PixelY);
			Shadow.BackgroundColor3 = Cfg.Color;
			Shadow.Parent = _Instance
		else
			Shadow.ZIndex = _Instance.ZIndex - 1;
			Shadow.Size = _Instance.Size + UDim2.new(0, 1, 0, 1);
			Shadow.AnchorPoint = _Instance.AnchorPoint;
			Shadow.Position = _Instance.Position + UDim2.new(0, Cfg.PixelX, 0, Cfg.PixelY);
			Shadow.Parent = _Instance
		end
	end
end
return Utility
