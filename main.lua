local vec2 = require("lib.types.vec2")
local list = require("lib.list")
require("monkeypatch")

local function rng(a, b)
	if a then
		if b then
			return love.math.random() * (b - a) + a
		end
		return love.math.random() * a
	end
	return love.math.random()
end

local w, h = love.graphics.getDimensions()

local function colliding(a, b)
	return vec2.distance(a.pos, b.pos) < a.radius + b.radius
end

local function randSquare(w, h)
	return vec2(rng() * w, rng() * h)
end

local function randCircle(r)
	return vec2.rotate(vec2(r, 0), rng() * math.tau)
end

local G = 100
local dtMul = 1 -- 1
local fade = 8/255
local bodies
local focusBody

local canvas = love.graphics.newCanvas(love.graphics.getDimensions())
love.graphics.setCanvas(canvas)
love.graphics.clear(0, 0, 0, 1)
love.graphics.setCanvas()

local function changeFocus(new)
	focusBody = new
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setCanvas()
end

local newObjPos
local justMadeBody
function love.mousepressed(x, y, button)
	local pos = vec2(x, y)
	if focusBody then
		pos = -vec2(love.graphics.getDimensions())/2 + pos + focusBody.pos
	end
	if not newObjPos then
		newObjPos = pos
	else
		local newBody = {
			col = {
				r = rng(0.2, 1),
				g = rng(0.2, 1),
				b = rng(0.2, 1)
			},
			radius = 1.5,
			mass = 10,
			pos = newObjPos,
			vel = (pos - newObjPos) * 1
		}
		newBody.prevPos = newBody.pos
		bodies:add(newBody)
		justMadeBody = newBody
		newObjPos = nil
	end
end

function love.load()
	bodies = list()
	-- bodies:add({col={r=1,g=1,b=1}, radius=10, mass=1000, pos=randSquare(w,h), vel=vec2()})
	-- bodies:add({col={r=1,g=1,b=1}, radius=10, mass=10, pos=randSquare(w,h), vel=vec2()})
	-- bodies:add({col={r=1,g=1,b=1}, radius=10, mass=100, pos=randSquare(w,h), vel=vec2()})
	local screenMiddleVector = vec2(love.graphics.getDimensions())/2
	-- local mSun = 1000
	for _=1, 500 do
		local newBody = {col={r=rng(0.2,1),g=rng(0.2,1),b=rng(0.2,1)}, radius=1.5, mass=rng(1,100), pos=randSquare(w/2,h/2)+vec2(w/4,h/4), vel=randCircle(rng(20))}
		newBody.prevPos = newBody.pos
		bodies:add(newBody)
		
		-- local newBody = {
		-- 	col = {
		-- 		r = rng(0.2, 1),
		-- 		g = rng(0.2, 1),
		-- 		b = rng(0.2, 1)
		-- 	},
		-- 	radius = 2,
		-- 	mass = 1,
		-- 	pos = randSquare(w, h),
		-- 	-- vel = vec2()
		-- }
		-- local circularOrbitSpeed = math.sqrt(G * mSun / (newBody.pos-screenMiddleVector):length())
		-- newBody.vel = (newBody.pos-screenMiddleVector):rotate(math.tau/4):normalise() * circularOrbitSpeed
		-- newBody.prevPos = newBody.pos
		-- bodies:add(newBody)
	end
	-- bodies:add({col={r=1,g=1,b=1}, radius = 20, mass=mSun, pos=screenMiddleVector, vel=vec2()})
end

function love.update(dt)
	dt = dt * dtMul
	local toMerge = {}
	for i = 1, bodies.size - 1 do
		local bodyA = bodies:get(i)
		for j = i + 1, bodies.size do
			local bodyB = bodies:get(j)
			if colliding(bodyA, bodyB) then
				toMerge[#toMerge+1] = bodyA
				toMerge[#toMerge+1] = bodyB
			end
			local AtoB = bodyB.pos - bodyA.pos
			local AtoBDist2 = AtoB:length2()
			local AtoBDir = AtoB:normalise()
			local force = G * bodyA.mass * bodyB.mass / AtoBDist2
			bodyA.vel = bodyA.vel + force * AtoBDir / bodyA.mass * dt
			bodyB.vel = bodyB.vel - force * AtoBDir / bodyB.mass * dt
			-- 6.67430 x 10^-11
		end
	end
	for i = 1, #toMerge - 1, 2 do -- make new body with summed area, mass and momentum, and lerped position and colour
		local bodyA = toMerge[i]
		local bodyB = toMerge[i+1]
		if focusBody == bodyB and bodyB.mass < bodyA.mass then
			changeFocus(bodyA)
		end
		local aArea = math.tau / 2 * bodyA.radius ^ 2
		local bArea = math.tau / 2 * bodyB.radius ^ 2
		local newRadius = math.sqrt(aArea+bArea)/math.sqrt(math.pi)
		local lerp = bodyB.mass / (bodyB.mass + bodyA.mass)
		bodyA.pos = bodyA.pos*(1-lerp) + bodyB.pos*lerp
		local totalMomentum = bodyA.mass*bodyA.vel + bodyB.mass*bodyB.vel
		bodyA.radius = newRadius
		bodyA.mass = bodyA.mass + bodyB.mass
		bodyA.col.r = bodyA.col.r * (1 - lerp) + bodyB.col.r * lerp
		bodyA.col.g = bodyA.col.g * (1 - lerp) + bodyB.col.g * lerp
		bodyA.col.b = bodyA.col.b * (1 - lerp) + bodyB.col.b * lerp
		bodyA.vel = totalMomentum / bodyA.mass
		bodies:remove(bodyB)
	end
	for body in bodies:elements() do
		body.prevPos = body.pos
		body.pos = body.pos + body.vel * dt
	end
	
	local totalMomentum = vec2()
	local totalEnergy = 0
	for body in bodies:elements() do
		totalMomentum = totalMomentum + body.vel * body.mass
		totalEnergy = totalEnergy + vec2.dot(body.vel, body.vel) * body.mass / 2
	end
	print(totalMomentum, totalEnergy)
end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(fade, fade, fade)
	love.graphics.setBlendMode("subtract")
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
	love.graphics.setColor(1, 1, 1)
	love.graphics.setBlendMode("alpha")
	if focusBody then
		love.graphics.translate(-focusBody.pos.x, -focusBody.pos.y)
		love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
	end
	if justMadeBody then -- hack to solve newly spawned bodies' gaps-from-being-too-fast-filling line having a straight edge at the start
		local body = justMadeBody
		love.graphics.setColor(body.col.r, body.col.g, body.col.b)
		love.graphics.circle("fill", body.prevPos.x, body.prevPos.y, body.radius)
		justMadeBody = nil
	end
	for body in bodies:elements() do
		love.graphics.setLineWidth(body.radius * 2)
		love.graphics.setColor(body.col.r, body.col.g, body.col.b)
		love.graphics.circle("fill", body.pos.x, body.pos.y, body.radius)
		if fade ~= 1 then
			love.graphics.line(body.prevPos.x, body.prevPos.y, body.pos.x, body.pos.y)
		end
	end
	love.graphics.setCanvas()
	love.graphics.push()
	love.graphics.reset()
	love.graphics.draw(canvas)
	love.graphics.pop()
	if newObjPos then
		love.graphics.setLineWidth(1)
		love.graphics.setColor(1, 1, 1)
		local pos = vec2(love.mouse.getPosition())
		if focusBody then
			pos = -vec2(love.graphics.getDimensions())/2 + pos + focusBody.pos
		end
		love.graphics.line(newObjPos.x, newObjPos.y, pos:components())
	end
	love.graphics.origin()
end

function love.keypressed(key)
	if key == "f" then
		local largestBody = nil
		local largestBodyRadius = -math.huge
		for body in bodies:elements() do
			if body.radius > largestBodyRadius then
				largestBody = body
				largestBodyRadius = body.radius
			end
		end
		if largestBody then
			changeFocus(largestBody)
		end
	elseif key == "u" then
		if focusBody then
			changeFocus(nil)
		end
	end
end
