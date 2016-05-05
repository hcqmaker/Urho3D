-- Urho3D material editor

materialWindow = nil; -- Window
editMaterial = nil; -- Material
oldMaterialState = nil; -- XMLFile
inMaterialRefresh = true;
materialPreview = nil; -- View3D
previewScene = nil; -- Scene
previewCameraNode = nil; -- Node
previewLightNode = nil; -- Node
previewLight = nil; -- Light
previewModelNode = nil; -- Node
previewModel = nil; -- StaticModel

function CreateMaterialEditor()
    if (materialWindow ~= nil) then
        return;
	end

    materialWindow = LoadEditorUI("UI/EditorMaterialWindow.xml");
    ui.root:AddChild(materialWindow);
    materialWindow.opacity = uiMaxOpacity;

    InitMaterialPreview();
    RefreshMaterialEditor();

    local height = Min(ui.root.height - 60, 500);
	materialWindow:SetSize(300, height);
    CenterDialog(materialWindow);

    HideMaterialEditor();

    SubscribeToEvent(materialWindow:GetChild("NewButton", true), "Released", "NewMaterial");
    SubscribeToEvent(materialWindow:GetChild("RevertButton", true), "Released", "RevertMaterial");
    SubscribeToEvent(materialWindow:GetChild("SaveButton", true), "Released", "SaveMaterial");
    SubscribeToEvent(materialWindow:GetChild("SaveAsButton", true), "Released", "SaveMaterialAs");
    SubscribeToEvent(materialWindow:GetChild("CloseButton", true), "Released", "HideMaterialEditor");
    SubscribeToEvent(materialWindow:GetChild("NewParameterDropDown", true), "ItemSelected", "CreateShaderParameter");
    SubscribeToEvent(materialWindow:GetChild("DeleteParameterButton", true), "Released", "DeleteShaderParameter");
    SubscribeToEvent(materialWindow:GetChild("NewTechniqueButton", true), "Released", "NewTechnique");
    SubscribeToEvent(materialWindow:GetChild("DeleteTechniqueButton", true), "Released", "DeleteTechnique");
    SubscribeToEvent(materialWindow:GetChild("SortTechniquesButton", true), "Released", "SortTechniques");
    SubscribeToEvent(materialWindow:GetChild("ConstantBiasEdit", true), "TextChanged", "EditConstantBias");
    SubscribeToEvent(materialWindow:GetChild("ConstantBiasEdit", true), "TextFinished", "EditConstantBias");
    SubscribeToEvent(materialWindow:GetChild("SlopeBiasEdit", true), "TextChanged", "EditSlopeBias");
    SubscribeToEvent(materialWindow:GetChild("SlopeBiasEdit", true), "TextFinished", "EditSlopeBias");
    SubscribeToEvent(materialWindow:GetChild("CullModeEdit", true), "ItemSelected", "EditCullMode");
    SubscribeToEvent(materialWindow:GetChild("ShadowCullModeEdit", true), "ItemSelected", "EditShadowCullMode");
    SubscribeToEvent(materialWindow:GetChild("FillModeEdit", true), "ItemSelected", "EditFillMode");
end

function ShowMaterialEditor()
    RefreshMaterialEditor();
    materialWindow.visible = true;
	materialWindow:BringToFront();
    return true;
end

function HideMaterialEditor()
    materialWindow.visible = false;
end

function InitMaterialPreview()
    previewScene = Scene("PreviewScene");
	previewScene:CreateComponent("Octree");

    local zoneNode = previewScene:CreateChild("Zone");
    local zone = zoneNode:CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000, 1000);
    zone.ambientColor = Color(0.15, 0.15, 0.15);
    zone.fogColor = Color(0, 0, 0);
    zone.fogStart = 10.0;
    zone.fogEnd = 100.0;

    previewCameraNode = previewScene:CreateChild("PreviewCamera");
    previewCameraNode.position = Vector3(0, 0, -1.5);
    local camera = previewCameraNode:CreateComponent("Camera");
    camera.nearClip = 0.1;
    camera.farClip = 100.0;

    previewLightNode = previewScene:CreateChild("PreviewLight");
    previewLightNode.direction = Vector3(0.5, -0.5, 0.5);
    previewLight = previewLightNode:CreateComponent("Light");
    previewLight.lightType = LIGHT_DIRECTIONAL;
    previewLight.specularIntensity = 0.5;

    previewModelNode = previewScene:CreateChild("PreviewModel");
    previewModelNode.rotation = Quaternion(0, 0, 0);
    previewModel = previewModelNode:CreateComponent("StaticModel");
    previewModel.model = cache:GetResource("Model", "Models/Sphere.mdl");

    materialPreview = materialWindow:GetChild("MaterialPreview", true);
    materialPreview:SetFixedHeight(100);
    materialPreview:SetView(previewScene, camera);
    materialPreview.viewport.renderPath = renderPath;
    materialPreview.autoUpdate = false;

    SubscribeToEvent(materialPreview, "DragMove", "RotateMaterialPreview");
end

function EditMaterial(mat)
    if (editMaterial ~= nil) then
        UnsubscribeFromEvent(editMaterial, "ReloadFinished");
	end

    editMaterial = mat;

    if (editMaterial ~= nil) then
        SubscribeToEvent(editMaterial, "ReloadFinished", "RefreshMaterialEditor");
	end

    ShowMaterialEditor();
end

function RefreshMaterialEditor()
    RefreshMaterialPreview();
    RefreshMaterialName();
    RefreshMaterialTechniques();
    RefreshMaterialTextures();
    RefreshMaterialShaderParameters();
    RefreshMaterialMiscParameters();
end

function RefreshMaterialPreview()
    previewModel.material = editMaterial;
	materialPreview:QueueUpdate();
end

function RefreshMaterialName()
    local container = materialWindow:GetChild("NameContainer", true);
	container:RemoveAllChildren();

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0);
    if (editMaterial ~= nil) then
        nameEdit.text = editMaterial.name;
	end
    SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialName");

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "Pick");
    SubscribeToEvent(pickButton, "Released", "PickEditMaterial");
end

function RefreshMaterialTechniques(fullUpdate)
	if (fullUpdate == nil) then
		fullUpdate = true;
	end
    local list = materialWindow:GetChild("TechniqueList", true);

    if (editMaterial == nil) then
        return;
	end

    if (fullUpdate == true) then
        list:RemoveAllItems();
		for i = 0, editMaterial.numTechniques - 1 do
            local entry = editMaterial.techniqueEntries[i];

            local container = UIElement:new();
			container:SetLayout(LM_HORIZONTAL, 4);
			container:SetFixedHeight(ATTR_HEIGHT);
			list:AddItem(container);

            local nameEdit = CreateAttributeLineEdit(container, nil, i, 0);
            nameEdit.name = "TechniqueNameEdit" .. String(i);

            local pickButton = CreateResourcePickerButton(container, nil, i, 0, "Pick");
            SubscribeToEvent(pickButton, "Released", "PickMaterialTechnique");
            local openButton = CreateResourcePickerButton(container, nil, i, 0, "Open");
            SubscribeToEvent(openButton, "Released", "OpenResource");

            if (entry.technique ~= nil) then
                nameEdit.text = entry.technique.name;
			end

            SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialTechnique");

            local container2 = UIElement:new();
			container2:SetLayout(LM_HORIZONTAL, 4);
			container2:SetFixedHeight(ATTR_HEIGHT);
			list:AddItem(container2);

            local text = container2:CreateChild("Text");
            text.style = "EditorAttributeText";
            text.text = "Quality";
            local attrEdit = CreateAttributeLineEdit(container2, nil, i, 0);
            attrEdit.text = String(entry.qualityLevel);
            SubscribeToEvent(attrEdit, "TextChanged", "EditTechniqueQuality");
            SubscribeToEvent(attrEdit, "TextFinished", "EditTechniqueQuality");

            text = container2:CreateChild("Text");
            text.style = "EditorAttributeText";
            text.text = "LOD Distance";
            attrEdit = CreateAttributeLineEdit(container2, nil, i, 0);
            attrEdit.text = String(entry.lodDistance);
            SubscribeToEvent(attrEdit, "TextChanged", "EditTechniqueLodDistance");
            SubscribeToEvent(attrEdit, "TextFinished", "EditTechniqueLodDistance");
		end 
    else
		for i = 0, editMaterial.numTechniques - 1 do
            local entry = editMaterial.techniqueEntries[i];

            local nameEdit = materialWindow:GetChild("TechniqueNameEdit" + String(i), true);
            if (nameEdit ~= nil) then
				nameEdit.text = ifor(entry.technique ~= nil, entry.technique.name , "");
			end
		end
	end
end

function RefreshMaterialTextures(fullUpdate)
	if (fullUpdate == nil) then
		fullUpdate = true;
	end
    if (fullUpdate) then
        local list = materialWindow:GetChild("TextureList", true);
		list:RemoveAllItems();
		for i = 0, MAX_MATERIAL_TEXTURE_UNITS - 1 do
            local tuName = GetTextureUnitName(TextureUnit(i));
            tuName[0] = ToUpper(tuName[0]);

            local parent = CreateAttributeEditorParentWithSeparatedLabel(list, "Unit " .. i .. " " .. tuName, i, 0, false);

            local container = UIElement:new();
			container:SetLayout(LM_HORIZONTAL, 4, IntRect(10, 0, 4, 0));
			container:SetFixedHeight(ATTR_HEIGHT);
			parent:AddChild(container);

            local nameEdit = CreateAttributeLineEdit(container, nil, i, 0);
            nameEdit.name = "TextureNameEdit" .. String(i);

            local pickButton = CreateResourcePickerButton(container, nil, i, 0, "Pick");
            SubscribeToEvent(pickButton, "Released", "PickMaterialTexture");
            local openButton = CreateResourcePickerButton(container, nil, i, 0, "Open");
            SubscribeToEvent(openButton, "Released", "OpenResource");

            if (editMaterial ~= nil) then
                local texture = editMaterial.textures[i];
                if (texture ~= nil) then
                    nameEdit.text = texture.name;
				end
			end

            SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialTexture");
		end
    else
		for i = 0, MAX_MATERIAL_TEXTURE_UNITS - 1 do
            local nameEdit = materialWindow:GetChild("TextureNameEdit" .. String(i), true);
            if (nameEdit ~= nil) then
				local textureName;
				if (editMaterial ~= nil) then
					local texture = editMaterial.textures[i];
					if (texture ~= nil) then
						textureName = texture.name;
					end
				end
			end
            
            nameEdit.text = textureName;
		end
	end
end

function RefreshMaterialShaderParameters()
    local list = materialWindow:GetChild("ShaderParameterList", true);
	list:RemoveAllItems();
    if (editMaterial == nil) then
        return;
	end

    local parameterNames = editMaterial.shaderParameterNames;

	for i = 0, parameterNames.length - 1 do
        local type = editMaterial.shaderParameters[parameterNames[i]].type;
        local value = editMaterial.shaderParameters[parameterNames[i]];
        local parent = CreateAttributeEditorParent(list, parameterNames[i], 0, 0);
        local numCoords = type - VAR_FLOAT + 1;

        local coordValues = Split(ToString(value), (' '));

		for j = 0, numCoords - 1 do
            local attrEdit = CreateAttributeLineEdit(parent, nil, 0, 0);
			attrEdit:GetVars():SetInt("Coordinate", j);
			attrEdit:GetVars():SetString("Name" , parameterNames[i]);
            attrEdit.text = coordValues[j];

            CreateDragSlider(attrEdit);

            SubscribeToEvent(attrEdit, "TextChanged", "EditShaderParameter");
            SubscribeToEvent(attrEdit, "TextFinished", "EditShaderParameter");
		end
	end
end

function RefreshMaterialMiscParameters()
    if (editMaterial == nil) then
        return;
	end
        
    local bias = editMaterial.depthBias;

    inMaterialRefresh = true;

    local attrEdit = materialWindow:GetChild("ConstantBiasEdit", true);
    attrEdit.text = String(bias.constantBias);
    attrEdit = materialWindow:GetChild("SlopeBiasEdit", true);
    attrEdit.text = String(bias.slopeScaledBias);
    
    local attrList = materialWindow:GetChild("CullModeEdit", true);
    attrList.selection = editMaterial.cullMode;
    attrList = materialWindow:GetChild("ShadowCullModeEdit", true);
    attrList.selection = editMaterial.shadowCullMode;
    attrList = materialWindow:GetChild("FillModeEdit", true);
    attrList.selection = editMaterial.fillMode;

    inMaterialRefresh = false;
end

function RotateMaterialPreview(eventType,  eventData)
    local elemX = eventData["ElementX"]:GetInt();
    local elemY = eventData["ElementY"]:GetInt();
    
    if (materialPreview.height > 0 and materialPreview.width > 0) then
        local yaw = ((materialPreview.height / 2) - elemY) * (90.0 / materialPreview.height);
        local pitch = ((materialPreview.width / 2) - elemX) * (90.0 / materialPreview.width);

        previewModelNode.rotation = previewModelNode.rotation.Slerp(Quaternion(yaw, pitch, 0), 0.1);
		materialPreview:QueueUpdate();
	end 
end

function EditMaterialName(eventType,  eventData)
    local nameEdit = eventData["Element"]:GetPtr();
    local newMaterialName = Trimmed(nameEdit.text);
    if (not empty(newMaterialName)) then
        local newMaterial = cache:GetResource("Material", newMaterialName);
        if (newMaterial ~= nil) then
            EditMaterial(newMaterial);
		end
	end
end

function PickEditMaterial()
    resourcePicker = GetResourcePicker(StringHash("Material"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditMaterialDone");
end

function PickEditMaterialDone(eventType,  eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end

    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);

    if (res ~= nil) then
        EditMaterial(tolua.cast(res, "Material"));
	end

    resourcePicker = nil;
end

function NewMaterial()
    EditMaterial(Material());
end

function RevertMaterial()
    if (editMaterial == nil) then
        return;
	end

    BeginMaterialEdit();
    cache:ReloadResource(editMaterial);
    EndMaterialEdit();
    
    RefreshMaterialEditor();
end

function SaveMaterial()
    if (editMaterial == nil or empty(editMaterial.name)) then
        return;
	end

    local fullName = cache:GetResourceFileName(editMaterial.name);
    if (empty(fullName)) then
        return;
	end

    MakeBackup(fullName);
    local saveFile = File(fullName, FILE_WRITE);
    local success = editMaterial:Save(saveFile);
    RemoveBackup(success, fullName);
end

function SaveMaterialAs()
    if (editMaterial == nil) then
        return;
	end

    resourcePicker = GetResourcePicker(StringHash("Material"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Save material as", "Save", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "SaveMaterialAsDone");
end

function SaveMaterialAsDone(eventType,  eventData)
    StoreResourcePickerPath();
    CloseFileSelector();
    resourcePicker = nil;

    if (editMaterial == nil) then
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
        fullName = fullName .. Substring(filter, 1);
	end

    MakeBackup(fullName);
    local saveFile = File(fullName, FILE_WRITE);
    if (editMaterial:Save(saveFile)) then
        saveFile:Close();
        RemoveBackup(true, fullName);

        -- Load the new resource to update the name in the editor
        local newMat = cache:GetResource("Material", GetResourceNameFromFullName(fullName));
        if (newMat ~= nil) then
            EditMaterial(newMat);
		end
	end 
end

function EditShaderParameter(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local attrEdit = eventData["Element"]:GetPtr();
    local coordinate = attrEdit:GetVars():GetInt("Coordinate");

    local name = attrEdit:GetVars():GetString("Name");

    local oldValue = editMaterial.shaderParameters[name];
    local coordValues = Split(ToString(oldValue),(' '));
    coordValues[coordinate] = String(attrEdit.text.ToFloat());

    local valueString;
	for i = 0, coordValues.length - 1 do
        valueString =  valueString .. coordValues[i];
        valueString =  valueString .. " ";
	end

    local newValue = Variant();
	newValue:FromString(oldValue.type, valueString);
    
    BeginMaterialEdit();
    editMaterial.shaderParameters[name] = newValue;
    EndMaterialEdit();
end

function CreateShaderParameter(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local nameEdit = materialWindow:GetChild("ParameterNameEdit", true);
    local newName = Trimmed(nameEdit.text);
    if (empty(newName)) then
        return;
	end

    local dropDown = eventData["Element"]:GetPtr();
    local newValue = Variant();

	local tp = dropDown.selection;
	if (tp == 0) then
        newValue = float(0);
	elseif (tp == 1) then
        newValue = Vector2(0, 0);
	elseif (tp == 2) then
        newValue = Vector3(0, 0, 0);
	elseif (tp == 3) then
        newValue = Vector4(0, 0, 0, 0);
	end
    BeginMaterialEdit();
    editMaterial.shaderParameters[newName] = newValue;
    EndMaterialEdit();

    RefreshMaterialShaderParameters();
end

function DeleteShaderParameter()
    if (editMaterial == nil) then
        return;
	end

    local nameEdit = materialWindow:GetChild("ParameterNameEdit", true);
    local name = Trimmed(nameEdit.text);
    if (empty(name)) then
        return;
	end

    BeginMaterialEdit();
	editMaterial:RemoveShaderParameter(name);
    EndMaterialEdit();

    RefreshMaterialShaderParameters();
end

function PickMaterialTexture(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local button = eventData["Element"]:GetPtr();
    resourcePickIndex = button:GetVars():GetUInt("Index");

    resourcePicker = GetResourcePicker(StringHash("Texture2D"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickMaterialTextureDone");
end

function PickMaterialTextureDone(eventType,  eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end 

    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);

    if (res ~= nil and editMaterial ~= nil) then
        BeginMaterialEdit();
        editMaterial.textures[resourcePickIndex] = res;
        EndMaterialEdit();

        RefreshMaterialTextures(false);
	end

    resourcePicker = nil;
end

function EditMaterialTexture(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local attrEdit = eventData["Element"]:GetPtr();
    local textureName = Trimmed(attrEdit.text);
    local index = attrEdit:GetVars():GetUInt("Index");

    BeginMaterialEdit();

    if (not empty(textureName)) then
        local texture = cache:GetResource(ifor(GetExtension(textureName) == ".xml" , "TextureCube" , "Texture2D"), textureName);
        editMaterial.textures[index] = texture;
    else
        editMaterial.textures[index] = nil;
	end

    EndMaterialEdit();
end

function NewTechnique()
    if (editMaterial == nil) then
        return;
	end
        
    BeginMaterialEdit();
    editMaterial.numTechniques = editMaterial.numTechniques + 1;
    EndMaterialEdit();
    
    RefreshMaterialTechniques();
end

function DeleteTechnique()
    if (editMaterial == nil or editMaterial.numTechniques < 2) then
        return;
	end

    BeginMaterialEdit();
    editMaterial.numTechniques = editMaterial.numTechniques - 1;
    EndMaterialEdit();
    
    RefreshMaterialTechniques();
end

function PickMaterialTechnique(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local button = eventData["Element"]:GetPtr();
    resourcePickIndex = button:GetVars():GetUInt("Index");

    resourcePicker = GetResourcePicker(StringHash("Technique"));
    if (resourcePicker == nil) then
        return;
	end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
	end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickMaterialTechniqueDone");
end

function PickMaterialTechniqueDone(eventType,  eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        resourcePicker = nil;
        return;
	end

    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);

    if (res ~= nil and editMaterial ~= nil) then
        BeginMaterialEdit();
        local entry = editMaterial.techniqueEntries[resourcePickIndex];
        editMaterial.SetTechnique(resourcePickIndex, res, entry.qualityLevel, entry.lodDistance);
        EndMaterialEdit();

        RefreshMaterialTechniques(false);
	end 

    resourcePicker = nil;
end

function EditMaterialTechnique(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local attrEdit = eventData["Element"]:GetPtr();
    local techniqueName = Trimmed(attrEdit.text);
    local index = attrEdit:GetVars():GetUInt("Index");

    BeginMaterialEdit();

    local newTech;
    if (not empty(techniqueName)) then
        newTech = cache:GetResource("Technique", techniqueName);
	end

    local entry = editMaterial.techniqueEntries[index];
    editMaterial.SetTechnique(index, newTech, entry.qualityLevel, entry.lodDistance);

    EndMaterialEdit();
end

function EditTechniqueQuality(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local attrEdit = eventData["Element"]:GetPtr();
    local newQualityLevel = ToUInt(attrEdit.text);
    local index = attrEdit:GetVars():GetUInt("Index");

    BeginMaterialEdit();
    local entry = editMaterial.techniqueEntries[index];
    editMaterial.SetTechnique(index, entry.technique, newQualityLevel, entry.lodDistance);
    EndMaterialEdit();
end

function EditTechniqueLodDistance(eventType,  eventData)
    if (editMaterial == nil) then
        return;
	end

    local attrEdit = eventData["Element"]:GetPtr();
    local newLodDistance = ToFloat(attrEdit.text);
    local index = attrEdit:GetVars():GetUInt("Index");

    BeginMaterialEdit();
    local entry = editMaterial.techniqueEntries[index];
    editMaterial.SetTechnique(index, entry.technique, entry.qualityLevel, newLodDistance);
    EndMaterialEdit();
end

function SortTechniques()
    if (editMaterial == nil) then
        return;
	end
        
    BeginMaterialEdit();
    editMaterial.SortTechniques();
    EndMaterialEdit();
    
    RefreshMaterialTechniques();
end

function EditConstantBias(eventType,  eventData)
    if (editMaterial == nil or inMaterialRefresh) then
        return;
	end
        
    BeginMaterialEdit();
 
    local attrEdit = eventData["Element"]:GetPtr();
    local bias = editMaterial.depthBias;
    bias.constantBias = ToFloat(attrEdit.text);
    editMaterial.depthBias = bias;

    EndMaterialEdit();
end

function EditSlopeBias(eventType,  eventData)
    if (editMaterial == nil or inMaterialRefresh) then
        return;
	end
        
    BeginMaterialEdit();
 
    local attrEdit = eventData["Element"]:GetPtr();
    local bias = editMaterial.depthBias;
    bias.slopeScaledBias = ToFloat(attrEdit.text);
    editMaterial.depthBias = bias;

    EndMaterialEdit();
end

function EditCullMode(eventType,  eventData)
    if (editMaterial == nil or inMaterialRefresh) then
        return;
	end
        
    BeginMaterialEdit();
    
    local attrEdit = eventData["Element"]:GetPtr();
    editMaterial.cullMode = CullMode(attrEdit.selection);

    EndMaterialEdit();
end

function EditShadowCullMode(eventType,  eventData)
    if (editMaterial == nil or inMaterialRefresh) then
        return;
	end
        
    BeginMaterialEdit();
    
    local attrEdit = eventData["Element"]:GetPtr();
    editMaterial.shadowCullMode = CullMode(attrEdit.selection);

    EndMaterialEdit();
end

function EditFillMode(eventType,  eventData)
    if (editMaterial == nil or inMaterialRefresh) then
        return;
	end
        
    BeginMaterialEdit();
    
    local attrEdit = eventData["Element"]:GetPtr();
    editMaterial.fillMode = FillMode(attrEdit.selection);

    EndMaterialEdit();
end

function BeginMaterialEdit()
	if (editMaterial == nil) then
        return;
	end

    oldMaterialState = XMLFile:new();
    local materialElem = oldMaterialState:CreateRoot("material");
	editMaterial:Save(materialElem);
end

function EndMaterialEdit()
    if (editMaterial == nil) then
        return;
	end
    if (not dragEditAttribute) then
        local action = EditMaterialAction:new();
		action:Define(editMaterial, oldMaterialState);
        SaveEditAction(action);
	end
    
    materialPreview:QueueUpdate();
end

