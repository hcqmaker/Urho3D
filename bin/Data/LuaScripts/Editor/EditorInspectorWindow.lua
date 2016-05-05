-- Urho3D editor attribute inspector window handling
require "LuaScripts/Editor/AttributeEditor"

attributeInspectorWindow = nil; --Window
parentContainer = nil; -- UIElement
inspectorLockButton = nil; -- UIElement

applyMaterialList = true;
attributesDirty = false;
attributesFullDirty = false;

STRIKED_OUT = 'kk'
--STRIKED_OUT = "——";   -- Two unicode EM DASH (U+2014)
NODE_IDS_VAR = StringHash("NodeIDs");
COMPONENT_IDS_VAR = StringHash("ComponentIDs");
UI_ELEMENT_IDS_VAR = StringHash("UIElementIDs");
LABEL_WIDTH = 30;

-- Constants for accessing xmlResources
xmlResources = {}; -- Array<XMLFile@>
ATTRIBUTE_RES = 0;
VARIABLE_RES = 1;
STYLE_RES = 2;

nodeContainerIndex = M_MAX_UNSIGNED;
componentContainerStartIndex = 0;
elementContainerIndex = M_MAX_UNSIGNED;

-- Script Attribute session storage
scriptAttributes = VariantMap();
SCRIPTINSTANCE_ATTRIBUTE_IGNORE = 5;
LUASCRIPTINSTANCE_ATTRIBUTE_IGNORE = 4;

-- Node or UIElement hash-to-varname reverse mapping
globalVarNames = VariantMap();

inspectorLocked = false;

function InitXMLResources()
    local resources = { "UI/EditorInspector_Attribute.xml", "UI/EditorInspector_Variable.xml", "UI/EditorInspector_Style.xml" };
	for i = 1, #resources do
        Push(xmlResources, cache:GetResource("XMLFile", resources[i]));
	end
end

--/ Delete all child containers in the inspector list.
function DeleteAllContainers()
    parentContainer:RemoveAllChildren();
    nodeContainerIndex = M_MAX_UNSIGNED;
    componentContainerStartIndex = 0;
    elementContainerIndex = M_MAX_UNSIGNED;
end

--/ Get container at the specified index in the inspector list, the container must be created before.
function GetContainer(index)
    return parentContainer:GetChild(index);
end

--/ Get node container in the inspector list, create the container if it is not yet available.
function GetNodeContainer()
    if (nodeContainerIndex ~= M_MAX_UNSIGNED) then
        return GetContainer(nodeContainerIndex);
	end

    nodeContainerIndex = parentContainer.numChildren;
    parentContainer.LoadChildXML(xmlResources[ATTRIBUTE_RES], uiStyle);
    local container = GetContainer(nodeContainerIndex);
    container.LoadChildXML(xmlResources[VARIABLE_RES], uiStyle);
    SubscribeToEvent(container:GetChild("ResetToDefault", true), "Released", "HandleResetToDefault");
    SubscribeToEvent(container:GetChild("NewVarDropDown", true), "ItemSelected", "CreateNodeVariable");
    SubscribeToEvent(container:GetChild("DeleteVarButton", true), "Released", "DeleteNodeVariable");
	componentContainerStartIndex = componentContainerStartIndex + 1;
    return container;
end

--/ Get component container at the specified index, create the container if it is not yet available at the specified index.
function GetComponentContainer(index)
    if (componentContainerStartIndex + index < parentContainer.numChildren) then
        return GetContainer(componentContainerStartIndex + index);
	end

    local container;
	for i = parentContainer.numChildren, componentContainerStartIndex + index - 1 do
        parentContainer:LoadChildXML(xmlResources[ATTRIBUTE_RES], uiStyle);
        container = GetContainer(i);
        SubscribeToEvent(container:GetChild("ResetToDefault", true), "Released", "HandleResetToDefault");
	end
    return container;
end

--/ Get UI-element container, create the container if it is not yet available.
function GetUIElementContainer()
    if (elementContainerIndex ~= M_MAX_UNSIGNED) then
        return GetContainer(elementContainerIndex);
	end

    elementContainerIndex = parentContainer.numChildren;
    parentContainer.LoadChildXML(xmlResources[ATTRIBUTE_RES], uiStyle);
    local container = GetContainer(elementContainerIndex);
	container:LoadChildXML(xmlResources[VARIABLE_RES], uiStyle);
	container:LoadChildXML(xmlResources[STYLE_RES], uiStyle);
    local styleList = container:GetChild("StyleDropDown", true);
    styleList.placeholderText = STRIKED_OUT;
    styleList.parent:GetChild("StyleDropDownLabel"):SetFixedWidth(LABEL_WIDTH);
    PopulateStyleList(styleList);
    SubscribeToEvent(container:GetChild("ResetToDefault", true), "Released", "HandleResetToDefault");
    SubscribeToEvent(container:GetChild("NewVarDropDown", true), "ItemSelected", "CreateUIElementVariable");
    SubscribeToEvent(container:GetChild("DeleteVarButton", true), "Released", "DeleteUIElementVariable");
    SubscribeToEvent(styleList, "ItemSelected", "HandleStyleItemSelected");
    return container;
end

function CreateAttributeInspectorWindow()
    if (attributeInspectorWindow ~= nil) then
        return;
	end

    InitResourcePicker();
    InitVectorStructs();
    InitXMLResources();

    attributeInspectorWindow = LoadEditorUI("UI/EditorInspectorWindow.xml");
    parentContainer = attributeInspectorWindow:GetChild("ParentContainer");
    ui.root.AddChild(attributeInspectorWindow);
    local height = Min(ui.root.height - 60, 500);
    attributeInspectorWindow:SetSize(300, height);
    attributeInspectorWindow:SetPosition(ui.root.width - 10 - attributeInspectorWindow.width, 100);
    attributeInspectorWindow.opacity = uiMaxOpacity;
    attributeInspectorWindow:BringToFront();
    inspectorLockButton = attributeInspectorWindow:GetChild("LockButton", true);

    UpdateAttributeInspector();

    SubscribeToEvent(inspectorLockButton, "Pressed", "ToggleInspectorLock");
    SubscribeToEvent(attributeInspectorWindow:GetChild("CloseButton", true), "Pressed", "HideAttributeInspectorWindow");
    SubscribeToEvent(attributeInspectorWindow, "LayoutUpdated", "HandleWindowLayoutUpdated");
end

function HideAttributeInspectorWindow()
    attributeInspectorWindow.visible = false;
end

function DisableInspectorLock()
    inspectorLocked = false;
    if (inspectorLockButton ~= nil) then
        inspectorLockButton.style = "Button";
	end
    UpdateAttributeInspector(true);
end

function EnableInspectorLock()
    inspectorLocked = true;
    if (inspectorLockButton ~= nil) then
        inspectorLockButton.style = "ToggledButton";
	end
end

function ToggleInspectorLock()
    if (inspectorLocked) then
        DisableInspectorLock();
    else
        EnableInspectorLock();
    end
end

function ShowAttributeInspectorWindow()
    attributeInspectorWindow.visible = true;
    attributeInspectorWindow.BringToFront();
    return true;
end

--/ Handle main window layout updated event by positioning elements that needs manually-positioning (elements that are children of UI-element container with "Free" layout-mode).
function HandleWindowLayoutUpdated()
    -- When window resize and so the list's width is changed, adjust the 'Is enabled' container width and icon panel width so that their children stay at the right most position
    for i = 0, parentContainer.numChildren - 1 do
        local container = GetContainer(i);
        local list = container:GetChild("AttributeList");
        if (list == nil) then
        else
            local width = list.width;

            -- Adjust the icon panel's width
            local panel = container:GetChild("IconsPanel", true);
            if (panel ~= nil) then
                panel.width = width;
            end

            -- At the moment, only 'Is Enabled' container (place-holder + check box) is being created as child of the list view instead of as list item
            for j = 0, list.numChildren - 1 do
                local element = list.children[j];
                if (not element.internal) then
                    element.SetFixedWidth(width);
                    local title = container:GetChild("TitleText");
                    element.position = IntVector2(0, (title.screenPosition - list.screenPosition).y);

                    -- Adjust icon panel's width one more time to cater for the space occupied by 'Is Enabled' check box
                    if (panel ~= nil) then
                        panel.width = width - element.children[1].width - panel.layoutSpacing;
                    end
                    break;
                end
            end
        end
    end
end

function ToSerializableArray(nodes)
    local serializables = {};
    for i = 1, #nodes do
        Push(serializables, nodes[i]);
    end
    return serializables;
end

--/ Update the whole attribute inspector window, when fullUpdate flag is set to true then first delete all the containers and repopulate them again from scratch.
--/ The fullUpdate flag is usually set to true when the structure of the attributes are different than the existing attributes in the list.
function UpdateAttributeInspector(fullUpdate)
    if (fullUpdate == nil) then
        fullUpdate = true;
    end
    if (inspectorLocked) then
        return;
    end

    attributesDirty = false;
    if (fullUpdate) then
        attributesFullDirty = false;
    end

    -- If full update delete all containers and add them back as necessary
    if (fullUpdate) then
        DeleteAllContainers();
    end

    -- Update all ScriptInstances/LuaScriptInstances
    UpdateScriptInstances();

    if (not empty(editNodes)) then
        local container = GetNodeContainer();

        local nodeTitle = container:GetChild("TitleText");
        local nodeType;

        if (editNode ~= nil) then
            local idStr;
            if (editNode.ID >= FIRST_LOCAL_ID) then
                idStr = " (Local ID " .. String(editNode.ID) .. ")";
            else
                idStr = " (ID " .. String(editNode.ID) .. ")";
            end
            nodeType = editNode.typeName;
            nodeTitle.text = nodeType .. idStr;
        else
            nodeType = editNodes[0].typeName;
            nodeTitle.text = nodeType + " (ID " .. STRIKED_OUT .. " : " .. #editNodes .. "x)";
        end 
        IconizeUIElement(nodeTitle, nodeType);

        local list = container:GetChild("AttributeList");
        local nodes = ToSerializableArray(editNodes);
        UpdateAttributes(nodes, list, fullUpdate);

        if (fullUpdate) then
            --\todo Afunction hardcoding
            -- Resize the node editor according to the number of variables, up to a certain maximum
            local maxAttrs = Clamp(list.contentElement.numChildren, MIN_NODE_ATTRIBUTES, MAX_NODE_ATTRIBUTES);
            list:SetFixedHeight(maxAttrs * ATTR_HEIGHT + 2);
            container:SetFixedHeight(maxAttrs * ATTR_HEIGHT + 58);
        end

        -- Set icon's target in the icon panel
        SetAttributeEditorID(container:GetChild("ResetToDefault", true), nodes);
    end 

    if (not empty(editComponents)) then
        local numEditableComponents = editComponents.length / numEditableComponentsPerNode;
        local multiplierText;
        if (numEditableComponents > 1) then
            multiplierText = " (" .. numEditableComponents .. "x)";
        end

        for j = 0, numEditableComponentsPerNode - 1 do
            local container = GetComponentContainer(j);
            local componentTitle = container:GetChild("TitleText");
            componentTitle.text = GetComponentTitle(editComponents[j * numEditableComponents]) .. multiplierText;
            IconizeUIElement(componentTitle, editComponents[j * numEditableComponents].typeName);
            SetIconEnabledColor(componentTitle, editComponents[j * numEditableComponents].enabledEffective);

            local components = {};
            for i = 0, numEditableComponents - 1 do
                local component = editComponents[j * numEditableComponents + i];
                Push(components, component);
            end

            UpdateAttributes(components, container:GetChild("AttributeList"), fullUpdate);
            SetAttributeEditorID(container:GetChild("ResetToDefault", true), components);
        end 
    end

    if (not empty(editUIElements.empty)) then
        local container = GetUIElementContainer();

        local titleText = container:GetChild("TitleText");
        local styleList = container:GetChild("StyleDropDown", true);
        local elementType;

        if (editUIElement ~= nil) then
            elementType = editUIElement.typeName;
            titleText.text = elementType .. " [ID " .. ToString(GetUIElementID(editUIElement)) .. "]";
            SetStyleListSelection(styleList, editUIElement.style);
        else
            elementType = editUIElements[0].typeName;
            local appliedStyle = tolua.cast(editUIElements[0], "UIElement").style;
            local sameType = true;
            local sameStyle = true;
            for i = 1, #editUIElements do
                if (editUIElements[i].typeName ~= elementType) then
                    sameType = false;
                    sameStyle = false;
                    break;
                end

                if (sameStyle and tolua.cast(editUIElements[i],"UIElement").style ~= appliedStyle) then
                    sameStyle = false;
                end
            end
            titleText.text = ifor(sameType , elementType , "Mixed type") .. " [ID " + STRIKED_OUT .. " : " .. #editUIElements .. "x]";
            SetStyleListSelection(SetEditable(styleList, sameStyle), ifor(sameStyle , appliedStyle , STRIKED_OUT));
            if (not sameType) then
                Clear(elementType);   -- No icon
            end
        end
        IconizeUIElement(titleText, elementType);

        UpdateAttributes(editUIElements, container:GetChild("AttributeList"), fullUpdate);
        SetAttributeEditorID(container:GetChild("ResetToDefault", true), editUIElements);
    end

    if (parentContainer.numChildren > 0) then
        UpdateAttributeInspectorIcons();
    else
        -- No editables, insert a dummy component container to show the information
        local titleText = GetComponentContainer(0):GetChild("TitleText");
        titleText.text = "Select editable objects";
        local panel = titleText:GetChild("IconsPanel");
        panel.visible = false;
    end

    -- Adjust size and position of manual-layout UI-elements, e.g. icons panel
    if (fullUpdate) then
        HandleWindowLayoutUpdated();
    end
end

function UpdateScriptInstances()
    local components = GetScene():GetComponents("ScriptInstance", true);
    for i = 1, #components do
        UpdateScriptAttributes(components[i]);
    end

    components = GetScene():GetComponents("LuaScriptInstance", true);
    for i = 1, #components do
        UpdateScriptAttributes(components[i]);
    end
end

function GetComponentAttributeHash(component, index)
    -- We won't consider the main attributes, as they won't reset when an error occurs.
    if (component.typeName == "ScriptInstance") then
        if (index <= SCRIPTINSTANCE_ATTRIBUTE_IGNORE) then
            return "";
        end
    else
        if (index <= LUASCRIPTINSTANCE_ATTRIBUTE_IGNORE) then
            return "";
        end
    end
    local attributeInfo = component.attributeInfos[index];
    local attribute = component.attributes[index];
    return String(component.ID) .. "-" .. attributeInfo.name .. "-" .. attribute.typeName;
end

function UpdateScriptAttributes(component)
    for i = Min(SCRIPTINSTANCE_ATTRIBUTE_IGNORE, LUASCRIPTINSTANCE_ATTRIBUTE_IGNORE) + 1, component.numAttributes - 1 do
        local attribute = component.attributes[i];
        -- Component/node ID's are always unique within a scene, based on a simple increment.
        -- This makes for a simple method of mapping a components attributes unique and consistent.
        -- We will also use the type name in the hash to be able to recall and differentiate type changes.
        local hash = GetComponentAttributeHash(component, i);
        if (empty(hash)) then
        else

            if (not scriptAttributes:Contains(hash)) then
                -- set the initial value to the default value.
                scriptAttributes[hash] = attribute;
            else
                -- recall the previously stored value
                component.attributes[i] = scriptAttributes[hash];
            end
        end
    end
    component:ApplyAttributes();
end

--/ Update the attribute list of the node container.
function UpdateNodeAttributes()
    local fullUpdate = false;
    UpdateAttributes(ToSerializableArray(editNodes), GetNodeContainer():GetChild("AttributeList"), fullUpdate);
end

--/ Update the icons enabled color based on the internal state of the objects.
--/ For node and component, based on "enabled" property.
--/ For ui-element, based on "visible" property.
function UpdateAttributeInspectorIcons()
    if (empty(editNodes)) then
        local nodeTitle = GetNodeContainer():GetChild("TitleText");
        if (editNode ~= nil) then
            SetIconEnabledColor(nodeTitle, editNode.enabled);
        elseif (#editNodes > 0) then
            local hasSameEnabledState = true;

            for i = 2, #editNodes do
                if (editNodes[i].enabled ~= editNodes[0].enabled) then
                    hasSameEnabledState = false;
                    break;
                end
            end

            SetIconEnabledColor(nodeTitle, editNodes[0].enabled, not hasSameEnabledState);
        end
    end

    if (not empty(editComponents)) then
        local numEditableComponents = editComponents.length / numEditableComponentsPerNode;

        for j = 1, numEditableComponentsPerNode do
            local componentTitle = GetComponentContainer(j):GetChild("TitleText");

            local enabledEffective = editComponents[j * numEditableComponents].enabledEffective;
            local hasSameEnabledState = true;
            for i = 1, numEditableComponents - 1 do
                if (editComponents[j * numEditableComponents + i].enabledEffective ~= enabledEffective) then
                    hasSameEnabledState = false;
                    break;
                end
            end

            SetIconEnabledColor(componentTitle, enabledEffective, not hasSameEnabledState);
        end
    end
    
    if (not empty(editUIElements)) then
        local elementTitle = GetUIElementContainer():GetChild("TitleText");
        if (editUIElement ~= nil) then
            SetIconEnabledColor(elementTitle, editUIElement.visible);
        elseif (#editUIElements > 0) then
            local hasSameVisibleState = true;
            local visible = tolua.cast(editUIElements[0], "UIElement").visible;

            for i = 2, #editUIElements - 1 do
                if (tolua.cast(editUIElements[i], "UIElement").visible ~= visible) then
                    hasSameVisibleState = false;
                    break;
                end 
            end

            SetIconEnabledColor(elementTitle, visible, not hasSameVisibleState);
        end
    end
end

--/ Return true if the edit attribute action should continue.
function PreEditAttribute(serializables, index)
    return true;
end

--/ Call after the attribute values in the target serializables have been edited. 
function PostEditAttribute(serializables, index, oldValues)
    -- Create undo actions for the edits
    local group = EditActionGroup:new();
    for i = 1, #serializables do
        local action = EditAttributeAction:new();
        action:Define(serializables[i], index, oldValues[i]);
        Push(group.actions, action);
    end
    SaveEditActionGroup(group);

    -- If a UI-element changing its 'Is Modal' attribute, clear the hierarchy list selection
    local itemType = GetType(serializables[0]);
    if (itemType == ITEM_UI_ELEMENT and serializables[0].attributeInfos[index].name == "Is Modal") then
        hierarchyList.ClearSelection();
    end

    for i = 1, #serializables do
        PostEditAttribute(serializables[i], index);
        if (itemType == ITEM_UI_ELEMENT) then
            SetUIElementModified(serializables[i]);
        end
    end

    if (itemType ~= ITEM_UI_ELEMENT) then
        SetSceneModified();
    end
end

--/ Call after the attribute values in the target serializables have been edited. 
function PostEditAttribute(serializable, index)
    -- If a StaticModel/AnimatedModel/Skybox model was changed, apply a possibly different material list
    if (applyMaterialList and serializable.attributeInfos[index].name == "Model") then
        local staticModel = tolua.cast(serializable, "StaticModel");
        if (staticModel ~= nil) then
            staticModel:ApplyMaterialList();
        end
    end
end

--/ Store the IDs of the actual serializable objects into user-defined variable of the 'attribute editor' (e.g. line-edit, drop-down-list, etc).
function SetAttributeEditorID(attrEdit, serializables)
    if (serializables == nil or #serializables == 0) then
        return;
    end

    -- All target serializables must be either nodes, ui-elements, or components
    local ids = {};
    local tp = GetType(serializables[1]);

    if (tp == ITEM_NODE) then
        for i = 1, #serializables do 
            Push(ids, tolua.cast(serializables[i], "Node").id);
        end
        attrEdit:SetVar(NODE_IDS_VAR, Variant(ids));

    elseif (tp == ITEM_COMPONENT) then
        for i = 1, #serializables do
            Push(ids, tolua.cast(serializables[i], "Component").id);
        end
        attrEdit:SetVar(COMPONENT_IDS_VAR, Variant(ids));

    elseif (tp == ITEM_UI_ELEMENT) then
        for i = 1, #serializables do
            Push(ids, GetUIElementID(tolua.cast(serializables[i], "UIElement")));
        end
        attrEdit:SetVar(UI_ELEMENT_IDS_VAR, Variant(ids));
    end
end

--/ Return the actual serializable objects based on the IDs stored in the user-defined variable of the 'attribute editor'.
function GetAttributeEditorTargets(attrEdit)
    local ret = {};
    local variant = attrEdit:GetVar(NODE_IDS_VAR);
    if (not empty(variant)) then
        local ids = variant:GetVariantVector();
        for i = 1, #ids do
            local node = editorScene:GetNode(ids[i].GetUInt());
            if (node ~= nil) then
                Push(ret, node);
            end
        end
    else
        variant = attrEdit:GetVar(COMPONENT_IDS_VAR);
        if (not variant.empty) then
            local ids = variant:GetVariantVector();
            for i = 1, #ids do
                local component = editorScene:GetComponent(ids[i]:GetUInt());
                if (component ~= nil) then
                    Push(ret, component);
                end
            end
        else
            variant = attrEdit:GetVar(UI_ELEMENT_IDS_VAR);
            if (not variant.empty) then
                local ids = variant.GetVariantVector();
                for i = 1, #ids do
                    local element = editorUIElement:GetChild(UI_ELEMENT_ID_VAR, ids[i], true);
                    if (element ~= nil) then
                        Push(ret, element);
                    end
                end
            end
        end
    end

    return ret;
end

--/ Handle reset to default event, sent when reset icon in the icon-panel is clicked.
function HandleResetToDefault(eventType, eventData)
    ui.cursor.shape = CS_BUSY;

    local button = eventData["Element"]:GetPtr();
    local serializables = GetAttributeEditorTargets(button);
    if (empty(serializables)) then
        return;
    end

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Reset target serializables to their default values
    for i = 1, #serializables do
        local target = serializables[i];

        local action = ResetAttributesAction:new();
        action:Define(target);
        Push(group.actions, action);

        target:ResetToDefault();
        if (action.targetType == ITEM_UI_ELEMENT) then
            action:SetInternalVars(target);
            SetUIElementModified(target);
        end
        target:ApplyAttributes();

        for i = 0, target.numAttributes - 1 do
            PostEditAttribute(target, j);
        end
    end

    SaveEditActionGroup(group);
    if (GetType(serializables[0]) ~= ITEM_UI_ELEMENT) then
        SetSceneModified();
    end
    attributesFullDirty = true;
end

--/ Handle create new user-defined variable event for node target. 
function CreateNodeVariable(eventType, eventData)
    if (empty(editNodes)) then
        return;
    end

    local newName = ExtractVariableName(eventData);
    if (empty(newName)) then
        return;
    end

    -- Create scene variable
    editorScene:RegisterVar(newName);
    globalVarNames[newName] = newName;

    local newValue = ExtractVariantType(eventData);

    -- If we overwrite an existing variable, must recreate the attribute-editor(s) for the correct type
    local overwrite = false;
    for i = 1, #editNodes do
        overwrite = overwrite or not editNodes[i]:GetVar(newName):IsEmpty();
        editNodes[i]:SetVar(newName, Variant(newValue));
    end
    if (overwrite) then
        attributesFullDirty = true;
    else
        attributesDirty = true;
    end
end

--/ Handle delete existing user-defined variable event for node target.
function DeleteNodeVariable(eventType, eventData)
    if (empty(editNodes)) then
        return;
    end

    local delName = ExtractVariableName(eventData);
    if (empty(delName)) then
        return;
    end

    -- Note: intentionally do not unregister the variable name here as the same variable name may still be used by other attribute list

    local erased = false;
    for i = 1, #editNodes do
        -- \todo Should first check whether var in question is editable
        erased = editNodes[i]:GetVars():Erase(delName) or erased;
    end
    if (erased) then
        attributesDirty = true;
    end
end

--/ Handle create new user-defined variable event for ui-element target.
function CreateUIElementVariable(eventType, eventData)
    if (empty(editUIElements)) then
        return;
    end

    local newName = ExtractVariableName(eventData);
    if (empty(newName)) then
        return;
    end

    -- Create UIElement variable
    globalVarNames[newName] = newName;

    local newValue = ExtractVariantType(eventData);

    -- If we overwrite an existing variable, must recreate the attribute-editor(s) for the correct type
    local overwrite = false;
    for i = 1, #editUIElements do 
        local element = tolua.cast(editUIElements[i], "UIElement");
        overwrite = overwrite or not element:GetVar(newName):IsEmpty();
        element:SetVar(newName, Variant(newValue));
    end
    if (overwrite) then
        attributesFullDirty = true;
    else
        attributesDirty = true;
    end
end

--/ Handle delete existing user-defined variable event for ui-element target.
function DeleteUIElementVariable(eventType, eventData)
    if (empty(editUIElements)) then
        return;
    end

    local delName = ExtractVariableName(eventData);
    if (empty(delName)) then
        return;
    end

    -- Note: intentionally do not unregister the variable name here as the same variable name may still be used by other attribute list

    local erased = false;
    for i = 1, #editUIElements do
        -- \todo Should first check whether var in question is editable
        erased = tolua.cast(editUIElements[i], "UIElement").vars:Erase(delName) or erased;
    end
    if (erased) then
        attributesDirty = true;
    end
end

function ExtractVariableName(eventData)
    local element = eventData["Element"]:GetPtr();
    local nameEdit = element.parent:GetChild("VarNameEdit");
    return Trimmed(nameEdit.text);
end

function ExtractVariantType(eventData)
    local dropDown = eventData["Element"]:GetPtr();
    local tp = dropDown.selection; 
    if (tp == 0) then
        return Variant(0);
    elseif (tp == 1) then
        return Variant(false);
    elseif (tp == 2) then
        return Variant(0.0);
    elseif (tp == 3) then
        return Variant("");
    elseif (tp == 4) then
        return Variant(Vector3());
    elseif (tp == 5) then
        return Variant(Color());
    end

    return Variant();   -- This should not happen
end

--/ Get back the human-readable variable name from the StringHash.
function GetVarName(hash)
    -- First try to get it from scene
    local name = editorScene:GetVarName(hash);
    -- Then from the global variable reverse mappings
    if (empty(name) and globalVarNames:Contains(hash)) then
        name = ToString(globalVarNames());
    end
    return name;
end

inSetStyleListSelection = false;

--/ Select/highlight the matching style in the style drop-down-list based on specified style. 
function SetStyleListSelection(styleList, style)
    -- Prevent infinite loop upon initial style selection
    inSetStyleListSelection = true;

    local selection = M_MAX_UNSIGNED;
    local styleName = ifor(empty(style), "auto" , style);
    local items = styleList:GetItems();
    for i = 1, #items do
        local element = tolua.cast(items[i], "Text");
        if (element  == nil) then
            --continue;   -- It may be a divider
        else
            if (element.text == styleName) then
                selection = i;
                break;
            end
        end
    end
    styleList.selection = selection;

    inSetStyleListSelection = false;
end

--/ Handle the style change of the target ui-elements event when a new style is picked from the style drop-down-list.
function HandleStyleItemSelected(eventType, eventData)
    if (inSetStyleListSelection or empty(editUIElements)) then
        return;
    end

    ui.cursor.shape = CS_BUSY;

    local styleList = eventData["Element"]:GetPtr();
    local text = tolua.cast(styleList.selectedItem, "Text");
    if (text == nil) then
        return;
    end
    local newStyle = text.text;
    if (newStyle == "auto") then
        Clear(newStyle);
    end

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Apply new style to selected UI-elements
    for i = 1, #editUIElements do
        local element = editUIElements[i];

        local action = ApplyUIElementStyleAction:new() ;
        action:Define(element, newStyle);
        Push(group.actions, action);

        -- Use the Redo() to actually do the action
        action:Redo();
    end

    SaveEditActionGroup(group);
end
