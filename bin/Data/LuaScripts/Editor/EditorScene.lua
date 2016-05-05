

require "LuaScripts/Editor/EditorInspectorWindow"
--require "LuaScripts/Editor/EditorCubeCapture"

PICK_GEOMETRIES = 0;
PICK_LIGHTS = 1;
PICK_ZONES = 2;
PICK_RIGIDBODIES = 3;
PICK_UI_ELEMENTS = 4;
MAX_PICK_MODES = 5;
MAX_UNDOSTACK_SIZE = 256;

editorScene = nil;

instantiateFileName = '';
instantiateMode = REPLICATED;
sceneModified = false;
runUpdate = false;

selectedNodes = {};
selectedComponents = {};
editNode = nil;
editNodes = {};
editComponents = {};
numEditableComponentsPerNode = 1;

sceneCopyBuffer = {};

suppressSceneChanges = false;
inSelectionModify = false;
skipMruScene = false;

undoStack = {};
undoStackPos = 0;

revertOnPause = false;
revertData = nil;


function ClearSceneSelection()

    selectedNodes = {};
    selectedComponents = {};
    editNode = nil;
    editNodes = {};
    editComponents = {};
    numEditableComponentsPerNode = 1;
    HideGizmo();
end

function CreateScene()
    editorScene = Scene();
    script.defaultScene = editorScene;
    editorScene.updateEnabled = false;
end

function ResetScene()
	ui.cursor.shape = CS_BUSY;

    if (messageBoxCallback == nil and sceneModified) then
        local messageBox = MessageBox("Scene has been modified.\nContinue to reset?", "Warning");
        if (messageBox.window ~= nil) then
            local cancelButton = messageBox.window:GetChild("CancelButton", true);
            cancelButton.visible = true;
            cancelButton.focus = true;
            SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement");
            messageBoxCallback = ResetScene;
            return false;
		end
    else
        messageBoxCallback = nil;
	end
        
    -- Clear stored script attributes
    Clear(scriptAttributes);

    suppressSceneChanges = true;

    -- Create a scene with default values, these will be overridden when loading scenes
    editorScene:Clear();
	editorScene:CreateComponent("Octree");
	editorScene:CreateComponent("DebugRenderer");

    -- Release resources that became unused after the scene clear
    cache:ReleaseAllResources(false);

    sceneModified = false;
    revertData = nil;
    StopSceneUpdate();

    UpdateWindowTitle();
    DisableInspectorLock();
    UpdateHierarchyItem(editorScene, true);
    ClearEditActions();

    suppressSceneChanges = false;

    ResetCamera();
    CreateGizmo();
    CreateGrid();
    SetActiveViewport(viewports[0]);

    return true;
end


function SetResourcePath(newPath, usePreferredDir, additive)
	if (usePreferredDir == nil) then
		usePreferredDir = true;
	end
	if (additive == nil) then
		additive = false;
	end
    if (newPath == nil) then
        return;
    end
    
    if (not IsAbsolutePath(newPath)) then
        newPath = fileSystem.currentDir .. newPath;
    end

    if (usePreferredDir) then
        newPath = AddTrailingSlash(cache:GetPreferredResourceDir(newPath));
    else
        newPath = AddTrailingSlash(newPath);
    end

    if (newPath == sceneResourcePath) then
        return;
    end

    -- Remove the old scene resource path if any. However make sure that the default data paths do not get removed
    if (not additive) then
        cache:ReleaseAllResources(false);
        renderer:ReloadShaders();

        local check = AddTrailingSlash(sceneResourcePath);
        local isDefaultResourcePath = check:Compare(fileSystem.programDir .. "Data/", false) == 0 or
            check:Compare(fileSystem.programDir .. "CoreData/", false) == 0;

        if (not sceneResourcePath.empty and not isDefaultResourcePath) then
            cache:RemoveResourceDir(sceneResourcePath);
        end
    else
        -- If additive (path of a loaded prefab) check that the new path isn't already part of an old path
        local resourceDirs = cache.resourceDirs;
        for i, v in ipairs(resourceDirs) do
            if (newPath:StartsWith(v, false)) then
                return;
            end
        end
    end

    -- Add resource path as first priority so that it takes precedence over the default data paths
    cache:AddResourceDir(newPath, 0);
    RebuildResourceDatabase();

    if (not additive) then
        sceneResourcePath = newPath;
        uiScenePath = GetResourceSubPath(newPath, "Scenes");
        uiElementPath = GetResourceSubPath(newPath, "UI");
        uiNodePath = GetResourceSubPath(newPath, "Objects");
        uiScriptPath = GetResourceSubPath(newPath, "Scripts");
        uiParticlePath = GetResourceSubPath(newPath, "Particle");
    end
end

function GetResourceSubPath(basePath, subPath)
    basePath = AddTrailingSlash(basePath);
    if (fileSystem:DirExists(basePath .. subPath)) then
        return AddTrailingSlash(basePath .. subPath);
    else
        return basePath;
    end
end

function UpdateScene(timeStep)
    if (runUpdate) then
        editorScene:Update(timeStep);
    end
end


--function LoadScene(fileName) end
function LoadScene(fileName)
    if (empty(fileName)) then
        return false;
    end

    ui.cursor.shape = CS_BUSY;

    -- Always load the scene from the filesystem, not from resource paths
    if (not fileSystem:FileExists(fileName)) then
        MessageBox("No such scene.\n" .. fileName);
        return false;
    end

    local file = File:new(fileName, FILE_READ);
    if (not file.open) then
		MessageBox("Could not open file.\n" .. fileName);
		return false;
	end
    
    -- Reset stored script attributes.
    Clear(scriptAttributes);

    -- Add the scene's resource path in case it's necessary
    local newScenePath = GetPath(fileName);
    if (not rememberResourcePath and not sceneResourcePath:StartsWith(newScenePath, false)) then
        SetResourcePath(newScenePath);
    end

    suppressSceneChanges = true;
    sceneModified = false;
    revertData = nil;
    StopSceneUpdate();

    local extension = GetExtension(fileName);
    local loaded;
    if (extension ~= ".xml") then
        loaded = editorScene:Load(fileName);
    else
        loaded = editorScene:LoadXML(fileName);
    end

    -- Release resources which are not used by the new scene
    cache:ReleaseAllResources(false);

    -- Always pause the scene, and do updates manually
    editorScene.updateEnabled = false;

    UpdateWindowTitle();
    DisableInspectorLock();
    UpdateHierarchyItem(editorScene, true);
    ClearEditActions();

    suppressSceneChanges = false;

    -- global variable to mostly bypass adding mru upon importing tempscene
    if (not skipMruScene) then
        UpdateSceneMru(fileName);
    end

    skipMruScene = false;

    ResetCamera();
    CreateGizmo();
    CreateGrid();
    SetActiveViewport(viewports[0]);

    -- Store all ScriptInstance and LuaScriptInstance attributes
    UpdateScriptInstances();

    return loaded;
end

function SaveScene(fileName)
    if (fileName.empty) then
        return false;
    end

    ui.cursor.shape = CS_BUSY;

    -- Unpause when saving so that the scene will work properly when loaded outside the editor
    editorScene.updateEnabled = true;

    MakeBackup(fileName);
    -- File file(fileName, FILE_WRITE);
    local extension = GetExtension(fileName);
    local success = false;
    if (extension ~= ".xml") then
    	success = editorScene:Save(file);
   	else
   		success = editorScene:SaveXML(file);
   	end
    RemoveBackup(success, fileName);

    editorScene.updateEnabled = false;

    if (success) then
        UpdateSceneMru(fileName);
        sceneModified = false;
        UpdateWindowTitle();
    else
        MessageBox("Could not save scene successfully!\nSee Urho3D.log for more detail.");
    end

    return success;
end

function SaveSceneWithExistingName()
    if (empty(editorScene.fileName) or editorScene.fileName == TEMP_SCENE_NAME) then
        return PickFile();
    else
        return SaveScene(editorScene.fileName);
	end
end

function CreateNode(mode)
     newNode = nil;
    if (editNode ~= nil) then
        newNode = editNode:CreateChild("", mode);
    else
        newNode = editorScene:CreateChild("", mode);
	end
    -- Set the new node a certain distance from the camera
    newNode.position = GetNewNodePosition();

    -- Create an undo action for the create
    local action = CreateNodeAction:new();
	action:Define(newNode);
    SaveEditAction(action);
    SetSceneModified();

    FocusNode(newNode);

    return newNode;
end

function SceneResetPosition()
	-- TODO
	return false;
end
function SceneResetRotation()
	-- TODO
	return false;
end
function SceneResetScale()
	-- TODO
	return false;
end
function SceneToggleEnable()
	-- TODO
	return false;
end
function SceneUnparent()
	-- TODO
	return false;
end

function ToggleSceneUpdate()
	-- TODO
	return false;
end

function StopTestAnimation()
	-- TODO
	return false;
end

function SceneRebuildNavigation()
	-- TODO
	return false;
end

function SceneAddChildrenStaticModelGroup()
	-- TODO
	return false;
end

function  CreateNode(mode)
    -- TODO
end

function CreateComponent(componentType)
    -- If this is the root node, do not allow to create duplicate scene-global components
    if (editNode == editorScene and CheckForExistingGlobalComponent(editNode, componentType)) then
        return;
	end

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- For now, make a local node's all components local
    -- todo Allow to specify the createmode
	for i = 1, #editNodes do
        local newComponent = editNodes[i]:CreateComponent(componentType, ifor(editNodes[i].id < FIRST_LOCAL_ID , REPLICATED , LOCAL));
        if (newComponent ~= nil) then
            -- Some components such as CollisionShape do not create their internal object before the first call to ApplyAttributes()
            -- to prevent unnecessary initialization with default values. Call now
            newComponent:ApplyAttributes();

            local action = CreateComponentAction:new();
			action:Define(newComponent);
            Push(group.actions,action);
		end 
	end 

    SaveEditActionGroup(group);
    SetSceneModified();

    -- Although the edit nodes selection are not changed, call to ensure attribute inspector notices new components of the edit nodes
    HandleHierarchyListSelectionChange();
end

function CreateLoadedComponent(component)
    if (component == nil) then return;end 
    local action = CreateComponentAction:new();
	action:Define(component);
    SaveEditAction(action);
    SetSceneModified();
    FocusComponent(component);
end

function CreateLoadedComponent(component)
    if (component == nil) then return;end 
    local action = CreateComponentAction:new();
	action:Define(component);
    SaveEditAction(action);
    SetSceneModified();
    FocusComponent(component);
end

function LoadNode(fileName, parent)
    if (empty(fileName)) then
        return nil;
	end

    if (not fileSystem:FileExists(fileName)) then
        MessageBox("No such node file.\n" .. fileName);
        return nil;
	end

    local file = File(fileName, FILE_READ);
    if (not file.open) then
        MessageBox("Could not open file.\n" .. fileName);
        return nil;
	end

    ui.cursor.shape = CS_BUSY;

    -- Before instantiating, add object's resource path if necessary
    SetResourcePath(GetPath(fileName), true, true);

    local cameraRay = camera:GetScreenRay(0.5, 0.5); -- Get ray at view center
    local position, normal;
    GetSpawnPosition(cameraRay, newNodeDistance, position, normal, 0, true);

    local newNode = InstantiateNodeFromFile(file, position, Quaternion(), 1, parent, instantiateMode);
    if (newNode ~= nil) then
        FocusNode(newNode);
        instantiateFileName = fileName;
	end
    return newNode;
end

function InstantiateNodeFromFile(file, position, rotation, scaleMod, parent, mode)
	if (mode == nil) then
		mode = REPLICATED;
	end

	if (scaleMod == nil) then
		scaleMod = 1.0;
	end
    if (file == nil) then
        return nil;
	end

    local newNode;
    local numSceneComponent = editorScene.numComponents;

    suppressSceneChanges = true;

    local extension = GetExtension(file.name);
    if (extension ~= ".xml") then
        newNode = editorScene:Instantiate(file, position, rotation, mode);
    else
        newNode = editorScene:InstantiateXML(file, position, rotation, mode);
	end

    suppressSceneChanges = false;

    if (parent ~= nil) then
        newNode.parent = parent;
	end
        
    if (newNode ~= nil) then
        newNode.scale = newNode.scale * scaleMod;
        if (alignToAABBBottom) then
            local drawable = GetFirstDrawable(newNode);
            if (drawable ~= nil) then
                local aabb = drawable.worldBoundingBox;
                local aabbBottomCenter = Vector3(aabb.center.x, aabb.min.y, aabb.center.z);
                local offset = aabbBottomCenter - newNode.worldPosition;
                newNode.worldPosition = newNode.worldPosition - offset;
			end
		end

        -- Create an undo action for the load
        local action = CreateNodeAction:new();
		action:Define(newNode);
        SaveEditAction(action);
        SetSceneModified();

        if (numSceneComponent ~= editorScene.numComponents) then
            UpdateHierarchyItem(editorScene);
        else
            UpdateHierarchyItem(newNode);
		end
	end

    return newNode;
end

function SaveNode(fileName)
    if (empty(fileName)) then
        return false;
	end

    ui.cursor.shape = CS_BUSY;

    MakeBackup(fileName);
    local file = File(fileName, FILE_WRITE);
    if (not file.open) then
        MessageBox("Could not open file.\n" .. fileName);
        return false;
	end

    local extension = GetExtension(fileName);
    local success = ifor(extension ~= ".xml", editNode.Save(file),  editNode.SaveXML(file));
    RemoveBackup(success, fileName);

    if (success) then
        instantiateFileName = fileName;
    else
        MessageBox("Could not save node successfully!\nSee Urho3D.log for more detail.");
	end

    return success;
end

function CreateComponent(componentType)
    -- TODO
end

function UpdateScene(timeStep)
    if (runUpdate) then
        editorScene:Update(timeStep);
	end
end

function StopSceneUpdate()
    runUpdate = false;
	audio:Stop();
    toolBarDirty = true;

    -- If scene should revert on update stop, load saved data now
    if (revertOnPause and revertData ~= nil) then
        suppressSceneChanges = true;
        editorScene:Clear();
		editorScene:LoadXML(revertData.GetRoot());
        CreateGrid();
        UpdateHierarchyItem(editorScene, true);
        ClearEditActions();
        suppressSceneChanges = false;
	end

    revertData = nil;
end

function StartSceneUpdate()
    runUpdate = true;
    -- Run audio playback only when scene is updating, so that audio components' time-dependent attributes stay constant when
    -- paused (similar to physics)
    audio:Play();
    toolBarDirty = true;

    -- Save scene data for reverting if enabled
    if (revertOnPause) then
        revertData = XMLFile:new();
        local root = revertData:CreateRoot("scene");
		editorScene:SaveXML(root);
    else
        revertData = nil;
	end
end

function ToggleSceneUpdate()
    if (not runUpdate) then
        StartSceneUpdate();
    else
        StopSceneUpdate();
	end
    return true;
end

function SetSceneModified()
    if (not sceneModified) then
        sceneModified = true;
        UpdateWindowTitle();
	end
end

function SceneDelete()
    ui.cursor.shape = CS_BUSY;

    BeginSelectionModify();

    -- Clear the selection now to prevent repopulation of selectedNodes and selectedComponents combo
    hierarchyList.ClearSelection();

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Remove nodes
	for i = 1, #selectedNodes do
        local node = selectedNodes[i];
        if (node.parent == nil or node.scene == nil) then

		else
			local nodeIndex = GetListIndex(node);

			-- Create undo action
			local action = DeleteNodeAction:new();
			action:Define(node);
			Push(group.actions, action);

			node:Remove();
			SetSceneModified();

			-- If deleting only one node, select the next item in the same index
            if (#selectedNodes == 1 and #selectedComponents) then
                hierarchyList.selection = nodeIndex;
            end
        end
	end

    -- Then remove components, if they still remain
	for i = 1, #selectedComponents do	
        local component = selectedComponents[i];
        local node = component.node;
        if (node ~= nil) then
			local index = GetComponentListIndex(component);
			local nodeIndex = GetListIndex(node);
			if (index ~= NO_ITEM and nodeIndex ~= NO_ITEM) then
				-- Do not allow to remove the Octree, DebugRenderer or MaterialCache2D or DrawableProxy2D from the root node
			    if (node == editorScene and (component.typeName == "Octree" or component.typeName == "DebugRenderer" or 
                    component.typeName == "MaterialCache2D" or component.typeName == "DrawableProxy2D")) then

                    -- Create undo action
                    local action = DeleteComponentAction:new();
                    action:Define(component);
                    Push(group.actions, action);

                    node:RemoveComponent(component);
                    SetSceneModified();

                    -- If deleting only one component, select the next item in the same index
                    if (#selectedComponents == 1 and #selectedNodes == 0) then
                        hierarchyList.selection = index;
                    end
                end
			end
		end
    end

    SaveEditActionGroup(group);

    EndSelectionModify();
    return true;
end

function SceneCut()
    return SceneCopy() and SceneDelete();
end

function SceneCopy()
    ui.cursor.shape = CS_BUSY;

	sceneCopyBuffer:Clear();

    -- Copy components
    if (not #selectedComponents == 0) then
		for i = 1, #selectedComponents do
            local xml = XMLFile:new();
            local rootElem = xml:CreateRoot("component");
            selectedComponents[i]:SaveXML(rootElem);
			rootElem:SetBool("local", selectedComponents[i].id >= FIRST_LOCAL_ID);
			sceneCopyBuffer:Push(xml);
		end
    -- Copy nodes.
    else
		for i = 1, #selectedNodes do
            -- Skip the root scene node as it cannot be copied
            if (selectedNodes[i] ~= editorScene) then

				local xml = XMLFile:new();
				local rootElem = xml.CreateRoot("node");
				selectedNodes[i]:SaveXML(rootElem);
				rootElem:SetBool("local", selectedNodes[i].id >= FIRST_LOCAL_ID);
				sceneCopyBuffer:Push(xml);
			end 
		end 
	end

    return true;
end

function ScenePaste(pasteRoot, duplication)
	if (pasteRoot == nil) then
		pasteRoot = false;
	end
	if (duplication == nil) then
		duplication = false;
	end

    ui.cursor.shape = CS_BUSY;

    -- Group for storing undo actions
    local group = EditActionGroup:new();
	for i = 1, #sceneCopyBuffer do
        local rootElem = sceneCopyBuffer[i].root;
        local mode = rootElem.name;
        if (mode == "component" and editNode ~= nil) then
            -- If this is the root node, do not allow to create duplicate scene-global components
            if (editNode == editorScene and CheckForExistingGlobalComponent(editNode, rootElem.GetAttribute("type"))) then
                return false;
			end

            -- If copied component was local, make the new local too
            local newComponent = editNode:CreateComponent(rootElem.GetAttribute("type"), ifor(rootElem:GetBool("local") , LOCAL, 
                REPLICATED));
            if (newComponent == nil) then
                return false;
			end

            newComponent:LoadXML(rootElem);
			newComponent:ApplyAttributes();

            -- Create an undo action
            local action = CreateComponentAction:new();
			action:Define(newComponent);
            Push(group.actions, action);
        elseif (mode == "node") then
            -- If copied node was local, make the new local too
            local newNode;
            -- Are we pasting into the root node?
            if (pasteRoot) then
                newNode = editorScene:CreateChild("", ifor(rootElem:GetBool("local") , LOCAL , REPLICATED));
            else
                -- If we are duplicating, paste into the selected nodes parent
                if (duplication) then
                    if (editNode ~= nil and editNode.parent ~= nil) then
                        newNode = editNode.parent:CreateChild("", ifor(rootElem.GetBool("local") , LOCAL , REPLICATED));
                    else
                        newNode = editorScene:CreateChild("", rootElem:GetBool("local") , LOCAL , REPLICATED);
					end
                -- If we aren't duplicating, paste into the selected node
                else
                    newNode = editNode:CreateChild("", ifor(rootElem:GetBool("local"), LOCAL, REPLICATED));
				end
			end

            newNode:LoadXML(rootElem);

            -- Create an undo action
            local action = CreateNodeAction:new();
			action:Define(newNode);
            Push(group.actions, action);
		end
	end

    SaveEditActionGroup(group);
    SetSceneModified();
    return true;
end

function SceneDuplicate()
    local copy = sceneCopyBuffer;

    if (not SceneCopy()) then
        sceneCopyBuffer = copy;
        return false;
	end
    if (not ScenePaste(false, true)) then
        sceneCopyBuffer = copy;
        return false;
	end

    sceneCopyBuffer = copy;
    return true;
end

function SceneUnparent()
    if (not CheckHierarchyWindowFocus() and not empty(selectedComponents) and empty(selectedNodes)) then
        return false;
	end

    ui.cursor.shape = CS_BUSY;

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Parent selected nodes to root
    local changedNodes = {};
	for i = 1, #selectedNodes do
        local sourceNode = selectedNodes[i];
        if (sourceNode.parent == nil or sourceNode.parent == editorScene) then
		else

			-- Perform the reparenting, continue loop even if action fails
			local action = ReparentNodeAction:new();
			action:Define(sourceNode, editorScene);
			Push(group.actions, action);

			SceneChangeParent(sourceNode, editorScene, false);
			Push(changedNodes, sourceNode);
		end
	end

    -- Reselect the changed nodes at their new position in the list
	for i = 1, #changedNodes do
        hierarchyList:AddSelection(GetListIndex(changedNodes[i]));
	end

    SaveEditActionGroup(group);
    SetSceneModified();

    return true;
end

function SceneToggleEnable()
    if (not CheckHierarchyWindowFocus()) then
        return false;
	end

    ui.cursor.shape = CS_BUSY;

    local group = EditActionGroup:new();

    -- Toggle enabled state of nodes recursively
	for i = 1, #selectedNodes do
        -- Do not attempt to disable the Scene
        if (selectedNodes[i].typeName == "Node") then
            local oldEnabled = selectedNodes[i].enabled;
            selectedNodes[i]:SetEnabledRecursive(not oldEnabled);

            -- Create undo action
            local action = ToggleNodeEnabledAction:new();
			action:Define(selectedNodes[i], oldEnabled);
            Push(group.actions, action);
		end
	end

	for i = 1, #selectedComponents do
        -- Some components purposefully do not expose the Enabled attribute, and it does not affect them in any way
        -- (Octree, PhysicsWorld). Check that the first attribute is in fact called "Is Enabled"
        if (selectedComponents[i].numAttributes > 0 and selectedComponents[i].attributeInfos[0].name == "Is Enabled") then
            local oldEnabled = selectedComponents[i].enabled;
            selectedComponents[i].enabled = not oldEnabled;

            -- Create undo action
            local action = EditAttributeAction:new();
			action:Define(selectedComponents[i], 0, Variant(oldEnabled));
            Push(group.actions, action);
		end
	end

    SaveEditActionGroup(group);
    SetSceneModified();

    return true;
end

function SceneChangeParent(sourceNode, targetNode, createUndoAction)
	if (createUndoAction  == nil) then
		createUndoAction = true;
	end
    -- Create undo action if requested
    if (createUndoAction) then
        local action = ReparentNodeAction:new();
		action:Define(sourceNode, targetNode);
        SaveEditAction(action);
	end

    sourceNode.parent = targetNode;
    SetSceneModified();

    -- Return true if success
    if (sourceNode.parent == targetNode) then
        UpdateNodeAttributes(); -- Parent change may have changed local transform
        return true;
    else
        return false;
	end
end

function SceneChangeParent(sourceNode, sourceNodes, targetNode, createUndoAction)
	if (createUndoAction == nil) then	
		createUndoAction = true;
	end
    -- Create undo action if requested
    if (createUndoAction) then
        local action = ReparentNodeAction:new();
		action:Define(sourceNodes, targetNode);
        SaveEditAction(action);
	end

	for i = 1, #sourceNodes do
        local node = sourceNodes[i];
        node.parent = targetNode;
	end
    SetSceneModified();

    -- Return true if success
    if (sourceNode.parent == targetNode) then
        UpdateNodeAttributes(); -- Parent change may have changed local transform
        return true;
    else
        return false;
	end
end

function SceneResetPosition()
    if (editNode ~= nil) then
        local oldTransform = Transform:new();
		oldTransform:Define(editNode);

        editNode.position = Vector3(0.0, 0.0, 0.0);

        -- Create undo action
        local action = EditNodeTransformAction:new();
		action:Define(editNode, oldTransform);
        SaveEditAction(action);
        SetSceneModified();

        UpdateNodeAttributes();
        return true;
    else
        return false;
	end
end

function SceneResetRotation()
    if (editNode ~= nil) then
        local oldTransform = Transform:new();
		oldTransform:Define(editNode);

        editNode.rotation = Quaternion();

        -- Create undo action
        local action = EditNodeTransformAction:new();
		action:Define(editNode, oldTransform);
        SaveEditAction(action);
        SetSceneModified();

        UpdateNodeAttributes();
        return true;
    else
        return false;
	end
end

function SceneResetScale()
    if (editNode ~= nil) then
        local oldTransform = Transform:new();
		oldTransform:Define(editNode);

        editNode.scale = Vector3(1.0, 1.0, 1.0);

        -- Create undo action
        local action = EditNodeTransformAction:new();
		action:Define(editNode, oldTransform);
        SaveEditAction(action);
        SetSceneModified();

        UpdateNodeAttributes();
        return true;
    else
        return false;
	end
end

function SceneSelectAll()
    BeginSelectionModify();
    local rootLevelNodes = editorScene:GetChildren();
    local indices = {};
	for i = 1, #rootLevelNodes do
        Push(indices, GetListIndex(rootLevelNodes[i]));
	end
    hierarchyList:SetSelections(indices);
    EndSelectionModify();

    return true;
end

function SceneResetToDefault()
    ui.cursor.shape = CS_BUSY;

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Reset selected component to their default
    if (not empty(selectedComponents)) then
		for i = 1, #selectedComponents do
            local component = selectedComponents[i];

            local action = ResetAttributesAction:new();
			action:Define(component);
            Push(group.actions, action);

			component:ResetToDefault();
			component:ApplyAttributes();
			for j = 0, component.numAttributes - 1 do
                PostEditAttribute(component, j);
			end
		end
    -- OR reset selected nodes to their default
    else
		for i = 1, #selectedNodes do
            local node = selectedNodes[i];

            local action = ResetAttributesAction:new();
			action:Define(node);
            Push(group.actions, action);

			node:ResetToDefault();
			node:ApplyAttributes();
			for j = 0, node.numAttributes - 1 do
                PostEditAttribute(node, j);
			end
		end
	end

    SaveEditActionGroup(group);
    SetSceneModified();
    attributesFullDirty = true;

    return true;
end

function SceneRebuildNavigation()
    ui.cursor.shape = CS_BUSY;

    local navMeshes = editorScene:GetComponents("NavigationMesh", true);
    if (empty(navMeshes))then
        navMeshes = editorScene:GetComponents("DynamicNavigationMesh", true);
        if (empty(navMeshes)) then
            MessageBox("No NavigationMesh components in the scene, nothing to rebuild.");
            return false;
		end
	end

    local success = true;
	for i = 1, #navMeshes do
        local navMesh = navMeshes[i];
        if (not navMesh:Build()) then
            success = false;
		end
	end

    return success;
end

function SceneAddChildrenStaticModelGroup()
	local smg = nil
	if (#editComponents > 0) then
		smg = editComponents[1];
	end
    if (smg == nil and editNode ~= nil) then
        smg = editNode:GetComponent("StaticModelGroup");
	end

    if (smg == nil) then
        MessageBox("Must have a StaticModelGroup component selected.");
        return false;
	end

    local attrIndex = GetAttributeIndex(smg, "Instance Nodes");
    local oldValue = smg.attributes[attrIndex];

    local children = smg.node:GetChildren(true);
	for i = 1, #children do
        smg:AddInstanceNode(children[i]);
	end

    local action = EditAttributeAction:new();
	action:Define(smg, attrIndex, oldValue);
    SaveEditAction(action);
    SetSceneModified();
    FocusComponent(smg);
    
    return true;
end

function AssignMaterial(model, materialPath)
    local material = cache:GetResource("Material", materialPath);
    if (material == nil) then
        return;
	end

    local materials = model.GetAttribute("Material"):GetResourceRefList();
    local oldMaterials = {};
	for i = 1, #materials do
        Push(oldMaterials, materials.names[i]);
	end

    model.material = material;

    local action = AssignMaterialAction:new();
	action:Define(model, oldMaterials, material);
    SaveEditAction(action);
    SetSceneModified();
    FocusComponent(model);
end

function UpdateSceneMru(filename)

    while (Find(uiRecentScenes,filename) > -1) do 
        Erase(uiRecentScenes, Find(uiRecentScenes, filename));
	end

    Insert(uiRecentScenes, 0, filename);
	for i = #uiRecentScenes, 1, -1 do
        Erase(uiRecentScenes, i);
	end

    PopulateMruScenes();
end

function GetFirstDrawable(node)
    local nodes = node:GetChildren(true);
    Insert(nodes, 0, node);
	for i = 1, #nodes do
        local components = nodes[i]:GetComponents();
		for j = 1, #components do
            local drawable = tolua.cast(components[j], "Drawable");
            if (drawable ~= nil) then
                return drawable;
			end
		end
	end
    
    return nil;
end

function AssignModel(assignee, modelPath)
    local model = cache:GetResource("Model", modelPath);
    if (model == nil) then
        return;
	end

    local oldModel = assignee.model;
    assignee.model = model;

    local action = AssignModelAction:new();
	action:Define(assignee, oldModel, model);
    SaveEditAction(action);
    SetSceneModified();
    FocusComponent(assignee); 
end

function CreateModelWithStaticModel(filepath, parent)
    if (parent == nil) then
        return;
	end
    --/ \todo should be able to specify the createmode
    if (parent == editorScene) then
        parent = CreateNode(REPLICATED);
	end

    local model = cache:GetResource("Model", filepath);
    if (model == nil) then
        return;
	end

    local staticModel = parent:GetOrCreateComponent("StaticModel");
    staticModel.model = model;
    CreateLoadedComponent(staticModel);
end

function CreateModelWithAnimatedModel(filepath, parent)
    if (parent == nil) then
        return;
	end
    --/ \todo should be able to specify the createmode
    if (parent == editorScene) then
        parent = CreateNode(REPLICATED);
	end

    local model = cache:GetResource("Model", filepath);
    if (model == nil) then
        return;
	end

    local animatedModel = parent:GetOrCreateComponent("AnimatedModel");
    animatedModel.model = model;
    CreateLoadedComponent(animatedModel);
end
