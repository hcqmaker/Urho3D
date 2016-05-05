-- Urho3D material editor

particleEffectWindow = nil; --Window
editParticleEffect = nil; -- ParticleEffect
oldParticleEffectState = nil; --XMLFile
inParticleEffectRefresh = false;
particleEffectPreview = nil; -- View3D
particlePreviewScene = nil; -- Scene
particleEffectPreviewNode = nil; -- Node
particlePreviewCameraNode = nil; -- Node
particlePreviewLightNode = nil; -- Node
particlePreviewLight = nil; --Light 
particleEffectEmitter = nil; -- ParticleEmitter
particleResetTimer = 0.0;

function CreateParticleEffectEditor()
    if (particleEffectWindow ~= nil) then
        return;
	end

    particleEffectWindow = LoadEditorUI("UI/EditorParticleEffectWindow.xml");
    ui.root:AddChild(particleEffectWindow);
    particleEffectWindow.opacity = uiMaxOpacity;

    InitParticleEffectPreview();
    InitParticleEffectBasicAttributes();
    RefreshParticleEffectEditor();

    local height = Min(ui.root.height - 60, 500);
	particleEffectWindow:SetSize(300, height);
    CenterDialog(particleEffectWindow);

    HideParticleEffectEditor();

    SubscribeToEvent(particleEffectWindow:GetChild("NewButton", true), "Released", "NewParticleEffect");
    SubscribeToEvent(particleEffectWindow:GetChild("RevertButton", true), "Released", "RevertParticleEffect");
    SubscribeToEvent(particleEffectWindow:GetChild("SaveButton", true), "Released", "SaveParticleEffect");
    SubscribeToEvent(particleEffectWindow:GetChild("SaveAsButton", true), "Released", "SaveParticleEffectAs");
    SubscribeToEvent(particleEffectWindow:GetChild("CloseButton", true), "Released", "HideParticleEffectEditor");
    SubscribeToEvent(particleEffectWindow:GetChild("NewColorFrame", true), "Released", "EditParticleEffectColorFrameNew");
    SubscribeToEvent(particleEffectWindow:GetChild("RemoveColorFrame", true), "Released", "EditParticleEffectColorFrameRemove");
    SubscribeToEvent(particleEffectWindow:GetChild("ColorFrameSort", true), "Released", "EditParticleEffectColorFrameSort");
    SubscribeToEvent(particleEffectWindow:GetChild("NewTextureFrame", true), "Released", "EditParticleEffectTextureFrameNew");
    SubscribeToEvent(particleEffectWindow:GetChild("RemoveTextureFrame", true), "Released", "EditParticleEffectTextureFrameRemove");
    SubscribeToEvent(particleEffectWindow:GetChild("TextureFrameSort", true), "Released", "EditParticleEffectTextureFrameSort");
    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceX", true), "TextChanged", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceY", true), "TextChanged", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceZ", true), "TextChanged", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinX", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinY", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinZ", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxX", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxY", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxZ", true), "TextChanged", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DampingForce", true), "TextChanged", "EditParticleEffectDampingForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ActiveTime", true), "TextChanged", "EditParticleEffectActiveTime");
    SubscribeToEvent(particleEffectWindow:GetChild("InactiveTime", true), "TextChanged", "EditParticleEffectInactiveTime");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMinX", true), "TextChanged", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMinY", true), "TextChanged", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMaxX", true), "TextChanged", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMaxY", true), "TextChanged", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("TimeToLiveMin", true), "TextChanged", "EditParticleEffectTimeToLive");
    SubscribeToEvent(particleEffectWindow:GetChild("TimeToLiveMax", true), "TextChanged", "EditParticleEffectTimeToLive");
    SubscribeToEvent(particleEffectWindow:GetChild("VelocityMin", true), "TextChanged", "EditParticleEffectVelocity");
    SubscribeToEvent(particleEffectWindow:GetChild("VelocityMax", true), "TextChanged", "EditParticleEffectVelocity");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationMin", true), "TextChanged", "EditParticleEffectRotation");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationMax", true), "TextChanged", "EditParticleEffectRotation");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationSpeedMin", true), "TextChanged", "EditParticleEffectRotationSpeed");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationSpeedMax", true), "TextChanged", "EditParticleEffectRotationSpeed");
    SubscribeToEvent(particleEffectWindow:GetChild("SizeAdd", true), "TextChanged", "EditParticleEffectSizeAdd");
    SubscribeToEvent(particleEffectWindow:GetChild("SizeMultiply", true), "TextChanged", "EditParticleEffectSizeMultiply");
    SubscribeToEvent(particleEffectWindow:GetChild("AnimationLodBias", true), "TextChanged", "EditParticleEffectAnimationLodBias");
    SubscribeToEvent(particleEffectWindow:GetChild("NumParticles", true), "TextChanged", "EditParticleEffectNumParticles");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeX", true), "TextChanged", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeY", true), "TextChanged", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeZ", true), "TextChanged", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmissionRateMin", true), "TextChanged", "EditParticleEffectEmissionRate");
    SubscribeToEvent(particleEffectWindow:GetChild("EmissionRateMax", true), "TextChanged", "EditParticleEffectEmissionRate");

    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceX", true), "TextFinished", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceY", true), "TextFinished", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ConstantForceZ", true), "TextFinished", "EditParticleEffectConstantForce");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinX", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinY", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMinZ", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxX", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxY", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DirectionMaxZ", true), "TextFinished", "EditParticleEffectDirection");
    SubscribeToEvent(particleEffectWindow:GetChild("DampingForce", true), "TextFinished", "EditParticleEffectDampingForce");
    SubscribeToEvent(particleEffectWindow:GetChild("ActiveTime", true), "TextFinished", "EditParticleEffectActiveTime");
    SubscribeToEvent(particleEffectWindow:GetChild("InactiveTime", true), "TextFinished", "EditParticleEffectInactiveTime");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMinX", true), "TextFinished", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMinY", true), "TextFinished", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMaxX", true), "TextFinished", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("ParticleSizeMaxY", true), "TextFinished", "EditParticleEffectParticleSize");
    SubscribeToEvent(particleEffectWindow:GetChild("TimeToLiveMin", true), "TextFinished", "EditParticleEffectTimeToLive");
    SubscribeToEvent(particleEffectWindow:GetChild("TimeToLiveMax", true), "TextFinished", "EditParticleEffectTimeToLive");
    SubscribeToEvent(particleEffectWindow:GetChild("VelocityMin", true), "TextFinished", "EditParticleEffectVelocity");
    SubscribeToEvent(particleEffectWindow:GetChild("VelocityMax", true), "TextFinished", "EditParticleEffectVelocity");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationMin", true), "TextFinished", "EditParticleEffectRotation");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationMax", true), "TextFinished", "EditParticleEffectRotation");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationSpeedMin", true), "TextFinished", "EditParticleEffectRotationSpeed");
    SubscribeToEvent(particleEffectWindow:GetChild("RotationSpeedMax", true), "TextFinished", "EditParticleEffectRotationSpeed");
    SubscribeToEvent(particleEffectWindow:GetChild("SizeAdd", true), "TextFinished", "EditParticleEffectSizeAdd");
    SubscribeToEvent(particleEffectWindow:GetChild("SizeMultiply", true), "TextFinished", "EditParticleEffectSizeMultiply");
    SubscribeToEvent(particleEffectWindow:GetChild("AnimationLodBias", true), "TextFinished", "EditParticleEffectAnimationLodBias");
    SubscribeToEvent(particleEffectWindow:GetChild("NumParticles", true), "TextFinished", "EditParticleEffectNumParticles");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeX", true), "TextFinished", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeY", true), "TextFinished", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterSizeZ", true), "TextFinished", "EditParticleEffectEmitterSize");
    SubscribeToEvent(particleEffectWindow:GetChild("EmissionRateMin", true), "TextFinished", "EditParticleEffectEmissionRate");
    SubscribeToEvent(particleEffectWindow:GetChild("EmissionRateMax", true), "TextFinished", "EditParticleEffectEmissionRate");

    SubscribeToEvent(particleEffectWindow:GetChild("EmitterShape", true), "ItemSelected", "EditParticleEffectEmitterShape");
    SubscribeToEvent(particleEffectWindow:GetChild("Scaled", true), "Toggled", "EditParticleEffectScaled");
    SubscribeToEvent(particleEffectWindow:GetChild("Sorted", true), "Toggled", "EditParticleEffectSorted");
    SubscribeToEvent(particleEffectWindow:GetChild("Relative", true), "Toggled", "EditParticleEffectRelative");

end

function EditParticleEffectColorFrameNew(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local num = editParticleEffect.numColorFrames;
    editParticleEffect.numColorFrames = num + 1;
    RefreshParticleEffectColorFrames();

    EndParticleEffectEdit();
end

function EditParticleEffectTextureFrameNew(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local num = editParticleEffect.numTextureFrames;
    editParticleEffect.numTextureFrames = num + 1;
    RefreshParticleEffectTextureFrames();

    EndParticleEffectEdit();
end

function EditParticleEffectColorFrameRemove(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    local lv = particleEffectWindow:GetChild("ColorFrameListView", true);
    if (lv ~= nil and lv.selection ~= M_MAX_UNSIGNED ) then
        BeginParticleEffectEdit();
        
        editParticleEffect.RemoveColorFrame(lv.selection);
        RefreshParticleEffectColorFrames();

        EndParticleEffectEdit();
	end 

end


function EditParticleEffectTextureFrameRemove(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    local lv = particleEffectWindow:GetChild("TextureFrameListView", true);
    if (lv ~= nil and lv.selection ~= M_MAX_UNSIGNED ) then
        BeginParticleEffectEdit();
        
		editParticleEffect:RemoveTextureFrame(lv.selection);
        RefreshParticleEffectTextureFrames();

        EndParticleEffectEdit();
	end 
end

function EditParticleEffectColorFrameSort(eventType, eventData)
    RefreshParticleEffectColorFrames();
end

function EditParticleEffectTextureFrameSort(eventType, eventData)
    RefreshParticleEffectTextureFrames();
end

function InitParticleEffectBasicAttributes()
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ConstantForceX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ConstantForceY", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ConstantForceZ", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMinX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMinY", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMinZ", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMaxX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMaxY", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DirectionMaxZ", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("DampingForce", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ActiveTime", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("InactiveTime", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ParticleSizeMinX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ParticleSizeMinY", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ParticleSizeMaxX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("ParticleSizeMaxY", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("TimeToLiveMin", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("TimeToLiveMax", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("VelocityMin", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("VelocityMax", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("RotationMin", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("RotationMax", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("RotationSpeedMin", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("RotationSpeedMax", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("SizeAdd", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("SizeMultiply", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("AnimationLodBias", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("NumParticles", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("EmitterSizeX", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("EmitterSizeY", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("EmitterSizeZ", true), "LineEdit"));

    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("EmissionRateMin", true), "LineEdit"));
    CreateDragSlider(tolua.cast(particleEffectWindow:GetChild("EmissionRateMax", true), "LineEdit"));
end

function EditParticleEffectConstantForce(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local v = editParticleEffect.constantForce;

    if (element.name == "ConstantForceX") then
        editParticleEffect.constantForce = Vector3(ToFloat(element.text), v.y, v.z);
	end

    if (element.name == "ConstantForceY") then
        editParticleEffect.constantForce = Vector3(v.x, ToFloat(element.text), v.z);
	end

    if (element.name == "ConstantForceZ") then
        editParticleEffect.constantForce = Vector3(v.x, v.y, ToFloat(element.text));
	end

    EndParticleEffectEdit();
end

function EditParticleEffectDirection(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minDirection;
    local vMax = editParticleEffect.maxDirection;

    if (element.name == "DirectionMinX") then
        editParticleEffect.minDirection = Vector3(ToFloat(element.text), vMin.y, vMin.z);
	end

    if (element.name == "DirectionMinY") then
        editParticleEffect.minDirection = Vector3(vMin.x, ToFloat(element.text), vMin.z);
	end

    if (element.name == "DirectionMinZ") then
        editParticleEffect.minDirection = Vector3(vMin.x, vMin.y, ToFloat(element.text));
	end

    if (element.name == "DirectionMaxX") then
        editParticleEffect.maxDirection = Vector3(ToFloat(element.text), vMax.y, vMax.z);
	end

    if (element.name == "DirectionMaxY") then
        editParticleEffect.maxDirection = Vector3(vMax.x, ToFloat(element.text), vMax.z);
	end

    if (element.name == "DirectionMaxZ") then
        editParticleEffect.maxDirection = Vector3(vMax.x, vMax.y, ToFloat(element.text));
	end

    EndParticleEffectEdit();
end

function EditParticleEffectDampingForce(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.dampingForce = ToFloat(element.text);

    EndParticleEffectEdit();
end

function EditParticleEffectActiveTime(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.activeTime = ToFloat(element.text);
    particleEffectEmitter.Reset();

    EndParticleEffectEdit();
end

function EditParticleEffectInactiveTime(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.inactiveTime = ToFloat(element.text);
    particleEffectEmitter.Reset();

    EndParticleEffectEdit();
end

function EditParticleEffectParticleSize(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minParticleSize;
    local vMax = editParticleEffect.maxParticleSize;

    if (element.name == "ParticleSizeMinX") then
        editParticleEffect.minParticleSize = Vector2(ToFloat(element.text), vMin.y);
	end

    if (element.name == "ParticleSizeMinY") then
        editParticleEffect.minParticleSize = Vector2(vMin.x, ToFloat(element.text));
	end

    if (element.name == "ParticleSizeMaxX") then
        editParticleEffect.maxParticleSize = Vector2(ToFloat(element.text), vMax.y);
	end

    if (element.name == "ParticleSizeMaxY") then
        editParticleEffect.maxParticleSize = Vector2(vMax.x, ToFloat(element.text));
	end

    EndParticleEffectEdit();
end

function EditParticleEffectTimeToLive(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minTimeToLive;
    local vMax = editParticleEffect.maxTimeToLive;

    if (element.name == "TimeToLiveMin") then
        editParticleEffect.minTimeToLive = ToFloat(element.text);
	end

    if (element.name == "TimeToLiveMax") then
        editParticleEffect.maxTimeToLive = ToFloat(element.text);
	end

    EndParticleEffectEdit();
end

function EditParticleEffectVelocity(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minVelocity;
    local vMax = editParticleEffect.maxVelocity;

    if (element.name == "VelocityMin") then
        editParticleEffect.minVelocity = ToFloat(element.text);
	end

    if (element.name == "VelocityMax") then
        editParticleEffect.maxVelocity = ToFloat(element.text);
	end

    EndParticleEffectEdit();
end

function EditParticleEffectRotation(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minRotation;
    local vMax = editParticleEffect.maxRotation;

    if (element.name == "RotationMin") then
        editParticleEffect.minRotation = ToFloat(element.text);
	end

    if (element.name == "RotationMax") then
        editParticleEffect.maxRotation = ToFloat(element.text);
	end

    EndParticleEffectEdit();
end

function EditParticleEffectRotationSpeed(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local vMin = editParticleEffect.minRotationSpeed;
    local vMax = editParticleEffect.maxRotationSpeed;

    if (element.name == "RotationSpeedMin") then
        editParticleEffect.minRotationSpeed = ToFloat(element.text);
	end

    if (element.name == "RotationSpeedMax") then
        editParticleEffect.maxRotationSpeed = ToFloat(element.text);
	end

    EndParticleEffectEdit();
end

function EditParticleEffectSizeAdd(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.sizeAdd = ToFloat(element.text);

    EndParticleEffectEdit();
end

function EditParticleEffectSizeMultiply(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.sizeMul = ToFloat(element.text);

    EndParticleEffectEdit();
end

function EditParticleEffectAnimationLodBias(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.animationLodBias = ToFloat(element.text);

    EndParticleEffectEdit();
end

function EditParticleEffectNumParticles(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.numParticles = ToInt(element.text);
	particleEffectEmitter:ApplyEffect();

    EndParticleEffectEdit();
end

function EditParticleEffectEmitterSize(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    local v = editParticleEffect.emitterSize;

    if (element.name == "EmitterSizeX") then
        editParticleEffect.emitterSize = Vector3(ToFloat(element.text), v.y, v.z);
	end

    if (element.name == "EmitterSizeY") then
        editParticleEffect.emitterSize = Vector3(v.x, ToFloat(element.text), v.z);
	end

    if (element.name == "EmitterSizeZ") then
        editParticleEffect.emitterSize = Vector3(v.x, v.y, ToFloat(element.text));
	end

    EndParticleEffectEdit();
end

function EditParticleEffectEmissionRate(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    if (element.name == "EmissionRateMin") then
        editParticleEffect.minEmissionRate = ToFloat(element.text);
	end

    if (element.name == "EmissionRateMax") then
        editParticleEffect.maxEmissionRate = ToFloat(element.text);
	end

    EndParticleEffectEdit();
end

function EditParticleEffectEmitterShape(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

	local el = element.selection;
	if (el == 0) then
		editParticleEffect.emitterType = EMITTER_BOX;
	elseif (el == 1) then
		editParticleEffect.emitterType = EMITTER_SPHERE;
	end
    
    EndParticleEffectEdit();
end

function EditParticleEffectMaterial(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    local element = eventData["Element"]:GetPtr();
    local res = cache:GetResource("Material", element.text);

    if (res ~= nil) then
        BeginParticleEffectEdit();

        editParticleEffect.material = res;
		particleEffectEmitter:ApplyEffect();
        
        EndParticleEffectEdit();
	end 
end

function PickEditParticleEffectMaterial(eventType, eventData)
    resourcePicker = GetResourcePicker(StringHash("Material"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditParticleEffectMaterialDone");
end

function PickEditParticleEffectMaterialDone(eventType, eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end

    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);

    if (res ~= nil and editParticleEffect ~= nil and particleEffectEmitter ~= nil) then
        editParticleEffect.material = res;
		particleEffectEmitter:ApplyEffect();
        RefreshParticleEffectMaterial();
	end

    resourcePicker = nil;
end

function EditParticleEffectScaled(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.scaled = element.checked;
	particleEffectEmitter:ApplyEffect();

    EndParticleEffectEdit();
end

function EditParticleEffectSorted(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.sorted = element.checked;
	particleEffectEmitter:ApplyEffect();

    EndParticleEffectEdit();
end

function EditParticleEffectRelative(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();

    editParticleEffect.relative = element.checked;
	particleEffectEmitter:ApplyEffect();

    EndParticleEffectEdit();
end

function ShowParticleEffectEditor()
    RefreshParticleEffectEditor();
    particleEffectWindow.visible = true;
	particleEffectWindow:BringToFront();
    return true;
end

function HideParticleEffectEditor()
    if (particleEffectWindow ~= nil) then
        particleEffectWindow.visible = false;
	end
end

function InitParticleEffectPreview()
    particlePreviewScene = Scene("particlePreviewScene");
	particlePreviewScene:CreateComponent("Octree");

    local zoneNode = particlePreviewScene:CreateChild("Zone");
    local zone = zoneNode:CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000, 1000);
    zone.ambientColor = Color(0.15, 0.15, 0.15);
    zone.fogColor = Color(0, 0, 0);
    zone.fogStart = 10.0;
    zone.fogEnd = 100.0;

    particlePreviewCameraNode = particlePreviewScene:CreateChild("PreviewCamera");
    particlePreviewCameraNode.position = Vector3(0, 0, -2.5);
    local camera = particlePreviewCameraNode:CreateComponent("Camera");
    camera.nearClip = 0.1;
    camera.farClip = 100.0;

    particlePreviewLightNode = particlePreviewScene:CreateChild("particlePreviewLight");
    particlePreviewLightNode.direction = Vector3(0.5, -0.5, 0.5);
    particlePreviewLight = particlePreviewLightNode:CreateComponent("Light");
    particlePreviewLight.lightType = LIGHT_DIRECTIONAL;
    particlePreviewLight.specularIntensity = 0.5;

    particleEffectPreviewNode = particlePreviewScene:CreateChild("PreviewEmitter");
    particleEffectPreviewNode.rotation = Quaternion(0, 0, 0);
    local gizmo = particleEffectPreviewNode:CreateComponent("StaticModel");
    gizmo.model = cache:GetResource("Model", "Models/Editor/Axes.mdl");
    gizmo.materials[0] = cache:GetResource("Material", "Materials/Editor/RedUnlit.xml");
    gizmo.materials[1] = cache:GetResource("Material", "Materials/Editor/GreenUnlit.xml");
    gizmo.materials[2] = cache:GetResource("Material", "Materials/Editor/BlueUnlit.xml");
    gizmo.occludee = false;

    particleEffectEmitter = particleEffectPreviewNode:CreateComponent("ParticleEmitter");
    editParticleEffect = CreateNewParticleEffect();
    particleEffectEmitter.effect = editParticleEffect;

    particleEffectPreview = particleEffectWindow:GetChild("ParticleEffectPreview", true);
	particleEffectPreview:SetFixedHeight(100);
	particleEffectPreview:SetView(particlePreviewScene, camera);

    SubscribeToEvent(particleEffectPreview, "DragMove", "RotateParticleEffectPreview");
end

function CreateNewParticleEffect()
    local effect = ParticleEffect();
    local res = cache:GetResource("Material", "Materials/Particle.xml");
    if (res == nil) then
        log:Error("Could not load default material for new particle effect.");
	end
    effect.material = res;
	effect:AddColorTime(Color(1,1,1,1), 0.0);
    return effect;
end

function EditParticleEffect(effect)
    if (effect == nil) then
        return;
	end

    if (editParticleEffect ~= nil) then
        UnsubscribeFromEvent(editParticleEffect, "ReloadFinished");
	end

    if (not empty(effect.name)) then
        cache:ReloadResource(effect);
	end
        
    editParticleEffect = effect;
    particleEffectEmitter.effect = editParticleEffect;

    if (editParticleEffect ~= nil) then
        SubscribeToEvent(editParticleEffect, "ReloadFinished", "RefreshParticleEffectEditor");
	end

    ShowParticleEffectEditor();
end

function RefreshParticleEffectEditor()
    inParticleEffectRefresh = true;

    RefreshParticleEffectPreview();
    RefreshParticleEffectName();
    RefreshParticleEffectBasicAttributes();
    RefreshParticleEffectMaterial();
    RefreshParticleEffectColorFrames();
    RefreshParticleEffectTextureFrames();

    inParticleEffectRefresh = false;
end

function RefreshParticleEffectColorFrames()
    if (editParticleEffect == nil) then
        return;
	end

    editParticleEffect:SortColorFrames();

    local lv = particleEffectWindow:GetChild("ColorFrameListView", true);
    if (lv == nil) then
        return;
	end
        
    lv:RemoveAllItems();

	for i = 0, editParticleEffect.numColorFrames - 1 do
        local colorFrame = editParticleEffect:GetColorFrame(i);

        local container = Button:new();
		lv:AddItem(container);
        container.style = "Button";
        container.imageRect = IntRect(18, 2, 30, 14);
        container.minSize = IntVector2(0, 20);
        container.maxSize = IntVector2(2147483647, 20);
        container.layoutMode = LM_HORIZONTAL;
        container.layoutBorder = IntRect(3,1,3,1);
        container.layoutSpacing = 4;

        local labelContainer = UIElement:new();
		container:AddChild(labelContainer);
        labelContainer.style = "HorizontalPanel";
        labelContainer.minSize = IntVector2(0, 16);
        labelContainer.maxSize = IntVector2(2147483647, 16);
        labelContainer.verticalAlignment = VA_CENTER;

        do
            local le = LineEdit();
			labelContainer:AddChild(le);
            le.name = "ColorTime";
            le:SetVar("ColorFrame", Variant(i));
            le.style = "LineEdit";
            le.minSize = IntVector2(0, 16);
            le.maxSize = IntVector2(40, 16);
            le.text = colorFrame.time;
            le.cursorPosition = 0;
            CreateDragSlider(le);

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame");
		end

        local textContainer = UIElement:new();
		labelContainer:AddChild(textContainer);
        textContainer.minSize = IntVector2(0, 16);
        textContainer.maxSize = IntVector2(2147483647, 16);
        textContainer.verticalAlignment = VA_CENTER;

        local t = Text:new();
		textContainer:AddChild(t);
        t.style = "Text";
        t.text = "Color";

        local editContainer = UIElement:new();
		container:AddChild(editContainer);
        editContainer.style = "HorizontalPanel";
        editContainer.minSize = IntVector2(0, 16);
        editContainer.maxSize = IntVector2(2147483647, 16);
        editContainer.verticalAlignment = VA_CENTER;

        do
            local le = LineEdit();
			editContainer:AddChild(le);
            le.name = "ColorR";
            le:SetVar("ColorFrame", Variant(i));
            le.style = "LineEdit";
            le.text = colorFrame.color.r;
            le.cursorPosition = 0;
            CreateDragSlider(le);

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame");
		end
        do
            local le = LineEdit();
			editContainer:AddChild(le);
            le.name = "ColorG";
            le:SetVar("ColorFrame", Variant(i));
            le.style = "LineEdit";
            le.text = colorFrame.color.g;
            le.cursorPosition = 0;
            CreateDragSlider(le);

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame");
		end
        do
            local le = LineEdit();
			editContainer:AddChild(le);
            le.name = "ColorB";
            le:SetVar("ColorFrame", Variant(i));
            le.style = "LineEdit";
            le.text = colorFrame.color.b;
            le.cursorPosition = 0;
            CreateDragSlider(le);

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame");
		end
        do
            local le = LineEdit();
			editContainer:AddChild(le);
            le.name = "ColorA";
            le:SetVar("ColorFrame", Variant(i));
            le.style = "LineEdit";
            le.text = colorFrame.color.a;
            le.cursorPosition = 0;
            CreateDragSlider(le);

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame");
		end

	end
end

function RefreshParticleEffectTextureFrames()
    if (editParticleEffect == nil) then
        return;
	end

    editParticleEffect:SortTextureFrames();

    local lv = particleEffectWindow:GetChild("TextureFrameListView", true);
    if (lv == nil) then
        return;
	end

    lv:RemoveAllItems();

	for i = 0, editParticleEffect.numTextureFrames - 1 do
        local textureFrame = editParticleEffect:GetTextureFrame(i);
        if (textureFrame ~= nil) then

            local container = Button:new();
    		lv:AddItem(container);
            container.style = "Button";
            container.imageRect = IntRect(18, 2, 30, 14);
            container.minSize = IntVector2(0, 20);
            container.maxSize = IntVector2(2147483647, 20);
            container.layoutMode = LM_HORIZONTAL;
            container.layoutBorder = IntRect(1,1,1,1);
            container.layoutSpacing = 4;

            local labelContainer = UIElement:new();
    		container:AddChild(labelContainer);
            labelContainer.style = "HorizontalPanel";
            labelContainer.minSize = IntVector2(0, 16);
            labelContainer.maxSize = IntVector2(2147483647, 16);
            labelContainer.verticalAlignment = VA_CENTER;

            do
                local le = LineEdit();
    			labelContainer:AddChild(le);
                le.name = "TextureTime";
                le:SetVar("TextureFrame", Variant(i));
                le.style = "LineEdit";
                le.minSize = IntVector2(0, 16);
                le.maxSize = IntVector2(40, 16);
                le.text = textureFrame.time;
                le.cursorPosition = 0;
                CreateDragSlider(le);

                SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame");
    		end

            local textContainer = UIElement:new();
    		labelContainer:AddChild(textContainer);
            textContainer.minSize = IntVector2(0, 16);
            textContainer.maxSize = IntVector2(2147483647, 16);
            textContainer.verticalAlignment = VA_CENTER;

            local t = Text:new();
    		textContainer:AddChild(t);
            t.style = "Text";
            t.text = "Texture";

            local editContainer = UIElement:new();
    		container:AddChild(editContainer);
            editContainer.style = "HorizontalPanel";
            editContainer.minSize = IntVector2(0, 16);
            editContainer.maxSize = IntVector2(2147483647, 16);
            editContainer.verticalAlignment = VA_CENTER;

            do
                local le = LineEdit:new();
    			editContainer:AddChild(le);
                le.name = "TextureMinX";
                le:SetVar("TextureFrame", Variant(i));
                le.style = "LineEdit";
                le.text = textureFrame.uv.min.x;
                le.cursorPosition = 0;
                CreateDragSlider(le);

                SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame");
    		end
            do
                local le = LineEdit:new();
    			editContainer:AddChild(le);
                le.name = "TextureMinY";
                le:SetVar("TextureFrame", Variant(i));
                le.style = "LineEdit";
                le.text = textureFrame.uv.min.y;
                le.cursorPosition = 0;
                CreateDragSlider(le);

                SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame");
    		end
            do
                local le = LineEdit:new();
    			editContainer:AddChild(le);
                le.name = "TextureMaxX";
                le:SetVar("TextureFrame", Variant(i));
                le.style = "LineEdit";
                le.text = textureFrame.uv.max.x;
                le.cursorPosition = 0;
                CreateDragSlider(le);

                SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame");
    		end
            do
                local le = LineEdit:new();
    			editContainer:AddChild(le);
                le.name = "TextureMaxY";
                le:SetVar("TextureFrame", Variant(i));
                le.style = "LineEdit";
                le.text = textureFrame.uv.max.y;
                le.cursorPosition = 0;
                CreateDragSlider(le);

                SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame");
    		end
        end
	end
end

function EditParticleEffectColorFrame(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();
    local i = element:GetVars():GetInt("ColorFrame");
    local cf = editParticleEffect:GetColorFrame(i);

    if (element.name == "ColorTime") then
        cf.time = ToFloat(element.text);
	end

    if (element.name == "ColorR") then
        cf.color = Color(ToFloat(element.text), cf.color.g, cf.color.b, cf.color.a);
	end

    if (element.name == "ColorG") then
        cf.color = Color(cf.color.r, ToFloat(element.text), cf.color.b, cf.color.a);
	end

    if (element.name == "ColorB") then
        cf.color = Color(cf.color.r, cf.color.g, ToFloat(element.text), cf.color.a);
	end

    if (element.name == "ColorA") then
        cf.color = Color(cf.color.r, cf.color.g, cf.color.b, ToFloat(element.text));
	end

    editParticleEffect:SetColorFrame(i, cf);
	particleEffectEmitter:Reset();

    EndParticleEffectEdit();
end

function EditParticleEffectTextureFrame(eventType, eventData)
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect == nil) then
        return;
	end

    if (particleEffectEmitter == nil) then
        return;
	end

    BeginParticleEffectEdit();

    local element = eventData["Element"]:GetPtr();
    local i = element:GetVars():GetInt("TextureFrame");
    local tf = editParticleEffect:GetTextureFrame(i);

    if (element.name == "TextureTime") then
        tf.time = ToFloat(element.text);
	end

    if (element.name == "TextureMinX") then
        tf.uv = Rect(ToFloat(element.text), tf.uv.min.y, tf.uv.max.x, tf.uv.max.y);
	end

    if (element.name == "TextureMinY") then
        tf.uv = Rect(tf.uv.min.x, ToFloat(element.text), tf.uv.max.x, tf.uv.max.y);
	end

    if (element.name == "TextureMaxX") then
        tf.uv = Rect(tf.uv.min.x, tf.uv.min.y, ToFloat(element.text), tf.uv.max.y);
	end

    if (element.name == "TextureMaxY") then
        tf.uv = Rect(tf.uv.min.x, tf.uv.min.y, tf.uv.max.x, ToFloat(element.text));
	end

    editParticleEffect:SetTextureFrame(i, tf);
    particleEffectEmitter.Reset();

    EndParticleEffectEdit();
end

function RefreshParticleEffectPreview()
    if (particleEffectEmitter == nil or editParticleEffect == nil) then
        return;
	end
    particleEffectEmitter.effect = editParticleEffect;
	particleEffectEmitter:Reset();
	particleEffectPreview:QueueUpdate();
end

function RefreshParticleEffectName()
    local container = particleEffectWindow:GetChild("NameContainer", true);
    if (container == nil) then
        return;
	end
        
    container:RemoveAllChildren();

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0);
    if (editParticleEffect ~= nil) then
        nameEdit.text = editParticleEffect.name;
	end
    SubscribeToEvent(nameEdit, "TextFinished", "EditParticleEffectName");

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "Pick");
    SubscribeToEvent(pickButton, "Released", "PickEditParticleEffect");
end

function RefreshParticleEffectBasicAttributes()
    if (editParticleEffect == nil) then
        return;
	end

    tolua.cast(particleEffectWindow:GetChild("ConstantForceX", true), "LineEdit").text = editParticleEffect.constantForce.x;
    tolua.cast(particleEffectWindow:GetChild("ConstantForceY", true), "LineEdit").text = editParticleEffect.constantForce.y;
    tolua.cast(particleEffectWindow:GetChild("ConstantForceZ", true), "LineEdit").text = editParticleEffect.constantForce.z;

    tolua.cast(particleEffectWindow:GetChild("DirectionMinX", true), "LineEdit").text = editParticleEffect.minDirection.x;
    tolua.cast(particleEffectWindow:GetChild("DirectionMinY", true), "LineEdit").text = editParticleEffect.minDirection.y;
    tolua.cast(particleEffectWindow:GetChild("DirectionMinZ", true), "LineEdit").text = editParticleEffect.minDirection.z;

    tolua.cast(particleEffectWindow:GetChild("DirectionMaxX", true), "LineEdit").text = editParticleEffect.maxDirection.x;
    tolua.cast(particleEffectWindow:GetChild("DirectionMaxY", true), "LineEdit").text = editParticleEffect.maxDirection.y;
    tolua.cast(particleEffectWindow:GetChild("DirectionMaxZ", true), "LineEdit").text = editParticleEffect.maxDirection.z;

    tolua.cast(particleEffectWindow:GetChild("DampingForce", true), "LineEdit").text = editParticleEffect.dampingForce;
    tolua.cast(particleEffectWindow:GetChild("ActiveTime", true), "LineEdit").text = editParticleEffect.activeTime;
    tolua.cast(particleEffectWindow:GetChild("InactiveTime", true), "LineEdit").text = editParticleEffect.inactiveTime;

    tolua.cast(particleEffectWindow:GetChild("ParticleSizeMinX", true), "LineEdit").text = editParticleEffect.minParticleSize.x;
    tolua.cast(particleEffectWindow:GetChild("ParticleSizeMinY", true), "LineEdit").text = editParticleEffect.minParticleSize.y;

    tolua.cast(particleEffectWindow:GetChild("ParticleSizeMaxX", true), "LineEdit").text = editParticleEffect.maxParticleSize.x;
    tolua.cast(particleEffectWindow:GetChild("ParticleSizeMaxY", true), "LineEdit").text = editParticleEffect.maxParticleSize.y;

    tolua.cast(particleEffectWindow:GetChild("TimeToLiveMin", true), "LineEdit").text = editParticleEffect.minTimeToLive;
    tolua.cast(particleEffectWindow:GetChild("TimeToLiveMax", true), "LineEdit").text = editParticleEffect.maxTimeToLive;

    tolua.cast(particleEffectWindow:GetChild("VelocityMin", true), "LineEdit").text = editParticleEffect.minVelocity;
    tolua.cast(particleEffectWindow:GetChild("VelocityMax", true), "LineEdit").text = editParticleEffect.maxVelocity;

    tolua.cast(particleEffectWindow:GetChild("RotationMin", true), "LineEdit").text = editParticleEffect.minRotation;
    tolua.cast(particleEffectWindow:GetChild("RotationMax", true), "LineEdit").text = editParticleEffect.maxRotation;

    tolua.cast(particleEffectWindow:GetChild("RotationSpeedMin", true), "LineEdit").text = editParticleEffect.minRotationSpeed;
    tolua.cast(particleEffectWindow:GetChild("RotationSpeedMax", true), "LineEdit").text = editParticleEffect.maxRotationSpeed;

    tolua.cast(particleEffectWindow:GetChild("SizeAdd", true), "LineEdit").text = editParticleEffect.sizeAdd;
    tolua.cast(particleEffectWindow:GetChild("SizeMultiply", true), "LineEdit").text = editParticleEffect.sizeMul;
    tolua.cast(particleEffectWindow:GetChild("AnimationLodBias", true), "LineEdit").text = editParticleEffect.animationLodBias;

    tolua.cast(particleEffectWindow:GetChild("NumParticles", true), "LineEdit").text = editParticleEffect.numParticles;

    tolua.cast(particleEffectWindow:GetChild("EmitterSizeX", true), "LineEdit").text = editParticleEffect.emitterSize.x;
    tolua.cast(particleEffectWindow:GetChild("EmitterSizeY", true), "LineEdit").text = editParticleEffect.emitterSize.y;
    tolua.cast(particleEffectWindow:GetChild("EmitterSizeZ", true), "LineEdit").text = editParticleEffect.emitterSize.z;

    tolua.cast(particleEffectWindow:GetChild("EmissionRateMin", true), "LineEdit").text = editParticleEffect.minEmissionRate;
    tolua.cast(particleEffectWindow:GetChild("EmissionRateMax", true), "LineEdit").text = editParticleEffect.maxEmissionRate;

	local tp = editParticleEffect.emitterType;
	if (tp == EMITTER_BOX) then
            tolua.cast(particleEffectWindow:GetChild("EmitterShape", true), "DropDownList").selection = 0;
    elseif (tp == EMITTER_SPHERE) then
            tolua.cast(particleEffectWindow:GetChild("EmitterShape", true), "DropDownList").selection = 1;
	end

    tolua.cast(particleEffectWindow:GetChild("Scaled", true), "CheckBox").checked = editParticleEffect.scaled;
    tolua.cast(particleEffectWindow:GetChild("Sorted", true), "CheckBox").checked = editParticleEffect.sorted;
    tolua.cast(particleEffectWindow:GetChild("Relative", true), "CheckBox").checked = editParticleEffect.relative;
end

function RefreshParticleEffectMaterial()
    local container = particleEffectWindow:GetChild("ParticleMaterialContainer", true);
    if (container == nil) then
        return;
	end
        
    container:RemoveAllChildren();

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0);
    if (editParticleEffect ~= nil) then
        if (editParticleEffect.material ~= nil) then
            nameEdit.text = editParticleEffect.material.name;
        else
            nameEdit.text = "Materials/Particle.xml";
            local res = cache:GetResource("Material", "Materials/Particle.xml");
            if (res ~= nil) then
                editParticleEffect.material = res;
			end 
		end
    end 

    SubscribeToEvent(nameEdit, "TextFinished", "EditParticleEffectMaterial");

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "Pick");
    SubscribeToEvent(pickButton, "Released", "PickEditParticleEffectMaterial");
end

function RotateParticleEffectPreview(eventType, eventData)
    local elemX = eventData["ElementX"]:GetInt();
    local elemY = eventData["ElementY"]:GetInt();
    
    if (particleEffectPreview.height > 0 and particleEffectPreview.width > 0) then
        local yaw = ((particleEffectPreview.height / 2) - elemY) * (90.0 / particleEffectPreview.height);
        local pitch = ((particleEffectPreview.width / 2) - elemX) * (90.0 / particleEffectPreview.width);

        particleEffectPreviewNode.rotation = particleEffectPreviewNode.rotation:Slerp(Quaternion(yaw, pitch, 0), 0.1);
		particleEffectPreview:QueueUpdate();
	end 
end

function EditParticleEffectName(eventType, eventData)
    local nameEdit = eventData["Element"]:GetPtr();
    local newParticleEffectName = Trimmed(nameEdit.text);
    if (not empty(newParticleEffectName) and not (editParticleEffect ~= nil and newParticleEffectName == editParticleEffect.name)) then
        local newParticleEffect = cache:GetResource("ParticleEffect", newParticleEffectName);
        if (newParticleEffect ~= nil) then
            EditParticleEffect(newParticleEffect);
		end
	end
end

function PickEditParticleEffect()
    resourcePicker = GetResourcePicker(StringHash("ParticleEffect"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditParticleEffectDone");
end

function PickEditParticleEffectDone(eventType, eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
    end

    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);

    if (res ~= nil) then
        EditParticleEffect(tolua.cast(res, "ParticleEffect"));
	end

    resourcePicker = nil;
end

function NewParticleEffect()
    BeginParticleEffectEdit();

    EditParticleEffect(CreateNewParticleEffect());
    
    EndParticleEffectEdit();
end

function RevertParticleEffect()
    if (inParticleEffectRefresh) then
        return;
	end

    if (editParticleEffect ~= nil) then
        return;
	end

    if (empty(editParticleEffect.name)) then
        NewParticleEffect();
        return;
	end

    BeginParticleEffectEdit();
    
	cache:ReloadResource(editParticleEffect);

    EndParticleEffectEdit();
    
    RefreshParticleEffectEditor();
end

function SaveParticleEffect()
    if (editParticleEffect == nil or empty(editParticleEffect.name)) then
        return;
	end

    local fullName = cache:GetResourceFileName(editParticleEffect.name);
    if (empty(fullName)) then
        return;
	end

    local saveFile = File(fullName, FILE_WRITE);
	editParticleEffect:Save(saveFile);
end

function SaveParticleEffectAs()
    if (editParticleEffect == nil) then
        return;
	end

    resourcePicker = GetResourcePicker(StringHash("ParticleEffect"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Save particle effect as", "Save", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "SaveParticleEffectAsDone");
end

function SaveParticleEffectAsDone(eventType, eventData)
    StoreResourcePickerPath();
    CloseFileSelector();
    resourcePicker = nil;

    if (editParticleEffect == nil) then
        return;
	end

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end

    local fullName = eventData["FileName"]:GetString();

    -- Add default extension for saving if not specified
    local filter = eventData["Filter"]:GetString();
    if (empty(GetExtension(fullName)) and filter ~= "*.*") then
        fullName = fullName .. Substring(filter,1);
	end

    local saveFile = File:new(fullName, FILE_WRITE);
    if (editParticleEffect:Save(saveFile)) then
		saveFile:Close();

        -- Load the new resource to update the name in the editor
        local newEffect = cache:GetResource("ParticleEffect", GetResourceNameFromFullName(fullName));
        if (newEffect ~= nil) then
            EditParticleEffect(newEffect);
		end
   end 
end

function BeginParticleEffectEdit()
    if (editParticleEffect == nil) then
        return;
	end

    inParticleEffectRefresh = true;

    oldParticleEffectState = XMLFile:new();
    local particleElem = oldParticleEffectState:CreateRoot("particleeffect");
	editParticleEffect:Save(particleElem);
end

function EndParticleEffectEdit()
    if (editParticleEffect == nil) then
        return;
	end

    if (not dragEditAttribute) then
        local action = EditParticleEffectAction:new();
		action:Define(particleEffectEmitter, editParticleEffect, oldParticleEffectState);
        SaveEditAction(action);
    end 

    inParticleEffectRefresh = false;
    
	particleEffectPreview:QueueUpdate();
end
