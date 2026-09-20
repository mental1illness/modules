local bit32 = bit32

export type DecodedFrame = {
	Pixels: buffer,
	Duration: number,
}

export type DecodedGif = {
	Width: number,
	Height: number,
	Frames: {DecodedFrame},
	LoopCount: number?,
}

local GifDecoder = {}

local function fail(message: string): never
	error("GifDecoder: " .. message, 2)
end

local function u8(data: string, position: number): number
	if position > #data then fail("unexpected end of data") end
	return string.byte(data, position)
end

local function u16(data: string, position: number): number
	return u8(data, position) + u8(data, position + 1) * 256
end

local function skipSubBlocks(data: string, position: number): number
	while true do
		local size = u8(data, position)
		position += 1
		if size == 0 then return position end
		if position + size - 1 > #data then fail("truncated sub-block") end
		position += size
	end
end

local function readSubBlocks(data: string, position: number): (string, number)
	local chunks = table.create(8)
	local count = 0
	while true do
		local size = u8(data, position)
		position += 1
		if size == 0 then
			return table.concat(chunks), position
		end
		if position + size - 1 > #data then fail("truncated sub-block") end
		count += 1
		chunks[count] = string.sub(data, position, position + size - 1)
		position += size
	end
end

local function readColorTable(data: string, position: number, count: number): ({number}, number)
	local colors = table.create(count * 3)
	for i = 1, count * 3 do
		colors[i] = u8(data, position)
		position += 1
	end
	return colors, position
end

local function colorAt(colors: {number}, index: number): (number, number, number)
	local offset = index * 3 + 1
	return colors[offset], colors[offset + 1], colors[offset + 2]
end

local function clearCanvas(canvas: buffer, width: number, height: number, r: number, g: number, b: number, a: number)
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local p = (y * width + x) * 4
			buffer.writeu8(canvas, p, r)
			buffer.writeu8(canvas, p + 1, g)
			buffer.writeu8(canvas, p + 2, b)
			buffer.writeu8(canvas, p + 3, a)
		end
	end
end

local function copyBuffer(source: buffer): buffer
	local result = buffer.create(buffer.len(source))
	buffer.copy(result, 0, source, 0, buffer.len(source))
	return result
end

local function lzwDecode(compressed: string, minimumCodeSize: number, expectedPixels: number): {number}
	if minimumCodeSize < 2 or minimumCodeSize > 8 then
		fail("invalid LZW minimum code size")
	end

	local clearCode = bit32.lshift(1, minimumCodeSize)
	local endCode = clearCode + 1
	local codeSize = minimumCodeSize + 1
	local nextCode = endCode + 1
	local tablePrefix = table.create(4096)
	local tableSuffix = table.create(4096)
	local output = table.create(expectedPixels)
	local outputCount = 0
	local bitPosition = 0
	local previous: number? = nil
	local first = 0
	local sawEnd = false

	local function readCode(): number?
		if bitPosition + codeSize > #compressed * 8 then return nil end
		local value = 0
		for bit = 0, codeSize - 1 do
			local byteIndex = math.floor((bitPosition + bit) / 8) + 1
			local bitIndex = (bitPosition + bit) % 8
			local byteValue = string.byte(compressed, byteIndex)
			if bit32.band(byteValue, bit32.lshift(1, bitIndex)) ~= 0 then
				value = bit32.bor(value, bit32.lshift(1, bit))
			end
		end
		bitPosition += codeSize
		return value
	end

	local function emit(value: number)
		outputCount += 1
		if outputCount > expectedPixels then fail("LZW output exceeds frame size") end
		output[outputCount] = value
	end

	while true do
		local code = readCode()
		if code == nil then break end
		if code == clearCode then
			codeSize = minimumCodeSize + 1
			nextCode = endCode + 1
			previous = nil
			for i = 0, clearCode - 1 do
				tablePrefix[i] = -1
				tableSuffix[i] = i
			end
		elseif code == endCode then
			sawEnd = true
			break
		else
			local current = code
			if previous == nil then
				if current >= clearCode then fail("invalid first LZW code") end
				first = current
				emit(current)
				previous = current
				else
					local kwkwk = current == nextCode
					if kwkwk then
						current = previous
					local chain = current
					while chain >= clearCode do chain = tableSuffix[chain] end
					first = chain
				else
					if current > nextCode then fail("invalid LZW code") end
					local chain = current
					while chain >= clearCode do chain = tableSuffix[chain] end
					first = chain
				end

				local stack = table.create(4096)
				local stackCount = 0
				local chain = current
				while chain >= clearCode do
					stackCount += 1
					stack[stackCount] = tableSuffix[chain]
					chain = tablePrefix[chain]
					if stackCount > 4096 then fail("LZW dictionary cycle") end
				end
					stackCount += 1
					stack[stackCount] = chain
					for i = stackCount, 1, -1 do emit(stack[i]) end
					if kwkwk then emit(first) end

				if nextCode < 4096 then
					tablePrefix[nextCode] = previous
					tableSuffix[nextCode] = first
					nextCode += 1
					if nextCode == bit32.lshift(1, codeSize) and codeSize < 12 then
						codeSize += 1
					end
				end
				previous = code
			end
		end
	end

	if not sawEnd then fail("missing LZW end code") end
	if outputCount ~= expectedPixels then fail(string.format("LZW decoded %d pixels, expected %d", outputCount, expectedPixels)) end
	return output
end

local function compositeIndices(
	canvas: buffer,
	indices: {number},
	left: number,
	top: number,
	width: number,
	height: number,
	canvasWidth: number,
canvasHeight: number,
	palette: {number},
	transparentIndex: number?,
	interlaced: boolean
)
	local source = 1
	if not interlaced then
		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local index = indices[source]
				source += 1
				if index ~= transparentIndex then
					local r, g, b = colorAt(palette, index)
					local dx = left + x
					local dy = top + y
					if dx >= 0 and dx < canvasWidth and dy >= 0 and dy < canvasHeight then
						local p = (dy * canvasWidth + dx) * 4
						buffer.writeu8(canvas, p, r)
						buffer.writeu8(canvas, p + 1, g)
						buffer.writeu8(canvas, p + 2, b)
						buffer.writeu8(canvas, p + 3, 255)
					end
				end
			end
		end
		return
	end

	local passStarts = {0, 4, 2, 1}
	local passSteps = {8, 8, 4, 2}
	local y = 0
	local pass = 1
	while pass <= 4 do
		if y >= height then
			pass += 1
			if pass <= 4 then y = passStarts[pass] end
		else
			for x = 0, width - 1 do
				local index = indices[source]
				source += 1
				if index ~= transparentIndex then
					local r, g, b = colorAt(palette, index)
					local dx = left + x
					local dy = top + y
					if dx >= 0 and dx < canvasWidth and dy >= 0 and dy < canvasHeight then
						local p = (dy * canvasWidth + dx) * 4
						buffer.writeu8(canvas, p, r)
						buffer.writeu8(canvas, p + 1, g)
						buffer.writeu8(canvas, p + 2, b)
						buffer.writeu8(canvas, p + 3, 255)
					end
				end
			end
			y += passSteps[pass]
		end
	end
end

function GifDecoder.decode(data: string): DecodedGif
	assert(typeof(data) == "string", "decode expects GIF bytes as a string")
	if #data < 13 then fail("file is too short") end
	local signature = string.sub(data, 1, 6)
	if signature ~= "GIF87a" and signature ~= "GIF89a" then fail("invalid GIF signature") end

	local position = 7
	local canvasWidth = u16(data, position)
	local canvasHeight = u16(data, position + 2)
	position += 4
if canvasWidth > 1024 or canvasHeight > 1024 then fail("logical screen exceeds 1024x1024") end
	if canvasWidth == 0 or canvasHeight == 0 then fail("invalid logical screen size") end
	local packed = u8(data, position)
	local backgroundIndex = u8(data, position + 1)
	position += 3
	local globalPalette: {number}? = nil
	if bit32.band(packed, 0x80) ~= 0 then
		local count = bit32.lshift(2, bit32.band(packed, 0x07))
		globalPalette, position = readColorTable(data, position, count)
	end

	local canvas = buffer.create(canvasWidth * canvasHeight * 4)
	local backgroundR, backgroundG, backgroundB = 0, 0, 0
	if globalPalette and backgroundIndex * 3 + 3 <= #globalPalette then
		backgroundR, backgroundG, backgroundB = colorAt(globalPalette, backgroundIndex)
	end
	clearCanvas(canvas, canvasWidth, canvasHeight, backgroundR, backgroundG, backgroundB, 0)

	local frames: {DecodedFrame} = {}
	local loopCount: number? = nil
	local gceDelay = 0
	local gceTransparent: number? = nil
	local gceDisposal = 0

	while position <= #data do
		local introducer = u8(data, position)
		position += 1
		if introducer == 0x3B then
			break -- trailer
		elseif introducer == 0x21 then
			local label = u8(data, position)
			position += 1
			if label == 0xF9 then
				local blockSize = u8(data, position)
				position += 1
				if blockSize ~= 4 then fail("invalid graphic control extension") end
				local gcePacked = u8(data, position)
				gceDelay = u16(data, position + 1) * 0.01
				local transparent = u8(data, position + 3)
				position += 4
				if u8(data, position) ~= 0 then fail("invalid graphic control terminator") end
				position += 1
				gceTransparent = if bit32.band(gcePacked, 1) ~= 0 then transparent else nil
				gceDisposal = bit32.band(bit32.rshift(gcePacked, 2), 7)
			elseif label == 0xFF then
				local appSize = u8(data, position)
				position += 1
				local appId = string.sub(data, position, position + appSize - 1)
				position += appSize
				local appData
				appData, position = readSubBlocks(data, position)
				if appId == "NETSCAPE2.0" and #appData >= 3 and string.byte(appData, 1) == 1 then
					loopCount = string.byte(appData, 2) + string.byte(appData, 3) * 256
				end
			else
				position = skipSubBlocks(data, position)
			end
		elseif introducer == 0x2C then
			local left = u16(data, position)
			local top = u16(data, position + 2)
			local width = u16(data, position + 4)
			local height = u16(data, position + 6)
			local imagePacked = u8(data, position + 8)
			position += 9
			if width == 0 or height == 0 then fail("invalid image dimensions") end
			local palette = globalPalette
			if bit32.band(imagePacked, 0x80) ~= 0 then
				local count = bit32.lshift(2, bit32.band(imagePacked, 0x07))
				palette, position = readColorTable(data, position, count)
			end
			if not palette then fail("image has no color table") end
			local minimumCodeSize = u8(data, position)
			position += 1
			local compressed
			compressed, position = readSubBlocks(data, position)
			local indices = lzwDecode(compressed, minimumCodeSize, width * height)

			local before = if gceDisposal == 3 then copyBuffer(canvas) else nil
			compositeIndices(
				canvas,
				indices,
				left,
				top,
				width,
				height,
canvasHeight,
				canvasWidth,
				palette,
				gceTransparent,
				bit32.band(imagePacked, 0x40) ~= 0
			)
			table.insert(frames, {Pixels = copyBuffer(canvas), Duration = gceDelay})

			if gceDisposal == 2 then
				-- Disposal 2 restores the frame rectangle to transparent background.
				for y = top, top + height - 1 do
					for x = left, left + width - 1 do
						if x >= 0 and x < canvasWidth and y >= 0 and y < canvasHeight then
							local p = (y * canvasWidth + x) * 4
							buffer.writeu8(canvas, p, backgroundR)
							buffer.writeu8(canvas, p + 1, backgroundG)
							buffer.writeu8(canvas, p + 2, backgroundB)
							buffer.writeu8(canvas, p + 3, 0)
						end
					end
				end
			elseif gceDisposal == 3 and before then
				buffer.copy(canvas, 0, before, 0, buffer.len(before))
			end

			gceDelay = 0
			gceTransparent = nil
			gceDisposal = 0
		else
			fail(string.format("unknown block introducer 0x%02X", introducer))
		end
	end

	if #frames == 0 then fail("GIF contains no frames") end
	return {
		Width = canvasWidth,
		Height = canvasHeight,
		Frames = frames,
		LoopCount = loopCount,
	}
end

return GifDecoder
