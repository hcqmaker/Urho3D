

editorUIElement = nil;
uiElementDefaultStyle = nil;
availableStyles = {};

editUIElement = nil;
selectedUIElements = {};
editUIElements = {};

uiElementCopyBuffer = {};

suppressUIElementChanges = false;

FILENAME_VAR = StringHash("FileName");
MODIFIED_VAR = StringHash("Modified");
CHILD_ELEMENT_FILENAME_VAR = StringHash("ChildElemFileName");

function ClearUIElementSelection()
    editUIElement = nil;
    selectedUIElements = {};
    editUIElements = {};
end


function CreateRootUIElement()
	editorUIElement = ui.root:CreateChild("UIElement");
    editorUIElement.name = "UI";
    editorUIElement:SetSize(graphics.width, graphics.height);
    editorUIElement.traversalMode = TM_DEPTH_FIRST;
    editorUIElement.priority = -1000;

    editorUIElement.elementEventSender = true;
    --SubscribeToEvent(editorUIElement, "ElementAdded", "HandleUIElementAdded");
    --SubscribeToEvent(editorUIElement, "ElementRemoved", "HandleUIElementRemoved");

    --UpdateHierarchyItem(M_MAX_UNSIGNED, editorUIElement, null);
end

function NewUIElement(typeName)
    -- If no edit element then parented to root
    local parent = ifor(editUIElement ~= nil , editUIElement , editorUIElement);
    local element = parent:CreateChild(typeName);
    if (element ~= nil) then
        -- Use the predefined UI style if set, otherwise use editor's own UI style
        local defaultStyle = ifor(uiElementDefaultStyle ~= nil , uiElementDefaultStyle , uiStyle);

        if (editUIElement == nil) then
            -- If parented to root, set the internal variables
            element:GetVars():SetString(FILENAME_VAR, "");
			element:GetVars():SetBool(MODIFIED_VAR, false);
            -- set a default UI style
            element.defaultStyle = defaultStyle;
            -- and position the newly created element at center
            CenterDialog(element);
		end
        -- Apply the auto style
        element.style = AUTO_STYLE;
        -- Do not allow UI subsystem to reorder children while editing the element in the editor
        element.sortChildren = false;

        -- Create an undo action for the create
        local action = CreateUIElementAction:new();
        action.Define(element);
        SaveEditAction(action);
        SetUIElementModified(element);

        FocusUIElement(element);
	end
    return true;
end
function ResetSortChildren(element)
    element.sortChildren = false;

    -- Perform the action recursively for child elements
	for i = 0, element.numChildren-1 do
        ResetSortChildren(element.children[i]);
	end
end

function OpenUILayout(fileName)
    if (empty(fileName)) then
        return;
	end

    ui.cursor.shape = CS_BUSY;

    -- Check if the UI element has been opened before
    if (editorUIElement:GetChild(FILENAME_VAR, Variant(fileName)) ~= nil) then
        MessageBox("UI element is already opened.\n" + fileName);
        return;
	end

    -- Always load from the filesystem, not from resource paths
    if (not fileSystem:FileExists(fileName)) then
        MessageBox("No such file.\n" .. fileName);
        return;
	end

    local file = File(fileName, FILE_READ);
    if (not file.open) then
        MessageBox("Could not open file.\n" .. fileName);
        return;
	end

    -- Add the UI layout's resource path in case it's necessary
    SetResourcePath(GetPath(fileName), true, true);

    local xmlFile = XMLFile:new();
	xmlFile:Load(file);

    suppressUIElementChanges = true;

    -- If uiElementDefaultStyle is not set then automatically fallback to use the editor's own default style
    local element = ui.LoadLayout(xmlFile, uiElementDefaultStyle);
    if (element ~= nil) then
        element:GetVars():SetString(FILENAME_VAR , fileName);
		element:GetVars():SetBool(MODIFIED_VAR, false);

        -- Do not allow UI subsystem to reorder children while editing the element in the editor
        ResetSortChildren(element);
        -- Register variable names from the 'enriched' XMLElement, if any
        RegisterUIElementVar(xmlFile.root);

		editorUIElement:AddChild(element);

        UpdateHierarchyItem(element);
        FocusUIElement(element);

        ClearEditActions();
    else
        MessageBox("Could not load UI layout successfully!\nSee Urho3D.log for more detail.");
	end

    suppressUIElementChanges = false;
end

function CloseUILayout()
    ui.cursor.shape = CS_BUSY;

    if (messageBoxCallback == nil) then
		for i = 1, #selectedUIElements do
            local element = GetTopLevelUIElement(selectedUIElements[i]);
            if (element ~= nil and element:GetVars():GetBool(MODIFIED_VAR)) then
                local messageBox = MessageBox("UI layout has been modified.\nContinue to close?", "Warning");
                if (messageBox.window ~= nil) then
                    local cancelButton = messageBox.window:GetChild("CancelButton", true);
                    cancelButton.visible = true;
                    cancelButton.focus = true;
                    SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement");
                    messageBoxCallback = CloseUILayout;
                    return false;
				end
			end
		end
    else
        messageBoxCallback = nil;
	end

    suppressUIElementChanges = true;
	for i = 1, #selectedUIElements do
        local element = GetTopLevelUIElement(selectedUIElements[i]);
        if (element ~= nil) then
            element:Remove();
            UpdateHierarchyItem(GetListIndex(element), nil, nil);
		end
	end
    hierarchyList:ClearSelection();
    ClearEditActions();

    suppressUIElementChanges = false;

    return true;
end

function CloseAllUILayouts()
    ui.cursor.shape = CS_BUSY;

    if (messageBoxCallback == nil) then
		for i = 0, editorUIElement.numChildren - 1 do
            local element = editorUIElement.children[i];
            if (element ~= nil and element:GetVars():GetBool(MODIFIED_VAR)) then
                local messageBox = MessageBox("UI layout has been modified.\nContinue to close?", "Warning");
                if (messageBox.window ~= nil) then
                    local cancelButton = messageBox.window:GetChild("CancelButton", true);
                    cancelButton.visible = true;
                    cancelButton.focus = true;
                    SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement");
                    messageBoxCallback = CloseAllUILayouts;
                    return false;
				end
			end
		end
    else
        messageBoxCallback = nil;
	end

    suppressUIElementChanges = true;

	editorUIElement:RemoveAllChildren();
    UpdateHierarchyItem(editorUIElement, true);

    -- Reset element ID number generator
    uiElementNextID = UI_ELEMENT_BASE_ID + 1;

	hierarchyList:ClearSelection();
    ClearEditActions();

    suppressUIElementChanges = false;

    return true;
end

function SaveUILayout(fileName)
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

    local element = GetTopLevelUIElement(editUIElement);
    if (element == nil) then
        return false;
	end

    local elementData = XMLFile:new();
    local rootElem = elementData:CreateRoot("element");
    local success = element:SaveXML(rootElem);
    RemoveBackup(success, fileName);

    if (success) then
        FilterInternalVars(rootElem);
        success = elementData:Save(file);
        if (success) then
			element:GetVars():SetString(FILENAME_VAR, fileName);
            SetUIElementModified(element, false);
		end
	end
    if (not success) then
        MessageBox("Could not save UI layout successfully!\nSee Urho3D.log for more detail.");
	end

    return success;
end

function SaveUILayoutWithExistingName()
    ui.cursor.shape = CS_BUSY;

    local element = GetTopLevelUIElement(editUIElement);
    if (element == nil) then
        return false;
	end

    local fileName = element:GetVars():GetString(FILENAME_VAR)
    if (empty(fileName)) then
        return PickFile();  -- No name yet, so pick one
    else
        return SaveUILayout(fileName);
	end
end

function LoadChildUIElement(fileName)
    if (empty(fileName)) then
        return;
	end

    ui.cursor.shape = CS_BUSY;

    if (not fileSystem:FileExists(fileName)) then
        MessageBox("No such file.\n" .. fileName);
        return;
	end

    local file = File(fileName, FILE_READ);
    if (not file.open) then
        MessageBox("Could not open file.\n" .. fileName);
        return;
	end

    local xmlFile = XMLFile:new();
	xmlFile:Load(file);

    suppressUIElementChanges = true;

    if (editUIElement:LoadChildXML(xmlFile, ifor(uiElementDefaultStyle ~= nil,  uiElementDefaultStyle , uiStyle))) then
        local rootElem = xmlFile.root;
        local index = ifor(rootElem:HasAttribute("index") , rootElem:GetUInt("index") , editUIElement.numChildren - 1);
        local element = editUIElement.children[index];
        ResetSortChildren(element);
        RegisterUIElementVar(xmlFile.root);
		element:GetVars():SetString(CHILD_ELEMENT_FILENAME_VAR, fileName);
        if (index == editUIElement.numChildren - 1) then
            UpdateHierarchyItem(element);
        else
            -- If not last child, find the list index of the next sibling as the insertion index
            UpdateHierarchyItem(GetListIndex(editUIElement.children[index + 1]), element, hierarchyList.items[GetListIndex(editUIElement)]);
		end
        SetUIElementModified(element);

        -- Create an undo action for the load
        local action = CreateUIElementAction:new();
        action.Define(element);
        SaveEditAction(action);

        FocusUIElement(element);
	end

    suppressUIElementChanges = false;
end

function SaveChildUIElement(fileName)
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

    local elementData = XMLFile:new();
    local rootElem = elementData:CreateRoot("element");
    local success = editUIElement:SaveXML(rootElem);
    RemoveBackup(success, fileName);
    
    if (success) then
        FilterInternalVars(rootElem);
        success = elementData:Save(file);
        if (success) then
            editUIElement:GetVars():SetString(CHILD_ELEMENT_FILENAME_VAR, fileName);
		end
	end
    if (not success) then
        MessageBox("Could not save child UI element successfully!\nSee Urho3D.log for more detail.");
	end

    return success;
end

function SetUIElementDefaultStyle(fileName)
    if (empty(fileName)) then
        return;
	end

    ui.cursor.shape = CS_BUSY;

    -- Always load from the filesystem, not from resource paths
    if (not fileSystem:FileExists(fileName)) then
        MessageBox("No such file.\n" .. fileName);
        return;
	end

    local file = File(fileName, FILE_READ);
    if (not file.open) then
        MessageBox("Could not open file.\n" .. fileName);
        return;
	end

    uiElementDefaultStyle = XMLFile:new();
	uiElementDefaultStyle:Load(file);

    -- Remove the existing style list to ensure it gets repopulated again with the new default style file
    Clear(availableStyles);

    -- Refresh Attribute Inspector when it is currently showing attributes of UI-element item type as the existing styles in the style drop down list are not valid anymore
    if (not editUIElements.empty) then
        attributesFullDirty = true;
	end
end

-- Prepare XPath query object only once and use it multiple times
filterInternalVarsQuery = XPathQuery("--attribute[@name='Variables']/variant");

function FilterInternalVars(source)
    local resultSet = filterInternalVarsQuery:Evaluate(source);
    local resultElem = resultSet.firstResult;
    while (resultElem.notNull) do 
        local name = GetVarName(resultElem:GetUInt("hash"));
        if (empty(name)) then
            local parent = resultElem.parent;

            -- If variable name is empty (or unregistered) then it is an internal variable and should be removed
            if (parent:RemoveChild(resultElem)) then
                -- If parent does not have any children anymore then remove the parent also
                if (not parent:HasChild("variant")) then
                    parent.parent.RemoveChild(parent);
				end
			end
        else
            -- If it is registered then it is a user-defined variable, so 'enrich' the XMLElement to store the variable name in plaintext
            resultElem:SetAttribute("name", name);
		end
        resultElem = resultElem.nextResult;
	end
end

local registerUIElemenVarsQuery = XPathQuery("--attribute[@name='Variables']/variant/@name");

function RegisterUIElementVar(source)
    local resultSet = registerUIElemenVarsQuery:Evaluate(source);
    local resultAttr = resultSet.firstResult;  -- Since we are selecting attribute, the resultset is in attribute context
    while (resultAttr.notNull) do
        local name = resultAttr:GetAttribute();
        globalVarNames[name] = name;
        resultAttr = resultAttr.nextResult;
	end
end

function  GetTopLevelUIElement(element)
    -- Only top level UI-element contains the FILENAME_VAR
    while (element ~= nil and not element:GetVars():Contains(FILENAME_VAR)) do
        element = element.parent;
	end
    return element;
end

function SetUIElementModified(element, flag)
	if (flag == nil) then
		flag = true;
	end
    element = GetTopLevelUIElement(element);
    if (element ~= nil and element:GetVars():GetBool(MODIFIED_VAR) ~= flag) then
        element:GetVars():SetBool(MODIFIED_VAR, flag);
        UpdateHierarchyItemText(GetListIndex(element), element.visible, GetUIElementTitle(element));
	end
end

local availableStylesXPathQuery = XPathQuery("/elements/element[@auto='false']/@type");

function GetAvailableStyles()
    -- Use the predefined UI style if set, otherwise use editor's own UI style
    local defaultStyle = ifor(uiElementDefaultStyle ~= nil , uiElementDefaultStyle , uiStyle);
    local rootElem = defaultStyle.root;
    local resultSet = availableStylesXPathQuery:Evaluate(rootElem);
    local resultElem = resultSet.firstResult;
    while (resultElem.notNull) do
        Push(availableStyles, resultElem:GetAttribute());
        resultElem = resultElem.nextResult;
	end

    Sort(availableStyles);
end

function PopulateStyleList(styleList)
    if (#availableStyles == 0) then
        GetAvailableStyles();
	end

	for i = 1, #availableStyles do
        local choice = Text:new();
        styleList.AddItem(choice);
        choice.style = "EditorEnumAttributeText";
        choice.text = availableStyles[i];
	end
end

function UIElementCut()
    return UIElementCopy() and UIElementDelete();
end

function UIElementCopy()
    ui.cursor.shape = CS_BUSY;

    Clear(uiElementCopyBuffer);
	for i = 1, #selectedUIElements do
        local xml = XMLFile:new();
        local rootElem = xml:CreateRoot("element");
        selectedUIElements[i]:SaveXML(rootElem);
        Push(uiElementCopyBuffer,xml);
	end

    return true;
end

function ResetDuplicateID(element)
    -- If it is a duplicate copy then the element ID need to be regenerated by resetting it now to empty
    if (GetListIndex(element) ~= NO_ITEM) then
        element:SetVar(UI_ELEMENT_ID_VAR, Variant());

        -- Perform the action recursively for child elements
        for i = 0, element.numChildren do
            ResetDuplicateID(element.children[i]);
        end
    end
end

function UIElementPaste(duplication)
	if (duplication == nil) then
		duplication = false;
	end
    ui.cursor.shape = CS_BUSY;

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Have to update manually because the element ID var is not set yet when the E_ELEMENTADDED event is sent
    suppressUIElementChanges = true;

	for i = 1, #uiElementCopyBuffer do
        local rootElem = uiElementCopyBuffer[i].root;
        local pasteElement;

        if (not duplication) then
            pasteElement = editUIElement;
        else
            if (editUIElement.parent ~= nil) then
                pasteElement = editUIElement.parent;
            else
                pasteElement = editUIElement;
			end
		end

        if (pasteElement:LoadChildXML(rootElem, nil)) then
            local element = pasteElement:GetChildren()[pasteElement:GetNumChildren()];

            ResetDuplicateID(element);
            UpdateHierarchyItem(element);
            SetUIElementModified(pasteElement);

            -- Create an undo action
            local action = CreateUIElementAction:new();
			action:Define(element);
            Push(group.actions, action);
		end
	end

    SaveEditActionGroup(group);

    suppressUIElementChanges = false;

    return true;
end

function UIElementDuplicate()
    ui.cursor.shape = CS_BUSY;

    local copy = uiElementCopyBuffer;
    UIElementCopy();
    UIElementPaste(true);
    uiElementCopyBuffer = copy;

    return true;
end

function UIElementDelete()
    ui.cursor.shape = CS_BUSY;

    BeginSelectionModify();

    -- Clear the selection now to prevent deleted elements from being reselected
    hierarchyList:ClearSelection();

    -- Group for storing undo actions
    local group = EditActionGroup:new();
	for i = 1, #selectedUIElements do
        local element = selectedUIElements[i];
        if (element.parent ~= nil) then
            --continue; -- Already deleted

            local index = GetListIndex(element);

            -- Create undo action
            local action = DeleteUIElementAction:new();
            action:Define(element);
            Push(group.actions, action);

            SetUIElementModified(element);
            element:Remove();

            -- If deleting only one element, select the next item in the same index
            if (selectedUIElements.length == 1) then
                hierarchyList.selection = index;
            end
		end
	end

    SaveEditActionGroup(group);

    EndSelectionModify();
    return true;
end

function UIElementSelectAll()
    BeginSelectionModify();
    local indices = {};
    local baseIndex = GetListIndex(editorUIElement);
    Push(indices, baseIndex);
    local baseIndent = hierarchyList.items[baseIndex].indent;
	for i = baseIndex + 1, hierarchyList.numItems - 1 do
        if (hierarchyList.items[i].indent <= baseIndent) then
            break;
		end
       Push(indices, i);
	end 
    hierarchyList:SetSelections(indices);
    EndSelectionModify();

    return true;
end

function UIElementResetToDefault()
    ui.cursor.shape = CS_BUSY;

    -- Group for storing undo actions
    local group = EditActionGroup:new();

    -- Reset selected elements to their default values
	for i = 1, #selectedUIElements do
        local element = selectedUIElements[i];

        local action = ResetAttributesAction:new();
		action:Define(element);
        Push(group.actions, action);

		element:ResetToDefault();
		action:SetInternalVars(element);
		element:ApplyAttributes();
		for j = 0, element.numAttributes-1 do
            PostEditAttribute(element, j);
		end
        SetUIElementModified(element);
	end

    SaveEditActionGroup(group);
    attributesFullDirty = true;

    return true;
end

function UIElementChangeParent(sourceElement, targetElement)
    local action = ReparentUIElementAction:new();
	action:Define(sourceElement, targetElement);
    SaveEditAction(action);

    sourceElement.parent = targetElement;
    SetUIElementModified(targetElement);
	return sourceElement.parent == targetElement;
end

