
subscribedToEditorSettings = false;
settingsDialog = nil;

function CreateEditorSettingsDialog()
    if (settingsDialog ~= nil) then
        return;
	end
    
    settingsDialog = LoadEditorUI("UI/EditorSettingsDialog.xml");
    ui.root:AddChild(settingsDialog);
    settingsDialog.opacity = uiMaxOpacity;
    settingsDialog.height = 440;
    CenterDialog(settingsDialog);
    UpdateEditorSettingsDialog();
    HideEditorSettingsDialog();
end

function UpdateEditorSettingsDialog()
    if (settingsDialog == nil) then
        return;
	end


    local nearClipEdit = settingsDialog:GetChild("NearClipEdit", true);
    nearClipEdit.text = String(viewNearClip);

    local farClipEdit = settingsDialog:GetChild("FarClipEdit", true);
    farClipEdit.text = String(viewFarClip);

    local fovEdit = settingsDialog:GetChild("FOVEdit", true);
    fovEdit.text = String(viewFov);

    local speedEdit = settingsDialog:GetChild("SpeedEdit", true);
    speedEdit.text = String(cameraBaseSpeed);

    local limitRotationToggle = settingsDialog:GetChild("LimitRotationToggle", true);
    limitRotationToggle.checked = limitRotation;

    local mouseWheelCameraPositionToggle = settingsDialog:GetChild("MouseWheelCameraPositionToggle", true);
    mouseWheelCameraPositionToggle.checked = mouseWheelCameraPosition;

    local mouseOrbitEdit = settingsDialog:GetChild("MouseOrbitEdit", true);
    mouseOrbitEdit.selection = mouseOrbitMode;

    local distanceEdit = settingsDialog:GetChild("DistanceEdit", true);
    distanceEdit.text = (newNodeDistance) .. "";

    local moveStepEdit = settingsDialog:GetChild("MoveStepEdit", true);
    moveStepEdit.text = (moveStep) .. "";
    local moveSnapToggle = settingsDialog:GetChild("MoveSnapToggle", true);
    moveSnapToggle.checked = moveSnap;

    local rotateStepEdit = settingsDialog:GetChild("RotateStepEdit", true);
    rotateStepEdit.text = String(rotateStep);
    local rotateSnapToggle = settingsDialog:GetChild("RotateSnapToggle", true);
    rotateSnapToggle.checked = rotateSnap;

    local scaleStepEdit = settingsDialog:GetChild("ScaleStepEdit", true);
    scaleStepEdit.text = (scaleStep) .. "";
    local scaleSnapToggle = settingsDialog:GetChild("ScaleSnapToggle", true);
    scaleSnapToggle.checked = scaleSnap;

    local applyMaterialListToggle = settingsDialog:GetChild("ApplyMaterialListToggle", true);
    applyMaterialListToggle.checked = applyMaterialList;

    local rememberResourcePathToggle = settingsDialog:GetChild("RememberResourcePathToggle", true);
    rememberResourcePathToggle.checked = rememberResourcePath;

    local importOptionsEdit = settingsDialog:GetChild("ImportOptionsEdit", true);
    importOptionsEdit.text = importOptions;

    local pickModeEdit = settingsDialog:GetChild("PickModeEdit", true);
    pickModeEdit.selection = pickMode;

    local renderPathNameEdit = settingsDialog:GetChild("RenderPathNameEdit", true);
    renderPathNameEdit.text = renderPathName;

    local pickRenderPathButton = settingsDialog:GetChild("PickRenderPathButton", true);

    local textureQualityEdit = settingsDialog:GetChild("TextureQualityEdit", true);
    textureQualityEdit.selection = renderer.textureQuality;

    local materialQualityEdit = settingsDialog:GetChild("MaterialQualityEdit", true);
    materialQualityEdit.selection = renderer.materialQuality;

    local shadowResolutionEdit = settingsDialog:GetChild("ShadowResolutionEdit", true);
    shadowResolutionEdit.selection = GetShadowResolution();

    local shadowQualityEdit = settingsDialog:GetChild("ShadowQualityEdit", true);
    shadowQualityEdit.selection = renderer.shadowQuality;

    local maxOccluderTrianglesEdit = settingsDialog:GetChild("MaxOccluderTrianglesEdit", true);
    maxOccluderTrianglesEdit.text = (renderer.maxOccluderTriangles) .. "";

    local specularLightingToggle = settingsDialog:GetChild("SpecularLightingToggle", true);
    specularLightingToggle.checked = renderer.specularLighting;

    local dynamicInstancingToggle = settingsDialog:GetChild("DynamicInstancingToggle", true);
    dynamicInstancingToggle.checked = renderer.dynamicInstancing;

    local frameLimiterToggle = settingsDialog:GetChild("FrameLimiterToggle", true);
    frameLimiterToggle.checked = engine.maxFps > 0;

    if (not subscribedToEditorSettings) then
        SubscribeToEvent(nearClipEdit, "TextChanged", "EditCameraNearClip");
        SubscribeToEvent(nearClipEdit, "TextFinished", "EditCameraNearClip");
        SubscribeToEvent(farClipEdit, "TextChanged", "EditCameraFarClip");
        SubscribeToEvent(farClipEdit, "TextFinished", "EditCameraFarClip");
        SubscribeToEvent(fovEdit, "TextChanged", "EditCameraFOV");
        SubscribeToEvent(fovEdit, "TextFinished", "EditCameraFOV");
        SubscribeToEvent(speedEdit, "TextChanged", "EditCameraSpeed");
        SubscribeToEvent(speedEdit, "TextFinished", "EditCameraSpeed");
        SubscribeToEvent(limitRotationToggle, "Toggled", "EditLimitRotation");
        SubscribeToEvent(mouseWheelCameraPositionToggle, "Toggled", "EditMouseWheelCameraPosition");
        SubscribeToEvent(mouseOrbitEdit, "ItemSelected", "EditMouseOrbitMode");
        SubscribeToEvent(distanceEdit, "TextChanged", "EditNewNodeDistance");
        SubscribeToEvent(distanceEdit, "TextFinished", "EditNewNodeDistance");
        SubscribeToEvent(moveStepEdit, "TextChanged", "EditMoveStep");
        SubscribeToEvent(moveStepEdit, "TextFinished", "EditMoveStep");
        SubscribeToEvent(rotateStepEdit, "TextChanged", "EditRotateStep");
        SubscribeToEvent(rotateStepEdit, "TextFinished", "EditRotateStep");
        SubscribeToEvent(scaleStepEdit, "TextChanged", "EditScaleStep");
        SubscribeToEvent(scaleStepEdit, "TextFinished", "EditScaleStep");
        SubscribeToEvent(moveSnapToggle, "Toggled", "EditMoveSnap");
        SubscribeToEvent(rotateSnapToggle, "Toggled", "EditRotateSnap");
        SubscribeToEvent(scaleSnapToggle, "Toggled", "EditScaleSnap");
        SubscribeToEvent(rememberResourcePathToggle, "Toggled", "EditRememberResourcePath");
        SubscribeToEvent(applyMaterialListToggle, "Toggled", "EditApplyMaterialList");
        SubscribeToEvent(importOptionsEdit, "TextChanged", "EditImportOptions");
        SubscribeToEvent(importOptionsEdit, "TextFinished", "EditImportOptions");
        SubscribeToEvent(pickModeEdit, "ItemSelected", "EditPickMode");
        SubscribeToEvent(renderPathNameEdit, "TextFinished", "EditRenderPathName");
        SubscribeToEvent(pickRenderPathButton, "Released", "PickRenderPath");
        SubscribeToEvent(textureQualityEdit, "ItemSelected", "EditTextureQuality");
        SubscribeToEvent(materialQualityEdit, "ItemSelected", "EditMaterialQuality");
        SubscribeToEvent(shadowResolutionEdit, "ItemSelected", "EditShadowResolution");
        SubscribeToEvent(shadowQualityEdit, "ItemSelected", "EditShadowQuality");
        SubscribeToEvent(maxOccluderTrianglesEdit, "TextChanged", "EditMaxOccluderTriangles");
        SubscribeToEvent(maxOccluderTrianglesEdit, "TextFinished", "EditMaxOccluderTriangles");
        SubscribeToEvent(specularLightingToggle, "Toggled", "EditSpecularLighting");
        SubscribeToEvent(dynamicInstancingToggle, "Toggled", "EditDynamicInstancing");
        SubscribeToEvent(frameLimiterToggle, "Toggled", "EditFrameLimiter");
        SubscribeToEvent(settingsDialog:GetChild("CloseButton", true), "Released", "HideEditorSettingsDialog");
        subscribedToEditorSettings = true;
	end
end


function ShowEditorSettingsDialog()

    UpdateEditorSettingsDialog();
    settingsDialog.visible = true;
    settingsDialog:BringToFront();
    return true;
end

function HideEditorSettingsDialog()
    settingsDialog.visible = false;
end

function EditCameraNearClip(eventType, eventData)
    local edit = tolua.cast(eventData["Element"]:GetPtr(), "LineEdit"); 
    viewNearClip = ToFloat(edit.text);
    UpdateViewParameters();
    if (eventType == StringHash("TextFinished")) then
        edit.text = (camera.nearClip) .. "";
	end
end

function EditCameraFarClip(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    viewFarClip = ToFloat(edit.text);
    UpdateViewParameters();
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(camera.farClip);
	end
end

function EditCameraFOV(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    viewFov = ToFloat(edit.text);
    UpdateViewParameters();
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(camera.fov);
	end
end

function EditCameraSpeed(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    cameraBaseSpeed = Max(ToFloat(edit.text), 1.0);
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(cameraBaseSpeed);
	end
end

function EditLimitRotation(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    limitRotation = edit.checked;
end

function EditMouseWheelCameraPosition(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    mouseWheelCameraPosition = edit.checked;
end

function EditMouseOrbitMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    mouseOrbitMode = edit.selection;
end

function EditNewNodeDistance(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    newNodeDistance = Max(ToFloat(edit.text), 0.0);
    if (eventType == StringHash("TextFinished")) then
        edit.text = (newNodeDistance) .. "";
	end
end

function EditMoveStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    moveStep = Max(ToFloat(edit.text), 0.0);
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(moveStep);
	end
end

function EditRotateStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    rotateStep = Max(ToFloat(edit.text), 0.0);
    if (eventType == StringHash("TextFinished")) then
        edit.text = (rotateStep) .. "";
	end
end

function EditScaleStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    scaleStep = Max(ToFloat(edit.text), 0.0);
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(scaleStep);
	end
end

function EditMoveSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    moveSnap = edit.checked;
    toolBarDirty = true;
end

function EditRotateSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    rotateSnap = edit.checked;
    toolBarDirty = true;
end

function EditScaleSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    scaleSnap = edit.checked;
    toolBarDirty = true;
end

function EditRememberResourcePath(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    rememberResourcePath = edit.checked;
end

function EditApplyMaterialList(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    applyMaterialList = edit.checked;
end

function EditImportOptions(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    importOptions = Trimmed(edit.text);
end

function EditPickMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    pickMode = edit.selection;
end

function EditRenderPathName(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    SetRenderPath(edit.text);
end

function PickRenderPath(eventType, eventData)
    CreateFileSelector("Load render path", "Load", "Cancel", uiRenderPathPath, uiRenderPathFilters, uiRenderPathFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "HandleLoadRenderPath");
end

function HandleLoadRenderPath(eventType, eventData)
    CloseFileSelector(uiRenderPathFilter, uiRenderPathPath);
    SetRenderPath(GetResourceNameFromFullName(ExtractFileName(eventData)));
    local renderPathNameEdit = settingsDialog:GetChild("RenderPathNameEdit", true);
    renderPathNameEdit.text = renderPathName;
end

function EditTextureQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.textureQuality = edit.selection;
end

function EditMaterialQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.materialQuality = edit.selection;
end

function EditShadowResolution(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    SetShadowResolution(edit.selection);
end

function EditShadowQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.shadowQuality = edit.selection;
end

function EditMaxOccluderTriangles(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.maxOccluderTriangles = ToInt(edit.text);
    if (eventType == StringHash("TextFinished")) then
        edit.text = String(renderer.maxOccluderTriangles);
	end
end

function EditSpecularLighting(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.specularLighting = edit.checked;
end

function EditDynamicInstancing(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.dynamicInstancing = edit.checked;
end

function EditFrameLimiter(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    engine.maxFps = ifor(edit.checked , 200 , 0);
end
