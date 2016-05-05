
randomRotationX = 0;
randomRotationY = 0;
randomRotationZ = 0;
randomScaleMinEdit = 0;
randomScaleMaxEdit = 0;
numberSpawnedObjectsEdit = 0;
spawnRadiusEdit = 0;
spawnCountEdit = 0;

spawnWindow = nil;
randomRotation = Vector3(0, 0, 0);
randomScaleMin = 1;
randomScaleMax = 1;
spawnCount = 1;
spawnRadius = 0;
useNormal = true;
alignToAABBBottom = true;

numberSpawnedObjects = 1;
spawnedObjectsNames = {};


function CreateSpawnEditor()
    if (spawnWindow ~= nil) then
        return;
	end

    spawnWindow = LoadEditorUI("UI/EditorSpawnWindow.xml");
    ui.root:AddChild(spawnWindow);
    spawnWindow.opacity = uiMaxOpacity;

    local height = Min(ui.root.height - 60, 500);
	spawnWindow:SetSize(300, height);
    CenterDialog(spawnWindow);

    HideSpawnEditor();
    SubscribeToEvent(spawnWindow:GetChild("CloseButton", true), "Released", "HideSpawnEditor");
    randomRotationX = spawnWindow:GetChild("RandomRotation.x", true);
    randomRotationY = spawnWindow:GetChild("RandomRotation.y", true);
    randomRotationZ = spawnWindow:GetChild("RandomRotation.z", true);
    randomRotationX.text = (randomRotation.x) .. "";
    randomRotationY.text = (randomRotation.y) .. "";
    randomRotationZ.text = (randomRotation.z) .. "";
    
    randomScaleMinEdit = spawnWindow:GetChild("RandomScaleMin", true);
    randomScaleMaxEdit = spawnWindow:GetChild("RandomScaleMax", true);
    randomScaleMinEdit.text = (randomScaleMin) .. "";
    randomScaleMaxEdit.text = (randomScaleMax) .. "";
    local useNormalToggle = spawnWindow:GetChild("UseNormal", true);
    useNormalToggle.checked = useNormal;
    local alignToAABBBottomToggle = spawnWindow:GetChild("AlignToAABBBottom", true);
    alignToAABBBottomToggle.checked = alignToAABBBottom;

    numberSpawnedObjectsEdit = spawnWindow:GetChild("NumberSpawnedObjects", true);
    numberSpawnedObjectsEdit.text = (numberSpawnedObjects) .. "";

    spawnRadiusEdit = spawnWindow:GetChild("SpawnRadius", true);
    spawnCountEdit = spawnWindow;GetChild("SpawnCount", true);
    spawnRadiusEdit.text = (spawnRadius) .. "";
    spawnCountEdit.text = (spawnCount) .. "";

    SubscribeToEvent(randomRotationX, "TextChanged", "EditRandomRotation");
    SubscribeToEvent(randomRotationY, "TextChanged", "EditRandomRotation");
    SubscribeToEvent(randomRotationZ, "TextChanged", "EditRandomRotation");
    SubscribeToEvent(randomScaleMinEdit, "TextChanged", "EditRandomScale");
    SubscribeToEvent(randomScaleMaxEdit, "TextChanged", "EditRandomScale");
    SubscribeToEvent(spawnRadiusEdit, "TextChanged", "EditSpawnRadius");
    SubscribeToEvent(spawnCountEdit, "TextChanged", "EditSpawnCount");
    SubscribeToEvent(useNormalToggle, "Toggled", "ToggleUseNormal");
    SubscribeToEvent(alignToAABBBottomToggle, "Toggled", "ToggleAlignToAABBBottom");
    SubscribeToEvent(numberSpawnedObjectsEdit, "TextFinished", "UpdateNumberSpawnedObjects");
    SubscribeToEvent(spawnWindow:GetChild("SetSpawnMode", true), "Released", "SetSpawnMode");
    RefreshPickedObjects();
end


function ShowSpawnEditor()
    spawnWindow.visible = true;
    spawnWindow:BringToFront();
    return true;
end

function HideSpawnEditor()
    spawnWindow.visible = false;
end

function PickSpawnObject()
    resourcePicker = GetResourcePicker(StringHash("Node"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickSpawnObjectDone");
end

function EditRandomRotation(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    randomRotation = Vector3(ToFloat(randomRotationX.text), ToFloat(randomRotationY.text), ToFloat(randomRotationZ.text));
    UpdateHierarchyItem(editorScene);
end

function EditRandomScale(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    randomScaleMin = ToFloat(randomScaleMinEdit.text);
    randomScaleMax = ToFloat(randomScaleMaxEdit.text);
    UpdateHierarchyItem(editorScene);
end

function ToggleUseNormal(eventType, eventData)
    useNormal = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
end

function ToggleAlignToAABBBottom(eventType, eventData)
    alignToAABBBottom = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
end

function UpdateNumberSpawnedObjects(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    numberSpawnedObjects = ToUInt(edit.text);
    edit.text = String(numberSpawnedObjects);
    RefreshPickedObjects();
end

function EditSpawnRadius(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    spawnRadius = ToFloat(edit.text);
end

function EditSpawnCount(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    spawnCount = edit.text.ToUInt();
end

function RefreshPickedObjects()
    spawnedObjectsNames:Resize(numberSpawnedObjects);
    local list = spawnWindow:GetChild("SpawnedObjects", true);
	list:RemoveAllItems();
	for i = 1, #numberSpawnedObjects do
        local parent = CreateAttributeEditorParentWithSeparatedLabel(list, "Object " +(i+1), i, 0, false);
        
        local container = UIElement:new();
		container:SetLayout(LM_HORIZONTAL, 4, IntRect(10, 0, 4, 0));
		container:SetFixedHeight(ATTR_HEIGHT);
		parent:AddChild(container);

        local nameEdit = CreateAttributeLineEdit(container, nil, i, 0);
        nameEdit.name = "TextureNameEdit" .. i;

        local pickButton = CreateResourcePickerButton(container, nil, i, 0, "Pick");
        SubscribeToEvent(pickButton, "Released", "PickSpawnedObject");
        nameEdit.text = spawnedObjectsNames[i];

        SubscribeToEvent(nameEdit, "TextFinished", "EditSpawnedObjectName");
	end
end

function EditSpawnedObjectName(eventType, eventData)
    local nameEdit = eventData["Element"]:GetPtr();
    local index = nameEdit:GetUInt("Index");
    local resourceName = VerifySpawnedObjectFile(nameEdit.text);
    nameEdit.text = resourceName;
    spawnedObjectsNames[index] = resourceName;
end

function VerifySpawnedObjectFile(resourceName)
    local file = cache:GetFile(resourceName);
    if(file ~= nil) then
        return resourceName;
    else
        return '';
	end
end

function PickSpawnedObject(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    resourcePickIndex = button:GetUInt("Index");
    CreateFileSelector("Pick spawned object", "Pick", "Cancel", uiNodePath, uiSceneFilters, uiNodeFilter);
    
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickSpawnedObjectNameDone");
end

function PickSpawnedObjectNameDone(eventType, eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end

    local resourceName = GetResourceNameFromFullName(eventData["FileName"]:GetString());
    spawnedObjectsNames[resourcePickIndex] = VerifySpawnedObjectFile(resourceName);
    resourcePicker = nil;
    RefreshPickedObjects();
end

function SetSpawnMode(eventType, eventData)
    editMode = EDIT_SPAWN;
end

function PlaceObject(spawnPosition, normal)
    local spawnRotation = Quaternion:new();
    if (useNormal) then
        spawnRotation = Quaternion(Vector3(0, 1, 0), normal);
	end

    spawnRotation = Quaternion(Random(-randomRotation.x, randomRotation.x),
        Random(-randomRotation.y, randomRotation.y), Random(-randomRotation.z, randomRotation.z)) * spawnRotation;

    local number = RandomInt(0, spawnedObjectsNames.length);
    local file = cache.GetFile(spawnedObjectsNames[number]);
    local spawnedObject = InstantiateNodeFromFile(file, spawnPosition, spawnRotation, Random(randomScaleMin, randomScaleMax));
    if (spawnedObject == nil) then
        spawnedObjectsNames[number] = spawnedObjectsNames[#spawnedObjectsNames - 1];
        --numberSpawnedObjects;
        RefreshPickedObjects();
        return;
	end
end

function GetSpawnPosition(cameraRay, maxDistance, position, normal, randomRadius, allowNoHit)
	if (randomRadius == nil) then
		randomRadius = 0.0;
	end
	if (allowNoHit == nil) then
		allowNoHit = true;
	end
    if (pickMode < PICK_RIGIDBODIES and editorScene.octree ~= nil) then
        local result = editorScene.octree:RaycastSingle(cameraRay, RAY_TRIANGLE, maxDistance, DRAWABLE_GEOMETRY, 0x7fffffff);
        if (result.drawable ~= nil) then
            if (randomRadius > 0) then
                local basePosition = RandomizeSpawnPosition(result.position, randomRadius);
                basePosition.y = basePosition.y + randomRadius;
                result = editorScene.octree:RaycastSingle(Ray(basePosition, Vector3(0, -1, 0)), RAY_TRIANGLE, randomRadius * 2.0,
                    DRAWABLE_GEOMETRY, 0x7fffffff);

                if (result.drawable ~= nil) then
                    position = result.position;
                    normal = result.normal;
                    return true;
                end
            else
                position = result.position;
                normal = result.normal;
                return true;
			end
		end
    elseif (editorScene.physicsWorld ~= nil) then
        -- If we are not running the actual physics update, refresh collisions before raycasting
        if (not runUpdate) then
            editorScene.physicsWorld:UpdateCollisions();
		end

        local result = editorScene.physicsWorld:RaycastSingle(cameraRay, maxDistance);

        if (result.body ~= nil) then
            if (randomRadius > 0) then
                local basePosition = RandomizeSpawnPosition(result.position, randomRadius);
                basePosition.y = basePosition.y + randomRadius;
                result = editorScene.physicsWorld:RaycastSingle(Ray(basePosition, Vector3(0, -1, 0)), randomRadius * 2.0);
                if (result.body ~= nil) then
                    position = result.position;
                    normal = result.normal;
                    return true;
				end
            else
                position = result.position;
                normal = result.normal;
                return true;
			end
		end
	end

    position = cameraRay.origin + cameraRay.direction * maxDistance;
    normal = Vector3(0, 1, 0);
    return allowNoHit;
end

function RandomizeSpawnPosition(position, randomRadius)
	angle = Random() * 360.0;
    local distance = Random() * randomRadius;
    return position + Quaternion(0, angle, 0) * Vector3(0, 0, distance);
end

function SpawnObject()
    if (spawnedObjectsNames.length == 0) then
        return;
	end
    local view = activeViewport.viewport.rect;

	for i = 1, spawnCount - 1 do
        local cameraRay = GetActiveViewportCameraRay();

        local position, normal;
        if (GetSpawnPosition(cameraRay, camera.farClip, position, normal, spawnRadius, false)) then
            PlaceObject(position, normal);
		end
	end
end


