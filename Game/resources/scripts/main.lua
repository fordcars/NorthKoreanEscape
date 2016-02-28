-- Roads widths are about 3m
-- This script is ugly, don't look

-- We create forest tiles dynamically to have a lower work load (there are a lot of objects per tile, which is difficult for Box2D and the GPU for textures)

local game = getGame()

local resourceManager = game:getResourceManager()
local inputManager = game:getInputManager()
local entityManager = game:getEntityManager()

local gameCamera = entityManager:getGameCamera()

local playerHeight = 1.65 -- In meters

local musicButtonPressedLastFrame = false
local actionButtonPressedLastFrame = false -- e

local basicShader = nil
local texturedShader = nil
local shadedShader = nil

local roomTableObject = nil

local skybox = nil

local timeAtTimerStart = 0
local timerLength = 0 -- In seconds
local transitioning = false

local level = 1 -- Current level (1 for pyongyang)

local forestTileLength = 24.3
local forestFirstTilePosition = Vec3(22.89, -1.18, 98.94)
local forestNextTilePosition = 0 -- Z coord when we last deleted/created tiles, changed when generating initial forest tiles

local forestNumberOfTileStyles = 4
local forestNumberOfTilesToCreate = 5 -- Create tiles when we delete/create them
local forestMinTilesForSeamless = 3 -- Minimum amount of tiles that hide us creating new tiles!

local forestTileObjects = {} -- A 2D list, first-D for tiles, second-D for objects in that tile

local forestFirstTileDeletion = true

local forestRunStarted = false
local forest5050Step = false -- 50/50 frame flag, beautiful name
local forestSpeed = 5 -- Initial speed
local forestAcceleration = 0.01

local forestStepsSlowToLose = 30
local forestStepsPlayerSlow = 0
local forestLastPosition = Vec3(0, 0, 0)

local forestIntroCollision = nil -- Remove after intro ends!

function gameInit()
	Utils.logprint("Hello, init from lua!")
	
	game:setName("North Korean Escape")
	game:setSize(IVec2(1024, 768))
	game:setMaxFramesPerSecond(60)
	game:reCenterMainWindow()
	
	local camera = entityManager:getGameCamera()
	local cameraPhysicsBody = camera:getPhysicsBody()
	camera:setFarClippingDistance(10000)
	camera:setFieldOfView(90)
	
	cameraPhysicsBody:calculateShapesFromRadius(0.5)
	cameraPhysicsBody:setWorldFriction(3)
	
	basicShader = resourceManager:addShader("basic.v.glsl", "basic.f.glsl")
	texturedShader = resourceManager:addShader("textured.v.glsl", "textured.f.glsl")
	shadedShader = resourceManager:addShader("shaded.v.glsl", "shaded.f.glsl")
	
	loadPyongyang()
	
	inputManager:registerKeys({KeyCode.UP, KeyCode.DOWN, KeyCode.LEFT, KeyCode.RIGHT,
		KeyCode.w, KeyCode.a, KeyCode.s, KeyCode.d, KeyCode.SPACE, KeyCode.LSHIFT, KeyCode.LCTRL, KeyCode.e})
end

-- Loads and adds to the world
function loadPyongyang()
	local prefix = "Pyongyang/"
	local cameraPhysicsBody = gameCamera:getPhysicsBody()
	
	cameraPhysicsBody:setPosition(Vec3(-594.56, -274.9 + playerHeight, -10.26)) -- Starting position
	
	resourceManager:addSound(prefix .. "Pyongyang_Music.ogg", SoundType.Music)
	resourceManager:findSound("Pyongyang_Music"):play()
	
	resourceManager:addNamedSound("BusDriving", "Other/BMW_DRIVEBY.ogg", SoundType.Chunk)
	resourceManager:addNamedSound("BusCrash", "Other/car_skid_and_crash.ogg", SoundType.Chunk)
	
	resourceManager:addTexture(prefix .. "Pyongyang_Ground1.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Ground2.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Ground3.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Ground4.dds", TextureType.DDS)
	local pyongyangGround = resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Ground.obj")
	
	resourceManager:addTexture(prefix .. "Bus/Bus.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Bus/Bus.obj")
	
	resourceManager:addTexture(prefix .. "Statue/Statue.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Statue/StatueWall1.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Statue/StatueWall2.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Statue/Statue.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Statue/StatueWall1.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Statue/StatueWall2.obj")
	
	resourceManager:addTexture(prefix .. "Apartment/Apartment.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Apartment.obj")
	resourceManager:addTexture(prefix .. "Apartment/Room/Room.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Room/Room.obj")
	
	-- Here, I've made collision objects separate, for fun (render as basic object)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Room/RoomCollisions.obj")
	
	resourceManager:addTexture(prefix .. "Apartment/Room/Objects/KimIlSungPicture.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Room/Objects/KimIlSungPicture.obj")
	resourceManager:addTexture(prefix .. "Apartment/Room/Objects/KimJongIlPicture.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Room/Objects/KimJongIlPicture.obj")
	
	resourceManager:addTexture(prefix .. "Apartment/Room/Objects/TableFull.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Apartment/Room/Objects/TableEmpty.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Apartment/Room/Objects/Table.obj")
	
	resourceManager:addTexture(prefix .. "Skybox.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Skybox.obj")
	
	resourceManager:addTexture(prefix .. "Pyongyang_Building1.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Building2.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Building3.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Building4.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Building5.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Pyongyang_Building6.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings1.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings2.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings3.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings4.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings5.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings6.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Buildings7.obj") -- Uses same texture as apartment
	
	resourceManager:addTexture(prefix .. "Pyongyang_Walls.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Walls.obj")
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Collisions.obj")
	
	resourceManager:addTexture(prefix .. "Pyongyang_Koryo.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Koryo.obj")
	resourceManager:addTexture(prefix .. "Pyongyang_Ryugyong.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_Ryugyong.obj")
	resourceManager:addTexture(prefix .. "Pyongyang_JucheTower.dds", TextureType.DDS)
	resourceManager:addObjectGeometryGroup(prefix .. "Pyongyang_JucheTower.obj")
	
	for i,v in ipairs(pyongyangGround:getObjectGeometries()) do
		local object = ShadedObject(v, shadedShader, resourceManager:findTexture("Pyongyang_Ground" .. i), false, PhysicsBodyType.Ignored)
		entityManager:addObject(object)
	end
	
	addObjectGeometries("Bus", true, "Bus", PhysicsBodyType.Static)
	addObjectGeometries("Statue", true, "Statue", PhysicsBodyType.Static)
	addObjectGeometries("StatueWall1", true, "StatueWall1", PhysicsBodyType.Static)
	addObjectGeometries("StatueWall2", true, "StatueWall2", PhysicsBodyType.Static)
	addObjectGeometries("Apartment", true, "Apartment", PhysicsBodyType.Static)
	
	addObjectGeometries("Room", true, "Room", PhysicsBodyType.Ignored)
	addObjectGeometries("RoomCollisions", false, false, PhysicsBodyType.Static)
	
	addObjectGeometries("KimIlSungPicture", true, "KimIlSungPicture", PhysicsBodyType.Ignored)
	addObjectGeometries("KimJongIlPicture", true, "KimJongIlPicture", PhysicsBodyType.Ignored)
	roomTableObject = addObjectGeometries("Table", true, "TableFull", PhysicsBodyType.Static)[1]
	
	skybox = addObjectGeometries("Skybox", false, "Skybox", PhysicsBodyType.Ignored)[1]
	
	addObjectGeometries("Pyongyang_Buildings1", true, "Pyongyang_Building1", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings2", true, "Pyongyang_Building2", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings3", true, "Pyongyang_Building3", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings4", true, "Pyongyang_Building4", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings5", true, "Pyongyang_Building5", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings6", true, "Pyongyang_Building6", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Buildings7", true, "Apartment", PhysicsBodyType.Static)
	
	addObjectGeometries("Pyongyang_Walls", true, "Pyongyang_Walls", PhysicsBodyType.Static)
	addObjectGeometries("Pyongyang_Collisions", false, false, PhysicsBodyType.Static)
	
	addObjectGeometries("Pyongyang_Koryo", true, "Pyongyang_Koryo", PhysicsBodyType.Ignored)
	addObjectGeometries("Pyongyang_Ryugyong", true, "Pyongyang_Ryugyong", PhysicsBodyType.Ignored)
	addObjectGeometries("Pyongyang_JucheTower", true, "Pyongyang_JucheTower", PhysicsBodyType.Ignored)
	
	-- Black box, for transition
	resourceManager:addObjectGeometryGroup("Other/BlackBox.obj")
	resourceManager:addTexture("Other/BlackBox.dds", TextureType.DDS)
end

function loadForest()
	local prefix = "Forest/"
	local plantsPrefix = prefix .. "Plants/"
	
	level = 2
	
	resourceManager:addSound(prefix .. "Forest_Music.ogg", SoundType.Music)
	resourceManager:findSound("Forest_Music"):play()
	
	resourceManager:addObjectGeometryGroup(prefix .. "Forest_Ground.obj")
	resourceManager:addTexture(prefix .. "Forest_Ground.dds", TextureType.DDS)
	addObjectGeometries("Forest_Ground", true, "Forest_Ground", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Skybox.obj")
	resourceManager:addTexture(prefix .. "Skybox.dds", TextureType.DDS)
	skybox = addObjectGeometries("Skybox", false, "Skybox", PhysicsBodyType.Ignored)[1]
	
	-- Plants
	resourceManager:addObjectGeometryGroup(plantsPrefix .. "Forest_Leaves1.obj")
	resourceManager:addTexture(plantsPrefix .. "Forest_Leaves1.dds", TextureType.DDS)
	addObjectGeometries("Forest_Leaves1", true, "Forest_Leaves1", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(plantsPrefix .. "Forest_Leaves2.obj")
	resourceManager:addTexture(plantsPrefix .. "Forest_Leaves2.dds", TextureType.DDS)
	addObjectGeometries("Forest_Leaves2", true, "Forest_Leaves2", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(plantsPrefix .. "Forest_Leaves3.obj")
	resourceManager:addTexture(plantsPrefix .. "Forest_Leaves3.dds", TextureType.DDS)
	addObjectGeometries("Forest_Leaves3", true, "Forest_Leaves3", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(plantsPrefix .. "Forest_Leaves4.obj")
	resourceManager:addTexture(plantsPrefix .. "Forest_Leaves4.dds", TextureType.DDS)
	addObjectGeometries("Forest_Leaves4", true, "Forest_Leaves4", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(plantsPrefix .. "Forest_Trunks.obj")
	resourceManager:addTexture(plantsPrefix .. "Forest_Trunk.dds", TextureType.DDS)
	addObjectGeometries("Forest_Trunks", true, "Forest_Trunk", PhysicsBodyType.Static, true)
	
	-- Other stuff
	resourceManager:addObjectGeometryGroup(prefix .. "Forest_Bus.obj")
	resourceManager:addTexture(prefix .. "Forest_Bus.dds", TextureType.DDS)
	addObjectGeometries("Forest_Bus", true, "Forest_Bus", PhysicsBodyType.Static)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Forest_Collisions.obj")
	addObjectGeometries("Forest_Collisions", true, false, PhysicsBodyType.Static)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Forest_IntroCollision.obj")
	forestIntroCollision = addObjectGeometries("Forest_IntroCollision", true, false, PhysicsBodyType.Static)[1]
	
	generateAndLoadInitialForestTiles(prefix)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Forest_Walls.obj")
	addObjectGeometries("Forest_Walls", true, "Forest_DefaultWall", PhysicsBodyType.Static)
	
	resourceManager:addObjectGeometryGroup("Other/Soldier/Soldier.obj")
	resourceManager:addTexture("Other/Soldier/Soldier.dds", TextureType.DDS)
	
	local firstPos = Vec3(45, -0.9, -57.372)
	local separation = 3
	for i=0,13,1 do
		local position = Vec3(firstPos.x - separation*i, firstPos.y, firstPos.z)
		local object = addObjectGeometries("Soldier", true, "Soldier", PhysicsBodyType.Ignored)[1]
		object:getPhysicsBody():setPosition(position)
		
		local velocity = getDirectionVector(position, Vec3(23.301, position.y, 109.83))
		object:getPhysicsBody():setVelocity(Vec3.scalarMul(velocity, math.random(1, 6)))
	end
	
	timeAtTimerStart = os.clock()
	timerLength = 14.8
end

function loadCamp()
	local prefix = "Camp/"
	
	level = 3
	
	resourceManager:addSound(prefix .. "Camp_Music.ogg", SoundType.Music)
	resourceManager:findSound("Camp_Music"):play()
	
	resourceManager:addObjectGeometryGroup(prefix .. "Skybox.obj")
	resourceManager:addTexture(prefix .. "Skybox.dds", TextureType.DDS)
	skybox = addObjectGeometries("Skybox", false, "Skybox", PhysicsBodyType.Ignored)[1]
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Bars.obj")
	resourceManager:addTexture(prefix .. "Camp_Bars.dds", TextureType.DDS)
	addObjectGeometries("Camp_Bars", true, "Camp_Bars", PhysicsBodyType.Static)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Cell.obj")
	resourceManager:addTexture(prefix .. "Camp_Cell.dds", TextureType.DDS)
	addObjectGeometries("Camp_Cell", true, "Camp_Cell", PhysicsBodyType.Static)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Ceiling.obj")
	addObjectGeometries("Camp_Ceiling", true, "Camp_Cell", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Ground.obj")
	resourceManager:addTexture(prefix .. "Camp_Ground.dds", TextureType.DDS)
	addObjectGeometries("Camp_Ground", true, "Camp_Ground", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Indoors.obj")
	resourceManager:addTexture(prefix .. "Camp_Indoors.dds", TextureType.DDS)
	addObjectGeometries("Camp_Indoors", true, "Camp_Indoors", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_KimIlSungPicture.obj")
	resourceManager:addTexture("Pyongyang/Apartment/Room/Objects/KimIlSungPicture.dds", TextureType.DDS)
	addObjectGeometries("Camp_KimIlSungPicture", true, "KimIlSungPicture", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_KimJongIlPicture.obj")
	resourceManager:addTexture("Pyongyang/Apartment/Room/Objects/KimJongIlPicture.dds", TextureType.DDS)
	addObjectGeometries("Camp_KimJongIlPicture", true, "KimJongIlPicture", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Soldiers.obj")
	resourceManager:addTexture("Other/Soldier/Soldier.dds", TextureType.DDS)
	addObjectGeometries("Camp_Soldiers", true, "Soldier", PhysicsBodyType.Ignored)
	
	-- Images
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Image1.obj")
	resourceManager:addTexture(prefix .. "Camp_Image1.dds", TextureType.DDS)
	addObjectGeometries("Camp_Image1", true, "Camp_Image1", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Image2.obj")
	resourceManager:addTexture(prefix .. "Camp_Image2.dds", TextureType.DDS)
	addObjectGeometries("Camp_Image2", true, "Camp_Image2", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Image3.obj") -- The middle image, don't ask me why
	resourceManager:addTexture(prefix .. "Camp_Image3.dds", TextureType.DDS)
	addObjectGeometries("Camp_Image3", true, "Camp_Image3", PhysicsBodyType.Ignored)
	
	-- Trees
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Leaves1.obj")
	resourceManager:addTexture("Forest/Plants/Forest_Leaves1.dds", TextureType.DDS)
	addObjectGeometries("Camp_Leaves1", true, "Forest_Leaves1", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Leaves2.obj")
	resourceManager:addTexture("Forest/Plants/Forest_Leaves2.dds", TextureType.DDS)
	addObjectGeometries("Camp_Leaves2", true, "Forest_Leaves2", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Leaves3.obj")
	resourceManager:addTexture("Forest/Plants/Forest_Leaves3.dds", TextureType.DDS)
	addObjectGeometries("Camp_Leaves3", true, "Forest_Leaves3", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Leaves4.obj")
	resourceManager:addTexture("Forest/Plants/Forest_Leaves4.dds", TextureType.DDS)
	addObjectGeometries("Camp_Leaves4", true, "Forest_Leaves4", PhysicsBodyType.Ignored)
	
	resourceManager:addObjectGeometryGroup(prefix .. "Camp_Trunks.obj")
	resourceManager:addTexture("Forest/Plants/Forest_Trunk.dds", TextureType.DDS)
	addObjectGeometries("Camp_Trunks", true, "Forest_Trunk", PhysicsBodyType.Ignored)
	
	local cameraPhysicsBody = gameCamera:getPhysicsBody()
	cameraPhysicsBody:setPosition(Vec3(19.866, -1.01 + playerHeight, 18.72))
	cameraPhysicsBody:setVelocity(Vec3(0,0,0))
	gameCamera:setDirection(Vec4(0, 0, -1, 0))
end

-- Normalized
function getDirectionVector(initialPoint, destinationPoint)
	return Vec3.normalize(Vec3.sub(destinationPoint, initialPoint)) -- I am cool at math
end

function generateAndLoadInitialForestTiles(forestPrefix)
	local prefix = forestPrefix.. "Run/"
	
	resourceManager:addTexture(prefix .. "Forest_DefaultTile.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Forest_DefaultWall.dds", TextureType.DDS)
	resourceManager:addTexture(prefix .. "Forest_Rock1.dds", TextureType.DDS)
	
	for i=1,forestNumberOfTileStyles,1 do
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Leaves1.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Leaves2.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Leaves3.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Leaves4.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Rocks.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Tile.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Trunks.obj")
		resourceManager:addObjectGeometryGroup(prefix .. "Tile" .. i .. "/Tile" .. i .. "_Walls.obj")
	end
	
	-- Setup random
	math.randomseed(os.clock())
	math.random();math.random();math.random(); -- Warm up the numbers, better randomness!
	
	createRandomForestTiles(forestFirstTilePosition, forestNumberOfTilesToCreate)
end

-- Returns the next position
-- Position is the position of the side of the tile, not the center
-- Sets forestNextTilePosition
function createRandomForestTiles(firstTilePosition, count)
	local nextPosition = nil
	
	for i=1,count,1 do
		local randomTile = math.random(1, forestNumberOfTileStyles) -- Inclusive!
		local position = Vec3(firstTilePosition.x, firstTilePosition.y, firstTilePosition.z + forestTileLength*i)
		
		nextPosition = position
		
		local newTileTable = {} -- Tables, functions and userdata are passed by reference
		table.insert(forestTileObjects, newTileTable)
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Leaves1", true, "Forest_Leaves1", PhysicsBodyType.Ignored, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Leaves2", true, "Forest_Leaves2", PhysicsBodyType.Ignored, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Leaves3", true, "Forest_Leaves3", PhysicsBodyType.Ignored, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Leaves4", true, "Forest_Leaves4", PhysicsBodyType.Ignored, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Rocks", true, "Forest_Rock1", PhysicsBodyType.Static, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Tile", true, "Forest_DefaultTile", PhysicsBodyType.Ignored, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Trunks", true, "Forest_Trunk", PhysicsBodyType.Static, false, position))
		
		addElementsToArray(newTileTable, addObjectGeometries("Tile" .. randomTile .. "_Walls", true, "Forest_DefaultWall", PhysicsBodyType.Static, false, position))
	end
	
	forestNextTilePosition = nextPosition
	return nextPosition
end

-- Uses table.insert()
function addElementsToArray(array, elements)
	for i,v in ipairs(elements) do
		table.insert(array, v)
	end
end

-- Frees ram and vram
function resetWorld()
	skybox = nil
	roomTableObject = nil
	
	for i,v in ipairs(entityManager:getObjects()) do
		entityManager:removeObject(v)
	end

	resourceManager:clearSounds()
	resourceManager:clearObjectGeometryGroups()
	resourceManager:clearTextures()
end

-- Returns the added objects (references)
-- If textureName is false, it will create a basic object
-- isCircular is optional
-- position is optional
function addObjectGeometries(objectGeometryGroupName, isShaded, textureName, physicsBodyType, isCircular, position)
	local objectGeometryGroup = resourceManager:findObjectGeometryGroup(objectGeometryGroupName)
	local newObjects = {}
	
	for i,v in ipairs(objectGeometryGroup:getObjectGeometries()) do
		local object = nil
		local objectIsCircular = false
		
		if(isCircular == true) then
			objectIsCircular = true
		end
		
		if(textureName ~= false) then
			if(isShaded) then
				object = ShadedObject(v, shadedShader, resourceManager:findTexture(textureName), objectIsCircular, physicsBodyType)
			else
				object = TexturedObject(v, texturedShader, resourceManager:findTexture(textureName), objectIsCircular, physicsBodyType)
			end
		else
			object = Object(v, basicShader, objectIsCircular, physicsBodyType)
		end
		
		if(position ~= nil) then
			object:getPhysicsBody():setPosition(position)
		end
		
		entityManager:addObject(object)
		table.insert(newObjects, object)
	end
	
	return newObjects
end

function gameStep()
	local game = getGame()
	
	local camera = entityManager:getGameCamera()
	local objects = entityManager:getObjects()
	
	doControls();
	
	--camera:getPhysicsBody():renderDebugShapeWithCoord(resourceManager:findShader("basic"), camera, 0.0)
	skybox:getPhysicsBody():setPosition(camera:getPhysicsBody():getPosition())

	--[[for i,v in ipairs(objects) do
		local physicsBody = v:getPhysicsBody()

		if(physicsBody:getType() ~= PhysicsBodyType.Ignored) then
			physicsBody:renderDebugShapeWithCoord(basicShader, camera, 0)
		end
	end]]--
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
		speed = speed * 3
	end
	
	if(inputManager:isKeyPressed(KeyCode.LCTRL)) then
		speed = speed * 0.3
	end
	
	if(forestRunStarted == false) then
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
	end
	
	if(inputManager:isKeyPressed(KeyCode.LEFT) or inputManager:isKeyPressed(KeyCode.RIGHT)) then
		local sidewaysVelocityAngle = 1.5708
		local sidewaysSpeed = speed
		
		if(forestRunStarted == true) then
			sidewaysSpeed = forestSpeed
		end
		
		if(inputManager:isKeyPressed(KeyCode.LEFT)) then
			sidewaysVelocityAngle = -sidewaysVelocityAngle
		end
		
		local normalizedCameraDirection = Vec4.normalize(camera:getDirection())
		local cameraVelocity = cameraPhysicsBody:getVelocity()
		
		local otherX = (normalizedCameraDirection.x * math.cos(sidewaysVelocityAngle) - normalizedCameraDirection.z * math.sin(sidewaysVelocityAngle)) * sidewaysSpeed
		local otherZ = (normalizedCameraDirection.x * math.sin(sidewaysVelocityAngle) + normalizedCameraDirection.z * math.cos(sidewaysVelocityAngle)) * sidewaysSpeed
		
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
	
	-- These are weird when we are pointing completely downwards and are far away?
	if(inputManager:isKeyPressed(KeyCode.a)) then
		local cameraDirection = camera:getDirection()
		
		local newX = cameraDirection.x * math.cos(-angleIncrementation) - cameraDirection.z * math.sin(-angleIncrementation)
		local newZ = cameraDirection.x * math.sin(-angleIncrementation) + cameraDirection.z * math.cos(-angleIncrementation)
		
		if(forestRunStarted == true) then
			-- Make the x/z on the right plane (-z in our case)
			local angleInRadians = (math.pi*-45)/180 -- Cause Lua cos/sin
			local weirdX = newX * math.cos(angleInRadians) - newZ * math.sin(angleInRadians)
			local weirdZ = newX * math.sin(angleInRadians) + newZ * math.cos(angleInRadians)
			
			if(weirdZ~=0 and (weirdX/weirdZ) >0.01) then -- Ignore if X too close to Y, too small of an angle
				camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
			end
		else
			camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
		end
	elseif(inputManager:isKeyPressed(KeyCode.d)) then
		local cameraDirection = Vec3.fromVec4(camera:getDirection())
		
		local newX = cameraDirection.x * math.cos(angleIncrementation) - cameraDirection.z * math.sin(angleIncrementation)
		local newZ = cameraDirection.x * math.sin(angleIncrementation) + cameraDirection.z * math.cos(angleIncrementation)
		
		if(forestRunStarted == true) then
			-- Make the x/z on the right plane (-z in our case)
			local angleInRadians = (math.pi*-45)/180 -- Cause Lua cos/sin
			local weirdX = newX * math.cos(angleInRadians) - newZ * math.sin(angleInRadians)
			local weirdZ = newX * math.sin(angleInRadians) + newZ * math.cos(angleInRadians)
			
			if(weirdZ~=0 and (weirdX/weirdZ) >0.01) then -- Ignore if X too close to Y, too small of an angle
				camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
			end
		else
			camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
		end
	end
	
	--[[-- Up/down controls
	if(inputManager:isKeyPressed(KeyCode.SPACE)) then
		cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, speed/30, 0)) )
	elseif(inputManager:isKeyPressed(KeyCode.LCTRL)) then
		cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, -speed/30, 0)) )
	end--]]
	
	-- Action
	if(inputManager:isKeyPressed(KeyCode.e)) then
		if(actionButtonPressedLastFrame == false) then
			actionButtonPressedLastFrame = true
			doAction()
		end
	else
		actionButtonPressedLastFrame = false
	end
	
	if(transitioning~=false) then
		cameraPhysicsBody:setVelocity(Vec3(0, 0, 0))
		
		if(os.clock()>(timeAtTimerStart + timerLength)) then
			if(transitioning==1) then
				transitioning = 2
				
				-- Reset timer
				timeAtTimerStart = os.clock() -- In seconds
				timerLength = 4
				
				resourceManager:findSound("BusDriving"):halt()
				resourceManager:findSound("BusCrash"):play()
			elseif(transitioning==2) then
				transitioning = false
				-- Load forest
				resetWorld()
				loadForest()
				cameraPhysicsBody:setPosition(Vec3(11.1689, -0.634 + playerHeight, 42.1478))
				camera:setDirection(Vec4(-1, 0, 0, 0))
			end
		end
	end
	
	if(level == 2) then -- Forest
		local tileDeleteDistance = forestNextTilePosition.z - forestMinTilesForSeamless*forestTileLength
		local cameraDirection = camera:getDirection()
		
		forest5050Step = not forest5050Step
		
		if(forestRunStarted == false and level == 2) then
			if(os.clock()>(timeAtTimerStart + timerLength)) then
				-- Start running!
				forestRunStarted = true
				camera:setDirection(Vec4(0, 0, 1, 0))
				entityManager:removeObject(forestIntroCollision)
			end
		end
		
		if(forestRunStarted == true) then
			forestSpeed = forestSpeed + forestAcceleration
			
			-- We need this since we can't velocity until we step the world
			if(forest5050Step == true) then
				local velocity = Vec3.scalarMul(Vec3.normalize(Vec3(cameraDirection.x, 0, cameraDirection.z)), forestSpeed)
				cameraPhysicsBody:setVelocity(velocity)
			else
				if(distanceSquaredBetweenPoints(cameraPhysicsBody:getPosition(), forestLastPosition) < (1.5 * 1.5)) then
					forestStepsPlayerSlow = forestStepsPlayerSlow + 1
					
					if(forestStepsPlayerSlow >= forestStepsSlowToLose) then
						forestRunStarted = false
						lose()
					end
				else
					forestStepsPlayerSlow = 0
					forestLastPosition = cameraPhysicsBody:getPosition()
				end
			end
		end
		
		if(cameraPhysicsBody:getPosition().z > tileDeleteDistance) then
			createRandomForestTiles(forestNextTilePosition, forestNumberOfTilesToCreate)
			
			if(forestFirstTileDeletion == false) then
				-- Delete tiles we no longer see
				-- Removes this amount of tiles from the start
				local tilesToDelete = forestNumberOfTilesToCreate
				
				-- Inverted loop for removing tiles
				for i=tilesToDelete,1,-1 do
					local tile = forestTileObjects[i]
					
					-- Remove the tile's objects
					for j=1,#tile,1 do
						entityManager:removeObject(tile[j])
					end
					
					table.remove(forestTileObjects, i)
				end
			else
				forestFirstTileDeletion = false
			end
		end
	end
end

-- 3D
function distanceBetweenPoints(p1, p2)
	return math.pow(distanceSquaredBetweenPoints(p1, p2), 1/3)
end

function distanceSquaredBetweenPoints(p1, p2)
	local deltaX = p2.x - p1.x
	local deltaY = p2.y - p1.y
	local deltaZ = p2.z - p1.z
	
	return (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ)
end

-- When you press the action button, this is called
function doAction()
	local camera = entityManager:getGameCamera()
	local cameraPhysicsBody = camera:getPhysicsBody()
	local pos = camera:getPhysicsBody():getPosition()
	
	local maxDistanceSquared = 1.2 * 1.2 -- In meters, as always
	
	if(level == 1) then
		-- From apartment to room
		if(distanceSquaredBetweenPoints(pos, Vec3(-60.76, playerHeight, -15.7)) <= maxDistanceSquared) then
			cameraPhysicsBody:setPosition(Vec3(-592.2, -274.9 + playerHeight, -11.6))
			camera:setDirection(Vec4(0, 0, 1, 0)) -- 0 for vector, not point
		end
		
		-- From room to apartment
		if(distanceSquaredBetweenPoints(pos, Vec3(-592.2, -274.9 + playerHeight, -11.6)) <= maxDistanceSquared) then
			cameraPhysicsBody:setPosition(Vec3(-60.76, playerHeight, -15.7))
			camera:setDirection(Vec4(0, 0, -1, 0))
		end
		
		-- Take room book
		if(distanceSquaredBetweenPoints(pos, Vec3(-591.49, -274.9 + playerHeight, -8.45)) <= maxDistanceSquared) then
			roomTableObject:setTexture(resourceManager:findTexture("TableEmpty"))
		end
		
		-- Bus door
		if(transitioning == false) then -- To be nice
			if(distanceSquaredBetweenPoints(pos, Vec3(-17.109, playerHeight, -45.71)) <= maxDistanceSquared) then
				local randomPos = Vec3(100, 100, 100)
				cameraPhysicsBody:setPosition(randomPos)
				local box = addObjectGeometries("BlackBox", false, "BlackBox", PhysicsBodyType.Ignored)[1]
				box:getPhysicsBody():setPosition(randomPos)
			
				transitioning = 1
				timeAtTimerStart = os.clock() -- In seconds
				timerLength = 2
				
				resourceManager:findSound("Pyongyang_Music"):halt()
				resourceManager:findSound("BusDriving"):play()
			end
		end
	end
	
	-- Restart
	if(level == 3) then
		if(distanceSquaredBetweenPoints(pos, Vec3(24.13, -1.01 + playerHeight, 20.57)) <= maxDistanceSquared) then
			timeAtTimerStart = 0
			timerLength = 0 -- In seconds
			transitioning = false

			level = 1 -- Current level (1 for pyongyang)

			forestTileLength = 24.3
			forestFirstTilePosition = Vec3(22.89, -1.18, 98.94)
			forestNextTilePosition = 0 -- Z coord when we last deleted/created tiles, changed when generating initial forest tiles

			forestNumberOfTileStyles = 4
			forestNumberOfTilesToCreate = 5 -- Create tiles when we delete/create them
			forestMinTilesForSeamless = 3 -- Minimum amount of tiles that hide us creating new tiles!

			forestTileObjects = {} -- A 2D list, first-D for tiles, second-D for objects in that tile

			forestFirstTileDeletion = true

			forestRunStarted = false
			forest5050Step = false -- 50/50 frame flag, beautiful name
			forestSpeed = 5 -- Initial speed
			forestAcceleration = 0.01

			forestStepsSlowToLose = 30
			forestStepsPlayerSlow = 0
			forestLastPosition = Vec3(0, 0, 0)

			forestIntroCollision = nil -- Remove after intro ends!
			
			resetWorld()
			loadPyongyang()
		end
	end
	
	--[[Utils.logprint("")
	Utils.logprint("Our pos x: " .. pos.x)
	Utils.logprint("Our pos y: " .. pos.y)
	Utils.logprint("Our pos z: " .. pos.z)]]--
end

-- Returns the index of the first instance of element
function findInArray(element, array)
	for i,v in ipairs(array) do
		if(v == element) then
			return v
		end
	end
end

function lose()
	Utils.logprint("Player died!")
	resetWorld()
	loadCamp()
end