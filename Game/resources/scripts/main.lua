-- Roads widths are about 3m
-- This whole script is a hack, don't you dare to look

local game = getGame()

local resourceManager = game:getResourceManager()
local inputManager = game:getInputManager()
local entityManager = game:getEntityManager()

local musicButtonPressedLastFrame = false
local actionButtonPressedLastFrame = false -- e

local shadedShader = nil
local texturedShader = nil

function gameInit()
	Utils.logprint("Hello, init from lua!")
	
	game:setName("North Korean Escape")
	game:setSize(1024, 768)
	game:setMaxFramesPerSecond(60)
	game:reCenterMainWindow()
	
	local camera = entityManager:getGameCamera()
	local cameraPhysicsBody = camera:getPhysicsBody()
	camera:setFarClippingDistance(10000)
	camera:setFieldOfView(90)
	
	cameraPhysicsBody:setPosition(Vec3(0, 1.65, 0)) -- Starting position
	cameraPhysicsBody:calculateShapesFromRadius(1)
	
	loadResources()
	
	inputManager:registerKeys({KeyCode.UP, KeyCode.DOWN, KeyCode.LEFT, KeyCode.RIGHT,
		KeyCode.w, KeyCode.a, KeyCode.s, KeyCode.d, KeyCode.SPACE, KeyCode.LSHIFT, KeyCode.LCTRL, KeyCode.m, KeyCode.e})
end

function loadResources()
	resourceManager:addShader("basic.v.glsl", "basic.f.glsl")
	resourceManager:addShader("textured.v.glsl", "textured.f.glsl")
	resourceManager:addShader("shaded.v.glsl", "shaded.f.glsl")
	
	resourceManager:addTexture("Pyongyang/Pyongyang_Ground1.dds", TextureType.DDS)
	resourceManager:addTexture("Pyongyang/Pyongyang_Ground2.dds", TextureType.DDS)
	resourceManager:addTexture("Pyongyang/Pyongyang_Ground3.dds", TextureType.DDS)
	resourceManager:addTexture("Pyongyang/Pyongyang_Ground4.dds", TextureType.DDS)
	local pyongyangGround = resourceManager:addObjectGeometryGroup("Pyongyang/Pyongyang_Ground.obj")
	
	resourceManager:addTexture("Pyongyang/Bus/Bus.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup("Pyongyang/Bus/Bus.obj")
	
	resourceManager:addTexture("Pyongyang/Statue/Statue.dds", TextureType.DDS)
	resourceManager:addTexture("Pyongyang/Statue/StatueWall1.dds", TextureType.DDS)
	resourceManager:addTexture("Pyongyang/Statue/StatueWall2.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup("Pyongyang/Statue/Statue.obj")
	resourceManager:addObjectGeometryGroup("Pyongyang/Statue/StatueWall1.obj")
	resourceManager:addObjectGeometryGroup("Pyongyang/Statue/StatueWall2.obj")
	
	resourceManager:addTexture("Pyongyang/Apartment/Apartment.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup("Pyongyang/Apartment/Apartment.obj")
	
	resourceManager:addTexture("Pyongyang/Skybox.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup("Pyongyang/Skybox.obj")
	
	shadedShader = resourceManager:findShader("shaded")
	texturedShader = resourceManager:findShader("textured")
	
	for i,v in ipairs(pyongyangGround:getObjectGeometries()) do
		object = ShadedObject(v, shadedShader, resourceManager:findTexture("Pyongyang_Ground" .. i), false, PhysicsBodyType.Ignored)
		entityManager:addObject(object)
	end
	
	addObjectGeometries("Skybox", false, "Skybox", PhysicsBodyType.Ignored)
	addObjectGeometries("Bus", true, "Bus", PhysicsBodyType.Static)
	addObjectGeometries("Statue", true, "Statue", PhysicsBodyType.Static)
	addObjectGeometries("StatueWall1", true, "StatueWall1", PhysicsBodyType.Static)
	addObjectGeometries("StatueWall2", true, "StatueWall2", PhysicsBodyType.Static)
	addObjectGeometries("Apartment", false, "Apartment", PhysicsBodyType.Static)
end

function addObjectGeometries(objectGeometryGroupName, isShaded, textureName, physicsBodyType)
	local objectGeometryGroup = resourceManager:findObjectGeometryGroup(objectGeometryGroupName)
	
	for i,v in ipairs(objectGeometryGroup:getObjectGeometries()) do
		local object = nil
		
		if(isShaded) then
			object = ShadedObject(v, shadedShader, resourceManager:findTexture(textureName), false, physicsBodyType)
		else
			object = TexturedObject(v, texturedShader, resourceManager:findTexture(textureName), false, physicsBodyType)
		end
		
		entityManager:addObject(object)
	end
end

function gameStep()
	local game = getGame()
	
	local camera = entityManager:getGameCamera()
	
	local shader = resourceManager:findShader("basic");
	local objects = entityManager:getObjects()
	
	doControls();
	
	camera:getPhysicsBody():renderDebugShapeWithCoord(resourceManager:findShader("basic"), camera, 0.0)
	
	for i,v in ipairs(objects) do
		local physicsBody = v:getPhysicsBody()
		
		if(physicsBody:getType() ~= PhysicsBodyType.Ignored) then
			physicsBody:renderDebugShape(shader, camera)
		end
	end
end

-- http://www.scs.ryerson.ca/~danziger/mth141/Handouts/Slides/projections.pdf
function projectVec2OnVec2(vector, projectionVector)
	local projected = Vec2.scalarMul(projectionVector, (  Vec2.dot(vector, projectionVector) / Vec2.length(projectionVector)  ))
	return projected
end

function doControls()
	local speed = 5.5
	local angleIncrementation = 0.02
	
	local camera = entityManager:getGameCamera()
	local cameraPhysicsBody = camera:getPhysicsBody()

	-- Movement
	if(inputManager:isKeyPressed(KeyCode.LSHIFT)) then
		speed = speed * 10
	end
	
	if(inputManager:isKeyPressed(KeyCode.UP)) then
		local cameraDirection = camera:getDirection()
		
		 -- Normalize to guarantee that it is the same everywhere
		local velocity = Vec3.scalarMul(Vec3.normalize(Vec3(cameraDirection.x, 0, cameraDirection.z)), speed)
		cameraPhysicsBody:setVelocity(velocity)
	elseif(inputManager:isKeyPressed(KeyCode.DOWN)) then
		local cameraDirection = camera:getDirection()
	
		local velocity = Vec3.scalarMul(Vec3.normalize(Vec3(-cameraDirection.x, 0, -cameraDirection.z)), speed)
		cameraPhysicsBody:setVelocity(velocity)
	end
	
	if(inputManager:isKeyPressed(KeyCode.LEFT) or inputManager:isKeyPressed(KeyCode.RIGHT)) then
		local sidewaysVelocityAngle = 1.5708
		
		if(inputManager:isKeyPressed(KeyCode.LEFT)) then
			sidewaysVelocityAngle = -sidewaysVelocityAngle
		end
		
		local normalizedCameraDirection = Vec4.normalize(camera:getDirection())
		local cameraVelocity = cameraPhysicsBody:getVelocity()
		
		local otherX = (normalizedCameraDirection.x * math.cos(sidewaysVelocityAngle) - normalizedCameraDirection.z * math.sin(sidewaysVelocityAngle)) * speed
		local otherZ = (normalizedCameraDirection.x * math.sin(sidewaysVelocityAngle) + normalizedCameraDirection.z * math.cos(sidewaysVelocityAngle)) * speed
		
		-- Get the velocity projection on the camera direction (this lets us keep vertical speed)
		local cameraVelocity2D = Vec2(cameraVelocity.x, cameraVelocity.z)
		local cameraDirection2D = Vec2(normalizedCameraDirection.x, normalizedCameraDirection.z)
		local projected = projectVec2OnVec2(cameraVelocity2D, cameraDirection2D)
		
		local currentVelocity = cameraPhysicsBody:getVelocity()
		
		-- Make sure we don't indefinitely add velocity, so normalize to our speed (only keep direction)
		local newVelocity = Vec3(otherX + projected.x,
								currentVelocity.y,
								otherZ + projected.y)
		
		cameraPhysicsBody:setVelocity(newVelocity)
	end
	
	-- View controls
	if(inputManager:isKeyPressed(KeyCode.w)) then
		local cameraDirection = camera:getDirection() -- Here we make sure we have the latest direction
		
		-- Base of the triangle
		local base = math.sqrt((cameraDirection.x * cameraDirection.x) + (cameraDirection.z * cameraDirection.z))
	
		-- http://stackoverflow.com/questions/22818531/how-to-rotate-2d-vector
		local newBase = base * math.cos(angleIncrementation) - cameraDirection.y * math.sin(angleIncrementation)
		local newY = base * math.sin(angleIncrementation) + cameraDirection.y * math.cos(angleIncrementation)
		
		local ratio = newBase / base
		
		camera:setDirection(Vec4(cameraDirection.x * ratio, newY, cameraDirection.z * ratio, 0)) -- 0 for vector
	elseif(inputManager:isKeyPressed(KeyCode.s)) then
		local cameraDirection = camera:getDirection()
		
		-- Base of the triangle
		local base = math.sqrt((cameraDirection.x * cameraDirection.x) + (cameraDirection.z * cameraDirection.z))
	
		local newBase = base * math.cos(-angleIncrementation) - cameraDirection.y * math.sin(-angleIncrementation)
		local newY = base * math.sin(-angleIncrementation) + cameraDirection.y * math.cos(-angleIncrementation)
		
		local ratio = newBase / base
		
		camera:setDirection(Vec4(cameraDirection.x * ratio, newY, cameraDirection.z * ratio, 0)) -- 0 for vector
	end
	
	if(inputManager:isKeyPressed(KeyCode.a)) then
		local cameraDirection = camera:getDirection()
		
		local newX = cameraDirection.x * math.cos(-angleIncrementation) - cameraDirection.z * math.sin(-angleIncrementation)
		local newZ = cameraDirection.x * math.sin(-angleIncrementation) + cameraDirection.z * math.cos(-angleIncrementation)
		
		camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
	elseif(inputManager:isKeyPressed(KeyCode.d)) then
		local cameraDirection = Vec3.fromVec4(camera:getDirection())
		
		local newX = cameraDirection.x * math.cos(angleIncrementation) - cameraDirection.z * math.sin(angleIncrementation)
		local newZ = cameraDirection.x * math.sin(angleIncrementation) + cameraDirection.z * math.cos(angleIncrementation)
		
		camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
	end
	
	-- Up/down controls
	if(inputManager:isKeyPressed(KeyCode.SPACE)) then
		cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, speed/30, 0)) )
	elseif(inputManager:isKeyPressed(KeyCode.LCTRL)) then
		cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, -speed/30, 0)) )
	end
	
	-- Music controls
	if(inputManager:isKeyPressed(KeyCode.m)) then
		if(musicButtonPressedLastFrame == false) then
			musicButtonPressedLastFrame = true
			
			resourceManager:findSound("soundEffect"):play()
			
			local music = resourceManager:findSound("music")
			if(music:isPaused()) then
				music:resume()
			else
				music:pause()
			end
		end
	else
		musicButtonPressedLastFrame = false
	end
	
	-- Action
	if(inputManager:isKeyPressed(KeyCode.e)) then
		if(actionButtonPressedLastFrame == false) then
			actionButtonPressedLastFrame = true
			doAction()
		end
	else
		actionButtonPressedLastFrame = false
	end
end

function distanceBetween2DPoints(p1, p2)
	return math.sqrt(p1, p2)
end

function distanceSquaredBetween2DPoints(p1, p2)
	local deltaX = p2.x - p1.x
	local deltaY = p2.y - p1.y
	
	return (deltaX * deltaX) + (deltaY * deltaY)
end

-- When you press the action button, this is called
function doAction()
	local camera = entityManager:getGameCamera()
	local pos = Vec2.fromVec3(camera:getPhysicsBody():getPosition())
	
	local maxDistanceSquared = 1 * 1 -- In meters, as always
	
	if(distanceSquaredBetween2DPoints(pos, Vec2(-60.76, 1.2)) <= maxDistanceSquared) then
		entityManager:removeObjectByIndex(0)
	end
	
	--[[Utils.logprint("")
	Utils.logprint("Our pos x: " .. pos.x)
	Utils.logprint("Our pos y: " .. pos.y)]]--
end