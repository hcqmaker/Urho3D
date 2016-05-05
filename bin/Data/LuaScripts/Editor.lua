
function simpleclass(c)
    local tc = {};
    for k, v in pairs(c) do tc[k] = v; end
    return tc;
end


--=================================================
-- for something not in 
script = {
    defaultScriptFile = nil,
    defaultScene = nil,
    Execute = function(command)
        loadstring(command)
    end
}

function GetObjectCategories()
    return GetContext():GetObjectCategoriesKeys();
end

function GetObjectsByCategory(v)
    return GetContext():GetObjectsByCategory(v);
end





function __G__TRACKBACK__(msg)
    log_error("-----------------------------------------------------");
    log_error(msg)
    log_error(debug.traceback())
    log_error("-----------------------------------------------------");
end

--[[
function log_info(str) log:Write(LOG_INFO, str.."") end
function log_debug(str) log:Write(LOG_DEBUG, str.."") end
function log_warn(str) log:Write(LOG_WARNING, str.."") end
function log_error(str) log:Write(LOG_ERROR, str.."") end
--]]
function log_info(str) print(str.."") end
function log_debug(str)  print(str.."") end
function log_warn(str)  print(str.."") end
function log_error(str) print(str.."") end

--=================================================
--=================================================


require "LuaScripts/Editor/EditorUtils"

require "LuaScripts/Editor/EditorHierarchyWindow"
require "LuaScripts/Editor/EditorView"
require "LuaScripts/Editor/EditorScene"
require "LuaScripts/Editor/EditorActions"
require "LuaScripts/Editor/EditorUIElement"
require "LuaScripts/Editor/EditorGizmo"
require "LuaScripts/Editor/EditorMaterial"
require "LuaScripts/Editor/EditorParticleEffect"
require "LuaScripts/Editor/EditorSettings"
require "LuaScripts/Editor/EditorPreferences"
require "LuaScripts/Editor/EditorToolBar"
require "LuaScripts/Editor/EditorSecondaryToolbar"
require "LuaScripts/Editor/EditorUI"
require "LuaScripts/Editor/EditorImport"
require "LuaScripts/Editor/EditorResourceBrowser"
require "LuaScripts/Editor/EditorSpawn"
require "LuaScripts/Editor/EditorSoundType"


-- edit  LoadConfig()
local configFileName

function Start()
	configFileName = fileSystem:GetAppPreferencesDir("urho3d", "Editor").."Config.xml"
	if (engine.headless) then
		ErrorDialog("Urho3D Editor", "Headless mode is not supported. The program will now exit.");
        engine:Exit();
        return;
	end
	
    OpenConsoleWindow();
    CreateLogo();
    SetWindowTitleAndIcon();
    
	SubscribeToEvent("Update", "FirstFrame");
	SubscribeToEvent(input, "ExitRequested", "HandleExitRequested");
	--engine.autoExit = false;
	script.defaultScriptFile = scriptFile;
	cache.autoReloadResources = true;
	cache.returnFailedResources = true;
	input.mouseVisible = true;
	ui.useSystemClipboard = true;
    --]]
end

function FirstFrame()

    print("=========>>===0");
	CreateScene();
	LoadConfig();
    print("=========>>===1");
	CreateUI();
	print("=========>>===2");
	CreateRootUIElement();
	ParseArguments();
    --
	SubscribeToEvent("Update", "HandleUpdate");
    SubscribeToEvent("ReloadFinished", "HandleReloadFinished");
    SubscribeToEvent("ReloadFailed", "HandleReloadFailed");
	--]]
end

function CreateLogo()
    -- Get logo texture
    local logoTexture = cache:GetResource("Texture2D", "Textures/LogoLarge.png")
    if logoTexture == nil then
        return
    end

    logoSprite = ui.root:CreateChild("Sprite")
    logoSprite:SetTexture(logoTexture)
    local textureWidth = logoTexture.width
    local textureHeight = logoTexture.height
    logoSprite:SetScale(256 / textureWidth)
    logoSprite:SetSize(textureWidth, textureHeight)
    logoSprite.hotSpot = IntVector2(0, textureHeight)
    logoSprite:SetAlignment(HA_LEFT, VA_BOTTOM);
    logoSprite.opacity = 0.75
    logoSprite.priority = -100
end

function SetWindowTitleAndIcon()
    local icon = cache:GetResource("Image", "Textures/UrhoIcon.png")
    graphics:SetWindowIcon(icon)
    graphics.windowTitle = "Urho3D Sample"
end



function HandleUpdate(eventType, eventData)

    local timeStep = eventData["TimeStep"]:GetFloat();

    -- DoResourceBrowserWork();
    -- UpdateView(timeStep);
    -- UpdateViewports(timeStep);
    -- UpdateStats(timeStep);
    UpdateScene(timeStep);
    -- UpdateTestAnimation(timeStep);
    -- UpdateGizmo();
    -- UpdateDirtyUI();

    -- Handle Particle Editor looping.
    if (particleEffectWindow ~= nil and particleEffectWindow.visible) then
        if (not particleEffectEmitter.emitting) then
            if (particleResetTimer == 0.0) then
                particleResetTimer = editParticleEffect.maxTimeToLive + 0.2;
            else
                particleResetTimer = Max(particleResetTimer - timeStep, 0.0);
                if (particleResetTimer <= 0.0001) then
                    particleEffectEmitter:Reset();
                    particleResetTimer = 0.0;
                end
            end
        end
    end
end

function HandleReloadFinished(eventType, eventData)
    attributesFullDirty = true;
end

function HandleReloadFailed(eventType, eventData)
    attributesFullDirty = true;
end

function Stop()
	--SaveConfig();
end

function ParseArguments()
	local arguments = GetArguments();
	local loaded = false;
	local num = #arguments;
	for i = 1, num do
		if (string.lower(arguments[i]) == "-scene") then
			i = i + 1;
			if (i < num) then
				loaded = LoadScene(arguments[i]);
				break;
			end
		end
	end
	if (not loaded) then
		ResetScene();
	end
end

function LoadConfig()
	if (not fileSystem:FileExists(configFileName)) then
		return;
	end

	local config = XMLFile();
    config:Load(configFileName);

    local configElem = config.root;
    if (configElem == nil) then
        return;
    end

    local cameraElem = configElem:GetChild("camera");
    local objectElem = configElem:GetChild("object");
    local renderingElem = configElem:GetChild("rendering");
    local uiElem = configElem:GetChild("ui");
    local hierarchyElem = configElem:GetChild("hierarchy");
    local inspectorElem = configElem:GetChild("attributeinspector");
    local viewElem = configElem:GetChild("view");
    local resourcesElem = configElem:GetChild("resources");
    local consoleElem = configElem:GetChild("console");
    local varNamesElem = configElem:GetChild("varnames");
    local soundTypesElem = configElem:GetChild("soundtypes");

    if (not cameraElem.isNull) then
        if (cameraElem:HasAttribute("nearclip")) then viewNearClip = cameraElem:GetFloat("nearclip"); end
        if (cameraElem:HasAttribute("farclip")) then viewFarClip = cameraElem:GetFloat("farclip"); end
        if (cameraElem:HasAttribute("fov")) then viewFov = cameraElem:GetFloat("fov"); end
        if (cameraElem:HasAttribute("speed")) then cameraBaseSpeed = cameraElem:GetFloat("speed"); end
        if (cameraElem:HasAttribute("limitrotation")) then limitRotation = cameraElem:GetBool("limitrotation"); end
        if (cameraElem:HasAttribute("mousewheelcameraposition")) then mouseWheelCameraPosition = cameraElem:GetBool("mousewheelcameraposition"); end
        if (cameraElem:HasAttribute("viewportmode")) then viewportMode = cameraElem:GetUInt("viewportmode"); end
        if (cameraElem:HasAttribute("mouseorbitmode")) then mouseOrbitMode = cameraElem:GetInt("mouseorbitmode"); end
        --UpdateViewParameters();
    end

    if (not objectElem.isNull) then
        if (objectElem:HasAttribute("newnodedistance")) then newNodeDistance = objectElem:GetFloat("newnodedistance"); end
        if (objectElem:HasAttribute("movestep")) then moveStep = objectElem:GetFloat("movestep"); end
        if (objectElem:HasAttribute("rotatestep")) then rotateStep = objectElem:GetFloat("rotatestep"); end
        if (objectElem:HasAttribute("scalestep")) then scaleStep = objectElem:GetFloat("scalestep"); end
        if (objectElem:HasAttribute("movesnap")) then moveSnap = objectElem:GetBool("movesnap"); end
        if (objectElem:HasAttribute("rotatesnap")) then rotateSnap = objectElem:GetBool("rotatesnap"); end
        if (objectElem:HasAttribute("scalesnap")) then scaleSnap = objectElem:GetBool("scalesnap"); end
        if (objectElem:HasAttribute("applymateriallist")) then applyMaterialList = objectElem:GetBool("applymateriallist"); end
        if (objectElem:HasAttribute("importoptions")) then importOptions = objectElem:GetAttribute("importoptions"); end
        if (objectElem:HasAttribute("pickmode")) then pickMode = objectElem:GetInt("pickmode"); end
        if (objectElem:HasAttribute("axismode")) then axisMode = AxisMode(objectElem:GetInt("axismode")); end
        if (objectElem:HasAttribute("revertonpause")) then revertOnPause = objectElem:GetBool("revertonpause"); end
    end

    if (not resourcesElem.isNull) then
        if (resourcesElem:HasAttribute("rememberresourcepath")) then rememberResourcePath = resourcesElem:GetBool("rememberresourcepath"); end
        if (rememberResourcePath and resourcesElem:HasAttribute("resourcepath")) then
            local newResourcePath = resourcesElem:GetAttribute("resourcepath");
            if (fileSystem:DirExists(newResourcePath)) then
                SetResourcePath(resourcesElem:GetAttribute("resourcepath"), false);
            end
        end
        if (resourcesElem:HasAttribute("importpath")) then
            local newImportPath = resourcesElem:GetAttribute("importpath");
            if (fileSystem:DirExists(newImportPath)) then
                uiImportPath = newImportPath;
            end
        end
        if (resourcesElem:HasAttribute("recentscenes")) then
            uiRecentScenes = resourcesElem:GetAttribute("recentscenes"):Split(';');
        end
    end

    if (not renderingElem.isNull) then
        if (renderingElem:HasAttribute("renderpath")) then renderPathName = renderingElem:GetAttribute("renderpath"); end
        if (renderingElem:HasAttribute("texturequality")) then renderer.textureQuality = renderingElem:GetInt("texturequality"); end
        if (renderingElem:HasAttribute("materialquality")) then renderer.materialQuality = renderingElem:GetInt("materialquality"); end
        if (renderingElem:HasAttribute("shadowresolution")) then SetShadowResolution(renderingElem:GetInt("shadowresolution")); end
        if (renderingElem:HasAttribute("shadowquality")) then renderer.shadowQuality = renderingElem:GetInt("shadowquality"); end
        if (renderingElem:HasAttribute("maxoccludertriangles")) then renderer.maxOccluderTriangles = renderingElem:GetInt("maxoccludertriangles"); end
        if (renderingElem:HasAttribute("specularlighting")) then renderer.specularLighting = renderingElem:GetBool("specularlighting"); end
        if (renderingElem:HasAttribute("dynamicinstancing")) then renderer.dynamicInstancing = renderingElem:GetBool("dynamicinstancing"); end
        if (renderingElem:HasAttribute("framelimiter")) then 
            local maxFps = 0;
            if (renderingElem:GetBool("framelimiter")) then
                maxFps = 200;
            end
            engine.maxFps = maxFps;
        end
    end

    if (not uiElem.isNull) then
        if (uiElem:HasAttribute("minopacity")) then uiMinOpacity = uiElem:GetFloat("minopacity"); end
        if (uiElem:HasAttribute("maxopacity")) then uiMaxOpacity = uiElem:GetFloat("maxopacity"); end
    end

    if (not hierarchyElem.isNull) then
        if (hierarchyElem:HasAttribute("showinternaluielement")) then showInternalUIElement = hierarchyElem:GetBool("showinternaluielement"); end
        if (hierarchyElem:HasAttribute("showtemporaryobject")) then showTemporaryObject = hierarchyElem:GetBool("showtemporaryobject"); end
        if (inspectorElem:HasAttribute("nodecolor")) then nodeTextColor = inspectorElem:GetColor("nodecolor"); end
        if (inspectorElem:HasAttribute("componentcolor")) then componentTextColor = inspectorElem:GetColor("componentcolor"); end
    end

    if (not inspectorElem.isNull) then
        if (inspectorElem:HasAttribute("originalcolor")) then normalTextColor = inspectorElem:GetColor("originalcolor"); end
        if (inspectorElem:HasAttribute("modifiedcolor")) then modifiedTextColor = inspectorElem:GetColor("modifiedcolor"); end
        if (inspectorElem:HasAttribute("noneditablecolor")) then nonEditableTextColor = inspectorElem:GetColor("noneditablecolor"); end
        if (inspectorElem:HasAttribute("shownoneditable")) then showNonEditableAttribute = inspectorElem:GetBool("shownoneditable"); end
    end

    if (not viewElem.isNull) then
        if (viewElem:HasAttribute("defaultzoneambientcolor")) then renderer.defaultZone.ambientColor = viewElem:GetColor("defaultzoneambientcolor"); end
        if (viewElem:HasAttribute("defaultzonefogcolor")) then renderer.defaultZone.fogColor = viewElem:GetColor("defaultzonefogcolor"); end
        if (viewElem:HasAttribute("defaultzonefogstart")) then renderer.defaultZone.fogStart = viewElem:GetInt("defaultzonefogstart"); end
        if (viewElem:HasAttribute("defaultzonefogend")) then renderer.defaultZone.fogEnd = viewElem:GetInt("defaultzonefogend"); end
        if (viewElem:HasAttribute("showgrid")) then showGrid = viewElem:GetBool("showgrid"); end
        if (viewElem:HasAttribute("grid2dmode")) then grid2DMode = viewElem:GetBool("grid2dmode"); end
        if (viewElem:HasAttribute("gridsize")) then gridSize = viewElem:GetInt("gridsize"); end
        if (viewElem:HasAttribute("gridsubdivisions")) then gridSubdivisions = viewElem:GetInt("gridsubdivisions"); end
        if (viewElem:HasAttribute("gridscale")) then gridScale = viewElem:GetFloat("gridscale"); end
        if (viewElem:HasAttribute("gridcolor")) then gridColor = viewElem:GetColor("gridcolor"); end
        if (viewElem:HasAttribute("gridsubdivisioncolor")) then gridSubdivisionColor = viewElem:GetColor("gridsubdivisioncolor"); end
    end

    if (not consoleElem.isNull) then
        -- Console does not exist yet at this point, so store the string in a global variable
        if (consoleElem:HasAttribute("commandinterpreter")) then consoleCommandInterpreter = consoleElem:GetAttribute("commandinterpreter"); end
    end

    if (not varNamesElem.isNull) then
        globalVarNames = varNamesElem:GetVariantMap();
    end

    if (not soundTypesElem.isNull) then
        LoadSoundTypes(soundTypesElem);
    end
end

function SaveConfig()

    local config = XMLFile();
    local configElem = config:CreateRoot("configuration");
    local cameraElem = configElem:CreateChild("camera");
    local objectElem = configElem:CreateChild("object");
    local renderingElem = configElem:CreateChild("rendering");
    local uiElem = configElem:CreateChild("ui");
    local hierarchyElem = configElem:CreateChild("hierarchy");
    local inspectorElem = configElem:CreateChild("attributeinspector");
    local viewElem = configElem:CreateChild("view");
    local resourcesElem = configElem:CreateChild("resources");
    local consoleElem = configElem:CreateChild("console");
    local varNamesElem = configElem:CreateChild("varnames");
    local soundTypesElem = configElem:CreateChild("soundtypes");

    cameraElem:SetFloat("nearclip", viewNearClip);
    cameraElem:SetFloat("farclip", viewFarClip);
    cameraElem:SetFloat("fov", viewFov);
    cameraElem:SetFloat("speed", cameraBaseSpeed);
    cameraElem:SetBool("limitrotation", limitRotation);
    cameraElem:SetBool("mousewheelcameraposition", mouseWheelCameraPosition);
    cameraElem:SetUInt("viewportmode", viewportMode);
    cameraElem:SetInt("mouseorbitmode", mouseOrbitMode);

    objectElem:SetFloat("newnodedistance", newNodeDistance);
    objectElem:SetFloat("movestep", moveStep);
    objectElem:SetFloat("rotatestep", rotateStep);
    objectElem:SetFloat("scalestep", scaleStep);
    objectElem:SetBool("movesnap", moveSnap);
    objectElem:SetBool("rotatesnap", rotateSnap);
    objectElem:SetBool("scalesnap", scaleSnap);
    objectElem:SetBool("applymateriallist", applyMaterialList);
    objectElem:SetAttribute("importoptions", importOptions);
    objectElem:SetInt("pickmode", pickMode);
    objectElem:SetInt("axismode", axisMode);
    objectElem:SetBool("revertonpause", revertOnPause);

    resourcesElem:SetBool("rememberresourcepath", rememberResourcePath);
    resourcesElem:SetAttribute("resourcepath", sceneResourcePath);
    resourcesElem:SetAttribute("importpath", uiImportPath);
    resourcesElem:SetAttribute("recentscenes", Join(uiRecentScenes, ";"));

    if (renderer ~= nil and graphics ~= nil) then
        renderingElem:SetAttribute("renderpath", renderPathName);
        renderingElem:SetInt("texturequality", renderer.textureQuality);
        renderingElem:SetInt("materialquality", renderer.materialQuality);
        renderingElem:SetInt("shadowresolution", GetShadowResolution());
        renderingElem:SetInt("maxoccludertriangles", renderer.maxOccluderTriangles);
        renderingElem:SetBool("specularlighting", renderer.specularLighting);
        renderingElem:SetInt("shadowquality", renderer.shadowQuality);
        renderingElem:SetBool("dynamicinstancing", renderer.dynamicInstancing);
    end

    renderingElem:SetBool("framelimiter", engine.maxFps > 0);

    uiElem:SetFloat("minopacity", uiMinOpacity);
    uiElem:SetFloat("maxopacity", uiMaxOpacity);

    hierarchyElem:SetBool("showinternaluielement", showInternalUIElement);
    hierarchyElem:SetBool("showtemporaryobject", showTemporaryObject);
    inspectorElem:SetColor("nodecolor", nodeTextColor);
    inspectorElem:SetColor("componentcolor", componentTextColor);

    inspectorElem:SetColor("originalcolor", normalTextColor);
    inspectorElem:SetColor("modifiedcolor", modifiedTextColor);
    inspectorElem:SetColor("noneditablecolor", nonEditableTextColor);
    inspectorElem:SetBool("shownoneditable", showNonEditableAttribute);

    viewElem:SetBool("showgrid", showGrid);
    viewElem:SetBool("grid2dmode", grid2DMode);
    viewElem:SetColor("defaultzoneambientcolor", renderer.defaultZone.ambientColor);
    viewElem:SetColor("defaultzonefogcolor", renderer.defaultZone.fogColor);
    viewElem:SetFloat("defaultzonefogstart", renderer.defaultZone.fogStart);
    viewElem:SetFloat("defaultzonefogend", renderer.defaultZone.fogEnd);
    viewElem:SetInt("gridsize", gridSize);
    viewElem:SetInt("gridsubdivisions", gridSubdivisions);
    viewElem:SetFloat("gridscale", gridScale);
    viewElem:SetColor("gridcolor", gridColor);
    viewElem:SetColor("gridsubdivisioncolor", gridSubdivisionColor);

    consoleElem:SetAttribute("commandinterpreter", console.commandInterpreter);

    varNamesElem:SetVariantMap(globalVarNames);

    SaveSoundTypes(soundTypesElem);

    config:Save(configFileName);
end
