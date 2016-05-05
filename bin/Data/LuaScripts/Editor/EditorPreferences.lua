-- Urho3D editor preferences dialog

subscribedToEditorPreferences = false;
preferencesDialog = nil;

nodeItemTextColorEditR = nil;
nodeItemTextColorEditG = nil;
nodeItemTextColorEditB = nil;
componentItemTextColorEditR = nil;
componentItemTextColorEditG = nil;
componentItemTextColorEditB = nil;

originalAttributeTextColorEditR = nil;
originalAttributeTextColorEditG = nil;
originalAttributeTextColorEditB = nil;
modifiedAttributeTextColorEditR = nil;
modifiedAttributeTextColorEditG = nil;
modifiedAttributeTextColorEditB = nil;
nonEditableAttributeTextColorEditR = nil;
nonEditableAttributeTextColorEditG = nil;
nonEditableAttributeTextColorEditB = nil;

defaultZoneAmbientColorEditR = nil;
defaultZoneAmbientColorEditG = nil;
defaultZoneAmbientColorEditB = nil;
defaultZoneFogColorEditR = nil;
defaultZoneFogColorEditG = nil;
defaultZoneFogColorEditB = nil;

gridColorEditR = nil;
gridColorEditG = nil;
gridColorEditB = nil;
gridSubdivisionColorEditR = nil;
gridSubdivisionColorEditG = nil;
gridSubdivisionColorEditB = nil;

function CreateEditorPreferencesDialog()
    if (preferencesDialog ~= nil) then
        return;
	end

    preferencesDialog = LoadEditorUI("UI/EditorPreferencesDialog.xml");
    ui.root:AddChild(preferencesDialog);
    preferencesDialog.opacity = uiMaxOpacity;
    preferencesDialog.height = 440;
    CenterDialog(preferencesDialog);

    nodeItemTextColorEditR = preferencesDialog:GetChild("NodeItemTextColor.r", true);
    nodeItemTextColorEditG = preferencesDialog:GetChild("NodeItemTextColor.g", true);
    nodeItemTextColorEditB = preferencesDialog:GetChild("NodeItemTextColor.b", true);
    componentItemTextColorEditR = preferencesDialog:GetChild("ComponentItemTextColor.r", true);
    componentItemTextColorEditG = preferencesDialog:GetChild("ComponentItemTextColor.g", true);
    componentItemTextColorEditB = preferencesDialog:GetChild("ComponentItemTextColor.b", true);

    originalAttributeTextColorEditR = preferencesDialog:GetChild("OriginalAttributeTextColor.r", true);
    originalAttributeTextColorEditG = preferencesDialog:GetChild("OriginalAttributeTextColor.g", true);
    originalAttributeTextColorEditB = preferencesDialog:GetChild("OriginalAttributeTextColor.b", true);
    modifiedAttributeTextColorEditR = preferencesDialog:GetChild("ModifiedAttributeTextColor.r", true);
    modifiedAttributeTextColorEditG = preferencesDialog:GetChild("ModifiedAttributeTextColor.g", true);
    modifiedAttributeTextColorEditB = preferencesDialog:GetChild("ModifiedAttributeTextColor.b", true);
    nonEditableAttributeTextColorEditR = preferencesDialog:GetChild("NonEditableAttributeTextColor.r", true);
    nonEditableAttributeTextColorEditG = preferencesDialog:GetChild("NonEditableAttributeTextColor.g", true);
    nonEditableAttributeTextColorEditB = preferencesDialog:GetChild("NonEditableAttributeTextColor.b", true);

    defaultZoneAmbientColorEditR = preferencesDialog:GetChild("DefaultZoneAmbientColor.r", true);
    defaultZoneAmbientColorEditG = preferencesDialog:GetChild("DefaultZoneAmbientColor.g", true);
    defaultZoneAmbientColorEditB = preferencesDialog;GetChild("DefaultZoneAmbientColor.b", true);
    defaultZoneFogColorEditR = preferencesDialog:GetChild("DefaultZoneFogColor.r", true);
    defaultZoneFogColorEditG = preferencesDialog:GetChild("DefaultZoneFogColor.g", true);
    defaultZoneFogColorEditB = preferencesDialog:GetChild("DefaultZoneFogColor.b", true);

    gridColorEditR = preferencesDialog:GetChild("GridColor.r", true);
    gridColorEditG = preferencesDialog:GetChild("GridColor.g", true);
    gridColorEditB = preferencesDialog:GetChild("GridColor.b", true);
    gridSubdivisionColorEditR = preferencesDialog:GetChild("GridSubdivisionColor.r", true);
    gridSubdivisionColorEditG = preferencesDialog:GetChild("GridSubdivisionColor.g", true);
    gridSubdivisionColorEditB = preferencesDialog:GetChild("GridSubdivisionColor.b", true);

    UpdateEditorPreferencesDialog();
    HideEditorPreferencesDialog();
end

function UpdateEditorPreferencesDialog()
    if (preferencesDialog == nil) then
        return;
	end

    local uiMinOpacityEdit = preferencesDialog:GetChild("UIMinOpacity", true);
    uiMinOpacityEdit.text = "" .. (uiMinOpacity);

    local uiMaxOpacityEdit = preferencesDialog:GetChild("UIMaxOpacity", true);
    uiMaxOpacityEdit.text = String(uiMaxOpacity);

    local showInternalUIElementToggle = preferencesDialog:GetChild("ShowInternalUIElement", true);
    showInternalUIElementToggle.checked = showInternalUIElement;

    local showTemporaryObjectToggle = preferencesDialog:GetChild("ShowTemporaryObject", true);
    showTemporaryObjectToggle.checked = showTemporaryObject;

    nodeItemTextColorEditR.text = "" .. (nodeTextColor.r);
    nodeItemTextColorEditG.text = "" .. (nodeTextColor.g);
    nodeItemTextColorEditB.text = "" .. (nodeTextColor.b);

    componentItemTextColorEditR.text = "" .. (componentTextColor.r);
    componentItemTextColorEditG.text = "" .. (componentTextColor.g);
    componentItemTextColorEditB.text = "" .. (componentTextColor.b);

    local showNonEditableAttributeToggle = preferencesDialog:GetChild("ShowNonEditableAttribute", true);
    showNonEditableAttributeToggle.checked = showNonEditableAttribute;

    originalAttributeTextColorEditR.text = "" .. (normalTextColor.r);
    originalAttributeTextColorEditG.text = "" .. (normalTextColor.g);
    originalAttributeTextColorEditB.text = "" .. (normalTextColor.b);

    modifiedAttributeTextColorEditR.text = "" .. (modifiedTextColor.r);
    modifiedAttributeTextColorEditG.text = "" .. (modifiedTextColor.g);
    modifiedAttributeTextColorEditB.text = String(modifiedTextColor.b);

    nonEditableAttributeTextColorEditR.text = String(nonEditableTextColor.r);
    nonEditableAttributeTextColorEditG.text = String(nonEditableTextColor.g);
    nonEditableAttributeTextColorEditB.text = String(nonEditableTextColor.b);

    defaultZoneAmbientColorEditR.text = String(renderer.defaultZone.ambientColor.r);
    defaultZoneAmbientColorEditG.text = String(renderer.defaultZone.ambientColor.g);
    defaultZoneAmbientColorEditB.text = String(renderer.defaultZone.ambientColor.b);

    defaultZoneFogColorEditR.text = String(renderer.defaultZone.fogColor.r);
    defaultZoneFogColorEditG.text = String(renderer.defaultZone.fogColor.g);
    defaultZoneFogColorEditB.text = String(renderer.defaultZone.fogColor.b);

    local defaultZoneFogStartEdit = preferencesDialog:GetChild("DefaultZoneFogStart", true);
    defaultZoneFogStartEdit.text = String(renderer.defaultZone.fogStart);
    local defaultZoneFogEndEdit = preferencesDialog:GetChild("DefaultZoneFogEnd", true);
    defaultZoneFogEndEdit.text = String(renderer.defaultZone.fogEnd);

    local showGridToggle = preferencesDialog:GetChild("ShowGrid", true);
    showGridToggle.checked = showGrid;
    
    local grid2DModeToggle = preferencesDialog:GetChild("Grid2DMode", true);
    grid2DModeToggle.checked = grid2DMode;

    local gridSizeEdit = preferencesDialog:GetChild("GridSize", true);
    gridSizeEdit.text = String(gridSize);
    
    local gridSubdivisionsEdit = preferencesDialog:GetChild("GridSubdivisions", true);
    gridSubdivisionsEdit.text = String(gridSubdivisions);
    
    local gridScaleEdit = preferencesDialog:GetChild("GridScale", true);
    gridScaleEdit.text = String(gridScale);

    gridColorEditR.text = String(gridColor.r);
    gridColorEditG.text = String(gridColor.g);
    gridColorEditB.text = String(gridColor.b);
    gridSubdivisionColorEditR.text = String(gridSubdivisionColor.r);
    gridSubdivisionColorEditG.text = String(gridSubdivisionColor.g);
    gridSubdivisionColorEditB.text = String(gridSubdivisionColor.b);

    if (not subscribedToEditorPreferences) then
        SubscribeToEvent(uiMinOpacityEdit, "TextFinished", "EditUIMinOpacity");
        SubscribeToEvent(uiMaxOpacityEdit, "TextFinished", "EditUIMaxOpacity");
        SubscribeToEvent(showInternalUIElementToggle, "Toggled", "ToggleShowInternalUIElement");
        SubscribeToEvent(showTemporaryObjectToggle, "Toggled", "ToggleShowTemporaryObject");
        SubscribeToEvent(nodeItemTextColorEditR, "TextFinished", "EditNodeTextColor");
        SubscribeToEvent(nodeItemTextColorEditG, "TextFinished", "EditNodeTextColor");
        SubscribeToEvent(nodeItemTextColorEditB, "TextFinished", "EditNodeTextColor");
        SubscribeToEvent(componentItemTextColorEditR, "TextFinished", "EditComponentTextColor");
        SubscribeToEvent(componentItemTextColorEditG, "TextFinished", "EditComponentTextColor");
        SubscribeToEvent(componentItemTextColorEditB, "TextFinished", "EditComponentTextColor");
        SubscribeToEvent(showNonEditableAttributeToggle, "Toggled", "ToggleShowNonEditableAttribute");
        SubscribeToEvent(originalAttributeTextColorEditR, "TextFinished", "EditOriginalAttributeTextColor");
        SubscribeToEvent(originalAttributeTextColorEditG, "TextFinished", "EditOriginalAttributeTextColor");
        SubscribeToEvent(originalAttributeTextColorEditB, "TextFinished", "EditOriginalAttributeTextColor");
        SubscribeToEvent(modifiedAttributeTextColorEditR, "TextFinished", "EditModifiedAttributeTextColor");
        SubscribeToEvent(modifiedAttributeTextColorEditG, "TextFinished", "EditModifiedAttributeTextColor");
        SubscribeToEvent(modifiedAttributeTextColorEditB, "TextFinished", "EditModifiedAttributeTextColor");
        SubscribeToEvent(nonEditableAttributeTextColorEditR, "TextFinished", "EditNonEditableAttributeTextColor");
        SubscribeToEvent(nonEditableAttributeTextColorEditG, "TextFinished", "EditNonEditableAttributeTextColor");
        SubscribeToEvent(nonEditableAttributeTextColorEditB, "TextFinished", "EditNonEditableAttributeTextColor");
        SubscribeToEvent(defaultZoneAmbientColorEditR, "TextFinished", "EditDefaultZoneAmbientColor");
        SubscribeToEvent(defaultZoneAmbientColorEditG, "TextFinished", "EditDefaultZoneAmbientColor");
        SubscribeToEvent(defaultZoneAmbientColorEditB, "TextFinished", "EditDefaultZoneAmbientColor");
        SubscribeToEvent(defaultZoneFogColorEditR, "TextFinished", "EditDefaultZoneFogColor");
        SubscribeToEvent(defaultZoneFogColorEditG, "TextFinished", "EditDefaultZoneFogColor");
        SubscribeToEvent(defaultZoneFogColorEditB, "TextFinished", "EditDefaultZoneFogColor");
        SubscribeToEvent(defaultZoneFogStartEdit, "TextFinished", "EditDefaultZoneFogStart");
        SubscribeToEvent(defaultZoneFogEndEdit, "TextFinished", "EditDefaultZoneFogEnd");
        SubscribeToEvent(showGridToggle, "Toggled", "ToggleShowGrid");
        SubscribeToEvent(grid2DModeToggle, "Toggled", "ToggleGrid2DMode");
        SubscribeToEvent(gridSizeEdit, "TextFinished", "EditGridSize");
        SubscribeToEvent(gridSubdivisionsEdit, "TextFinished", "EditGridSubdivisions");
        SubscribeToEvent(gridScaleEdit, "TextFinished", "EditGridScale");
        SubscribeToEvent(gridColorEditR, "TextFinished", "EditGridColor");
        SubscribeToEvent(gridColorEditG, "TextFinished", "EditGridColor");
        SubscribeToEvent(gridColorEditB, "TextFinished", "EditGridColor");
        SubscribeToEvent(gridSubdivisionColorEditR, "TextFinished", "EditGridSubdivisionColor");
        SubscribeToEvent(gridSubdivisionColorEditG, "TextFinished", "EditGridSubdivisionColor");
        SubscribeToEvent(gridSubdivisionColorEditB, "TextFinished", "EditGridSubdivisionColor");
        SubscribeToEvent(preferencesDialog:GetChild("CloseButton", true), "Released", "HideEditorPreferencesDialog");
        subscribedToEditorPreferences = true;
	end
end

function ShowEditorPreferencesDialog()
    UpdateEditorPreferencesDialog();
    preferencesDialog.visible = true;
	preferencesDialog:BringToFront();
    return true;
end

function HideEditorPreferencesDialog()
    preferencesDialog.visible = false;
end

function EditUIMinOpacity(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    uiMinOpacity = ToFloat(edit.text);
    edit.text = String(uiMinOpacity);
    FadeUI();
    UnfadeUI();
end

function EditUIMaxOpacity(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    uiMaxOpacity = ToFloat(edit.text);
    edit.text = String(uiMaxOpacity);
    FadeUI();
    UnfadeUI();
end

function ToggleShowInternalUIElement(eventType, eventData)
    showInternalUIElement = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
    UpdateHierarchyItem(editorUIElement, true);
end

function ToggleShowTemporaryObject(eventType, eventData)
    showTemporaryObject = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
    UpdateHierarchyItem(editorScene, true);
    UpdateHierarchyItem(editorUIElement, true);
end

function EditNodeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    nodeTextColor = Color(ToFloat(nodeItemTextColorEditR.text), ToFloat(nodeItemTextColorEditG.text), ToFloat(nodeItemTextColorEditB.text));
    if (edit.name == "NodeItemTextColor.r") then
        edit.text = String(normalTextColor.r);
    elseif (edit.name == "NodeItemTextColor.g") then
        edit.text = String(normalTextColor.g);
    elseif (edit.name == "NodeItemTextColor.b") then
        edit.text = String(normalTextColor.b);
	end
    UpdateHierarchyItem(editorScene);
end

function EditComponentTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    componentTextColor = Color(ToFloat(componentItemTextColorEditR.text), ToFloat(componentItemTextColorEditG.text), ToFloat(componentItemTextColorEditB.text));
    if (edit.name == "ComponentItemTextColor.r") then
        edit.text = String(normalTextColor.r);
    elseif (edit.name == "ComponentItemTextColor.g") then
        edit.text = String(normalTextColor.g);
    elseif (edit.name == "ComponentItemTextColor.b") then
        edit.text = String(normalTextColor.b);
	end
    UpdateHierarchyItem(editorScene);
end

function ToggleShowNonEditableAttribute(eventType, eventData)
    showNonEditableAttribute = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
    UpdateAttributeInspector(true);
end

function EditOriginalAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    normalTextColor = Color(ToFloat(originalAttributeTextColorEditR.text), ToFloat(originalAttributeTextColorEditG.text), ToFloat(originalAttributeTextColorEditB.text));
    if (edit.name == "OriginalAttributeTextColor.r") then
        edit.text = String(normalTextColor.r);
    elseif (edit.name == "OriginalAttributeTextColor.g") then
        edit.text = String(normalTextColor.g);
    elseif (edit.name == "OriginalAttributeTextColor.b") then
        edit.text = String(normalTextColor.b);
	end
    UpdateAttributeInspector(false);
end

function EditModifiedAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    modifiedTextColor = Color(ToFloat(modifiedAttributeTextColorEditR.text), ToFloat(modifiedAttributeTextColorEditG.text), ToFloat(modifiedAttributeTextColorEditB.text));
    if (edit.name == "ModifiedAttributeTextColor.r") then
        edit.text = String(modifiedTextColor.r);
    elseif (edit.name == "ModifiedAttributeTextColor.g") then
        edit.text = String(modifiedTextColor.g);
    elseif (edit.name == "ModifiedAttributeTextColor.b") then
        edit.text = String(modifiedTextColor.b);
	end
    UpdateAttributeInspector(false);
end

function EditNonEditableAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    nonEditableTextColor = Color(ToFloat(nonEditableAttributeTextColorEditR.text), ToFloat(nonEditableAttributeTextColorEditG.text), ToFloat(nonEditableAttributeTextColorEditB.text));
    if (edit.name == "NonEditableAttributeTextColor.r") then
        edit.text = String(nonEditableTextColor.r);
    elseif (edit.name == "NonEditableAttributeTextColor.g") then
        edit.text = String(nonEditableTextColor.g);
    elseif (edit.name == "NonEditableAttributeTextColor.b") then
        edit.text = String(nonEditableTextColor.b);
	end
    UpdateAttributeInspector(false);
end

function EditDefaultZoneAmbientColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.defaultZone.ambientColor = Color(ToFloat(defaultZoneAmbientColorEditR.text), ToFloat(defaultZoneAmbientColorEditG.text), ToFloat(defaultZoneAmbientColorEditB.text));
    if (edit.name == "DefaultZoneAmbientColor.r") then
        edit.text = String(renderer.defaultZone.ambientColor.r);
    elseif (edit.name == "DefaultZoneAmbientColor.g") then
        edit.text = String(renderer.defaultZone.ambientColor.g);
    elseif (edit.name == "DefaultZoneAmbientColor.b") then
        edit.text = String(renderer.defaultZone.ambientColor.b);
	end
end

function EditDefaultZoneFogColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.defaultZone.fogColor = Color(ToFloat(defaultZoneFogColorEditR.text), ToFloat(defaultZoneFogColorEditG.text), ToFloat(defaultZoneFogColorEditB.text));
    if (edit.name == "DefaultZoneFogColor.r") then
        edit.text = String(renderer.defaultZone.fogColor.r);
    elseif (edit.name == "DefaultZoneFogColor.g") then
        edit.text = String(renderer.defaultZone.fogColor.g);
    elseif (edit.name == "DefaultZoneFogColor.b") then
        edit.text = String(renderer.defaultZone.fogColor.b);
	end
end

function EditDefaultZoneFogStart(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.defaultZone.fogStart = ToFloat(edit.text);
    edit.text = String(renderer.defaultZone.fogStart);
end

function EditDefaultZoneFogEnd(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    renderer.defaultZone.fogEnd = ToFloat(edit.text);
    edit.text = String(renderer.defaultZone.fogEnd);
end

function ToggleShowGrid(eventType, eventData)
    showGrid = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox").checked;
    UpdateGrid(false);
end

function ToggleGrid2DMode(eventType, eventData)
    grid2DMode = tolua.cast(eventData["Element"]:GetPtr(),"CheckBox").checked;
    UpdateGrid();
end

function EditGridSize(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    gridSize = ToInt(edit.text);
    edit.text = String(gridSize);
    UpdateGrid();
end

function EditGridSubdivisions(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    gridSubdivisions = ToInt(edit.text);
    edit.text = String(gridSubdivisions);
    UpdateGrid();
end

function EditGridScale(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    gridScale = ToFloat(edit.text);
    edit.text = String(gridScale);
    UpdateGrid(false);
end

function EditGridColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    gridColor = Color(ToFloat(gridColorEditR.text), ToFloat(gridColorEditG.text), ToFloat(gridColorEditB.text));
    if (edit.name == "GridColor.r") then
        edit.text = String(gridColor.r);
    elseif (edit.name == "GridColor.g") then
        edit.text = String(gridColor.g);
    elseif (edit.name == "GridColor.b") then
        edit.text = String(gridColor.b);
	end
    UpdateGrid();
end

function EditGridSubdivisionColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr();
    gridSubdivisionColor = Color(ToFloat(gridSubdivisionColorEditR.text), ToFloat(gridSubdivisionColorEditG.text), ToFloat(gridSubdivisionColorEditB.text));
    if (edit.name == "GridSubdivisionColor.r") then
        edit.text = String(gridSubdivisionColor.r);
    elseif (edit.name == "GridSubdivisionColor.g") then
        edit.text = String(gridSubdivisionColor.g);
    elseif (edit.name == "GridSubdivisionColor.b") then
        edit.text = String(gridSubdivisionColor.b);
	end
    UpdateGrid();
end


