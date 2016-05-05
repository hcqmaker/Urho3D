
ITEM_NONE = 0;
ITEM_NODE = 1;
ITEM_COMPONENT = 2;
ITEM_UI_ELEMENT = 3;
NO_ITEM = M_MAX_UNSIGNED;
SCENE_TYPE = StringHash("Scene");
NODE_TYPE = StringHash("Node");
STATICMODEL_TYPE = StringHash("StaticModel");
ANIMATEDMODEL_TYPE = StringHash("AnimatedModel");
STATICMODELGROUP_TYPE = StringHash("StaticModelGroup");
SPLINEPATH_TYPE = StringHash("SplinePath");
CONSTRAINT_TYPE = StringHash("Constraint");
NO_CHANGE = String("0");
TYPE_VAR = StringHash("Type");
NODE_ID_VAR = StringHash("NodeID");
COMPONENT_ID_VAR = StringHash("ComponentID");
UI_ELEMENT_ID_VAR = StringHash("UIElementID");
DRAGDROPCONTENT_VAR = StringHash("DragDropContent");
ID_VARS =  {StringHash(""), NODE_ID_VAR, COMPONENT_ID_VAR, UI_ELEMENT_ID_VAR};
nodeTextColor = Color(1.0, 1.0, 1.0);
componentTextColor = Color(0.7, 1.0, 0.7);

UI_ELEMENT_BASE_ID = 1;
uiElementNextID = UI_ELEMENT_BASE_ID;
showInternalUIElement = false;
showTemporaryObject = false;

hierarchyWindow = nil; -- Window
hierarchyList = nil; -- ListView
hierarchyUpdateSelections = {};


function GetUIElementID(element)

    local elementID = element:GetVar(UI_ELEMENT_ID_VAR);
    if (elementID.empty) then
        -- Generate new ID
        elementID = uiElementNextID;
        uiElementNextID = uiElementNextID + 1;
        -- Store the generated ID
        element:SetVar(UI_ELEMENT_ID_VAR, Variant(elementID));
    end

    return elementID;
end

function GetUIElementByID(id)
	if (id == UI_ELEMENT_BASE_ID) then
		return editorUIElement;
	end
	return editorUIElement:GetChild(UI_ELEMENT_ID_VAR, id, true);
end

function CreateHierarchyWindow()
	if (hierarchyWindow ~= nil) then
		return;
	end

	hierarchyWindow = LoadEditorUI("UI/EditorHierarchyWindow.xml");
	hierarchyList = hierarchyWindow:GetChild("HierarchyList");
	ui.root:AddChild(hierarchyWindow);
    
	local height = math.min(ui.root.height - 60, 460);
	hierarchyWindow:SetSize(300, height);
    hierarchyWindow:SetPosition(35, 100);
    hierarchyWindow.opacity = uiMaxOpacity;
    hierarchyWindow:BringToFront();

    UpdateHierarchyItem(editorScene);
    
    hierarchyList.selectOnClickEnd = true;

    hierarchyList.contentElement.dragDropMode = DD_TARGET;
    hierarchyList.scrollPanel.dragDropMode = DD_TARGET;


    --[[TODO
    SubscribeToEvent(hierarchyWindow:GetChild("CloseButton", true), "Released", "HideHierarchyWindow");
    SubscribeToEvent(hierarchyWindow:GetChild("ExpandButton", true), "Released", "ExpandCollapseHierarchy");
    SubscribeToEvent(hierarchyWindow:GetChild("CollapseButton", true), "Released", "ExpandCollapseHierarchy");
    SubscribeToEvent(hierarchyList, "SelectionChanged", "HandleHierarchyListSelectionChange");
    SubscribeToEvent(hierarchyList, "ItemDoubleClicked", "HandleHierarchyListDoubleClick");
    SubscribeToEvent(hierarchyList, "ItemClicked", "HandleHierarchyItemClick");
    SubscribeToEvent("DragDropTest", "HandleDragDropTest");
    SubscribeToEvent("DragDropFinish", "HandleDragDropFinish");
    SubscribeToEvent(editorScene, "NodeAdded", "HandleNodeAdded");
    SubscribeToEvent(editorScene, "NodeRemoved", "HandleNodeRemoved");
    SubscribeToEvent(editorScene, "ComponentAdded", "HandleComponentAdded");
    SubscribeToEvent(editorScene, "ComponentRemoved", "HandleComponentRemoved");
    SubscribeToEvent(editorScene, "NodeNameChanged", "HandleNodeNameChanged");
    SubscribeToEvent(editorScene, "NodeEnabledChanged", "HandleNodeEnabledChanged");
    SubscribeToEvent(editorScene, "ComponentEnabledChanged", "HandleComponentEnabledChanged");
    SubscribeToEvent("TemporaryChanged", "HandleTemporaryChanged");
    --]]
end


function EnableExpandCollapseButtons(enable)
    local buttons =  {"ExpandButton", "CollapseButton", "AllCheckBox" };
    for k, v in ipairs(buttons) do
        local element = hierarchyWindow:GetChild(v, true);
        element.enabled = enable;
        local cr = nonEditableTextColor;
        if (enable) then 
        	cr = normalTextColor;
        end
        element.children[0].color = cr;
    end
end

function ShowHierarchyWindow()
    hierarchyWindow.visible = true;
    hierarchyWindow:BringToFront();
    return true;
end



function UpdateHierarchyItem(serializable, clear)
	print(serializable);
    if (clear == nil) then
        clear = false;
    end
    if (clear) then
        -- Remove the current selection before updating the list item (in turn trigger an update on the attribute editor)
        hierarchyList:ClearSelection();

        -- Clear copybuffer when whole window refreshed
        sceneCopyBuffer:Clear();
        uiElementCopyBuffer:Clear();
   	end

    -- In case of item's parent is not found in the hierarchy list then the item will be inserted at the list root level
    local parent = nil;
    local tp = GetType(serializable);
    if (tp == ITEM_NODE) then
    	parent = tolua.cast(serializable, "Node").parent;
    elseif (tp == ITEM_COMPONENT) then
    	parent = tolua.cast(serializable, "Component").node;
    elseif (tp == ITEM_UI_ELEMENT) then
    	parent = tolua.cast(serializable, "UIElement").parent;
    end

	local parentItem = hierarchyList:GetItem(GetListIndex(parent));
    UpdateHierarchyItem3(GetListIndex(serializable), serializable, parentItem);
end

function UpdateHierarchyItem3(itemIndex, serializable, parentItem)
    -- Whenever we're updating, disable layout update to optimize speed
	hierarchyList.contentElement:DisableLayoutUpdate();
    if (serializable == nil) then
        hierarchyList:RemoveItem(itemIndex);
        hierarchyList.contentElement:EnableLayoutUpdate();
        hierarchyList.contentElement:UpdateLayout();
        return itemIndex;
    end

    local itemType = GetType(serializable);
    local id = GetID(serializable, itemType);

    -- Remove old item if exists
    if (itemIndex < hierarchyList.numItems and MatchID(hierarchyList.items[itemIndex], id, itemType)) then
        hierarchyList:RemoveItem(itemIndex);
    end

    local text = Text:new();
    hierarchyList:InsertItem(itemIndex, text, parentItem);
    text.style = "FileSelectorListText";

    if (serializable.type == SCENE_TYPE and serializable == editorUIElement) then
        -- The root node (scene) and editor's root UIElement cannot be moved by drag and drop
        text.dragDropMode = DD_TARGET;
    else
        -- Internal UIElement is not able to participate in drag and drop action
        text.dragDropMode = itemType == ITEM_UI_ELEMENT and tolua.cast(serializable, "UIElement").internal and DD_DISABLED or DD_SOURCE_AND_TARGET;
    end
	print("------------------xxxx4");
    -- Advance the index for the child items
    if (itemIndex == M_MAX_UNSIGNED) then
        itemIndex = hierarchyList.numItems;
    else
        itemIndex = itemIndex + 1;
    end

    local iconType = serializable.typeName;
    if (serializable == editorUIElement) then
        iconType = "Root" .. iconType;
    end
    IconizeUIElement(text, iconType);
	print("------------------xxxx5");
    SetID(text, serializable, itemType);
    if (itemType == ITEM_NODE) then
    	local node = tolua.cast(serializable, "Node");
        text.text = GetNodeTitle(node);
        text.color = nodeTextColor;
        SetIconEnabledColor(text, node.enabled);

        local numComponents = node.numComponents;

        -- Update components first
        for i = 0, numComponents - 1 do
        	local component = node.components[i];
            if (showTemporaryObject and not component.temporary) then
                AddComponentItem(itemIndex, component, text);
                itemIndex = itemIndex + 1;
            end
        end
        
        -- Then update child nodes recursively
        for i = 0, numComponents - 1 do
        	local childNode = node.children[i];
            if (showTemporaryObject or not childNode.temporary) then
                itemIndex = UpdateHierarchyItem3(itemIndex, childNode, text);
            end
        end
    elseif (itemType == ITEM_COMPONENT) then
    	local component = tolua.cast(serializable, "Component");
        text.text = GetComponentTitle(component);
        text.color = componentTextColor;
        SetIconEnabledColor(text, component.enabledEffective);
   	elseif (itemType == ITEM_UI_ELEMENT) then
   		local element = tolua.cast(serializable, "UIElement");
        text.text = GetUIElementTitle(element);
        SetIconEnabledColor(text, element.visible);
        -- Update child elements recursively
        local numChildren = element.numChildren;
        for i = 0, numChildren-1 do
        	local childElement = element.children[i];
            if ((showInternalUIElement or not childElement.internal) and (showTemporaryObject or not childElement.temporary)) then
                itemIndex = UpdateHierarchyItem3(itemIndex, childElement, text);
            end
        end

   	end
	print("------------------xxxx8");
    -- Re-enable layout update (and do manual layout) now
    hierarchyList.contentElement:EnableLayoutUpdate();
    print("------------------xxxx9");
    hierarchyList.contentElement:UpdateLayout();
    print("------------------xxxx10");
    return itemIndex;
end


function UpdateHierarchyItemText(itemIndex, iconEnabled, textTitle)
	if (textTitle == nil) then
		textTitle = NO_CHANGE;
	end

    local text = hierarchyList.items[itemIndex];
    if (text == nil) then
        return;
    end

    SetIconEnabledColor(text, iconEnabled);

    if (textTitle ~= NO_CHANGE) then
        text.text = textTitle;
    end
end


function AddComponentItem(compItemIndex, component, parentItem)
    local text = Text:new();
    hierarchyList:InsertItem(compItemIndex, text, parentItem);
    text.style = "FileSelectorListText";
    text:SetVar(TYPE_VAR, Variant(ITEM_COMPONENT));
    text:SetVar(NODE_ID_VAR, Variant(component.node.ID));
    text:SetVar(COMPONENT_ID_VAR, Variant(component.ID));
    text.text = GetComponentTitle(component);
    text.color = componentTextColor;
    -- Components currently act only as drag targets
    text.dragDropMode = DD_TARGET;

    IconizeUIElement(text, component.typeName);
    SetIconEnabledColor(text, component.enabledEffective);
end

function GetType(serializable)
    if (tolua.cast(serializable, "Node") ~= nil) then
        return ITEM_NODE;
    elseif (tolua.cast(serializable, "Component") ~= nil) then
        return ITEM_COMPONENT;
    elseif (tolua.cast(serializable, "UIElement") ~= nil) then
        return ITEM_UI_ELEMENT;
    else
        return ITEM_NONE;
    end
end


function SetID(text, serializable, itemType)
	if (itemType == nil) then
		itemType = ITEM_NONE;
	end
    -- If item type is not provided, auto detect it
    if (itemType == ITEM_NONE) then
        itemType = GetType(serializable);
    end

    text:SetVar(TYPE_VAR, Variant(itemType));
    text:SetVar(ID_VARS[itemType], Variant(GetID(serializable, itemType)));

    -- Set node ID as drag and drop content for node ID editing
    if (itemType == ITEM_NODE) then
        text:SetVar(DRAGDROPCONTENT_VAR, Variant(String(text:GetVar(NODE_ID_VAR):GetUInt())));
    end

    if (itemType == ITEM_COMPONENT) then
    	text:SetVar(NODE_ID_VAR, Variant(tolua.cast(serializable, "Component").node.ID));
    elseif (itemType == ITEM_UI_ELEMENT) then
    	SubscribeToEvent(serializable, "NameChanged", "HandleElementNameChanged");
        SubscribeToEvent(serializable, "VisibleChanged", "HandleElementVisibilityChanged");
        SubscribeToEvent(serializable, "Resized", "HandleElementAttributeChanged");
        SubscribeToEvent(serializable, "Positioned", "HandleElementAttributeChanged");
    end
end


function GetID(serializable, itemType)
	itemType = itemType == nil and ITEM_NONE or ITEM_NONE;
    -- If item type is not provided, auto detect it
    if (itemType == ITEM_NONE) then
        itemType = GetType(serializable);
    end
    if (itemType == ITEM_NODE) then
    	return tolua.cast(serializable,"Node").id
    elseif (itemType == ITEM_COMPONENT) then
    	return tolua.cast(serializable,"Component").id
    elseif (itemType == ITEM_UI_ELEMENT) then
    	return GetUIElementID(tolua.cast(serializable, "UIElement")):GetUInt();
    end

    return M_MAX_UNSIGNED;
end

function MatchID(element, id, itemType)
    return element:GetVar(TYPE_VAR):GetInt() == itemType and element:GetVar(ID_VARS[itemType]) == id;
end


function GetListIndex(serializable)

    if (serializable == nil) then
        return NO_ITEM;
    end

    local itemType = GetType(serializable);
    local id = GetID(serializable, itemType);

    local numItems = hierarchyList.numItems;
    for i = 0,numItems-1 do
        if (MatchID(hierarchyList.items[i], id, itemType)) then
            return i;
        end
    end

    return NO_ITEM;
end


function GetListUIElement(index)

    local item = hierarchyList.items[index];
    if (item == nil) then
        return nil;
    end

    -- Get the text item's ID and use it to retrieve the actual UIElement the text item is associated to
    return GetUIElementByID(GetUIElementID(item));
end

function GetListNode(index)
    local item = hierarchyList.items[index];
    if (item == nil) then
        return nil;
    end

    return editorScene:GetNode(item:GetVar(NODE_ID_VAR):GetUInt());
end

function GetListComponentIndex(index)
    local item = hierarchyList.items[index];
    return GetListComponentItem(item);
end

function GetListComponentItem(item)
    if (item == nil) then
        return nil;
    end

    if (item:GetVar(TYPE_VAR):GetInt() ~= ITEM_COMPONENT) then
        return nil;
    end

    return editorScene:GetComponent(item:GetVar(COMPONENT_ID_VAR):GetUInt());
end


function GetComponentListIndex(component)
    if (component == nil) then
        return NO_ITEM;
    end

    local numItems = hierarchyList.numItems;
    for i = 0, numItems do
    	 local item = hierarchyList.items[i];
        if (item:GetVar(TYPE_VAR):GetInt() == ITEM_COMPONENT and item:GetVar(COMPONENT_ID_VAR):GetUInt() == component.ID) then
            return i;
        end
    end
    return NO_ITEM;
end

function GetUIElementTitle(element)
    local ret;

    -- Only top level UI-element has this variable
    local modifiedStr = element:GetVar(MODIFIED_VAR):GetBool() and "*" or "";
    ret = (element.name.empty and element.typeName or element.name)
     ret = ret .. modifiedStr .. " [" .. GetUIElementID(element):ToString() .. "]";

    if (element.temporary) then
        ret = ret .. " (Temp)";
    end

    return ret;
end


function GetNodeTitle(node)
    local ret = '';

    if (node.name.empty) then
        ret = node.typeName;
    else
        ret = node.name;
    end

    if (node.ID >= FIRST_LOCAL_ID) then
        ret = ret .. " (Local " .. node.ID .. ")";
    else
        ret = ret .. " (" .. node.ID .. ")";
    end

    if (node.temporary) then
        ret = ret .. " (Temp)";
    end

    return ret;
end

function GetComponentTitle(component)
    local ret = component.typeName;

    if (component.ID >= FIRST_LOCAL_ID) then
        ret = ret .. " (Local)";
    end
    if (component.temporary) then
        ret = ret .. " (Temp)";
    end
    return ret;
end



function SelectNode(node, multiselect)
    if (node == nil and multiselect == nil) then
        hierarchyList.ClearSelection();
        return;
    end

    local index = GetListIndex(node);
    local numItems = hierarchyList.numItems;

    if (index < numItems) then
        -- Expand the node chain now
        if (not multiselect and not hierarchyListIsSelected(index)) then
            -- Go in the parent chain up to make sure the chain is expanded
            local current = node;
            repeat
                hierarchyList:Expand(GetListIndex(current), true);
                current = current.parent;
            until (current == nil);
        end

        -- This causes an event to be sent, in response we set the node/component selections, and refresh editors
        if (not multiselect) then
            hierarchyList.selection = index;
        else
            hierarchyList:ToggleSelection(index);
        end
    elseif (not multiselect) then
        hierarchyList:ClearSelection();
    end
end


function SelectComponent(component, multiselect)
    if (component == nil and not multiselect) then
        hierarchyList:ClearSelection();
        return;
    end

    local node = component.node;
    if (node == nil and not multiselect) then
        hierarchyList:ClearSelection();
        return;
    end

    local nodeIndex = GetListIndex(node);
    local componentIndex = GetComponentListIndex(component);
    local numItems = hierarchyList.numItems;

    if (nodeIndex < numItems and componentIndex < numItems) then
        -- Expand the node chain now
        if (not multiselect or not hierarchyList:IsSelected(componentIndex)) then
            -- Go in the parent chain up to make sure the chain is expanded
            local current = node;
            repeat
                hierarchyList.Expand(GetListIndex(current), true);
                current = current.parent;
            until (current ~= nil);
        end

        -- This causes an event to be sent, in response we set the node/component selections, and refresh editors
        if (not multiselect) then
            hierarchyList.selection = componentIndex;
        else
            hierarchyList:ToggleSelection(componentIndex);
        end
    elseif (not multiselect) then
        hierarchyList:ClearSelection();
    end
end


function SelectUIElement(element, multiselect)
    local index = GetListIndex(element);
    local numItems = hierarchyList.numItems;

    if (index < numItems) then
        -- Expand the node chain now
        if (not multiselect or not hierarchyList:IsSelected(index)) then
            -- Go in the parent chain up to make sure the chain is expanded
            local current = element;
            repeat
                hierarchyList:Expand(GetListIndex(current), true);
                current = current.parent;
            until (current ~= nil)
        end

        if (not multiselect) then
            hierarchyList.selection = index;
        else
            hierarchyList:ToggleSelection(index);
        end
    elseif (not multiselect) then
        hierarchyList:ClearSelection();
    end
end


function HandleHierarchyListSelectionChange()
	if (inSelectionModify) then
		return;
	end

	ClearSceneSelection();
    ClearUIElementSelection();

    local indices = hierarchyList.selections;
    local num = #indices;
    local hasnum = false;
    if (#indices > 0) then hasnum = true; end
    EnableExpandCollapseButtons(hasnum);

    for i = 0, num-1 do
    	local index = indices[i];
        local item = hierarchyList.items[index];
        local type = item:GetVar(TYPE_VAR):GetInt();
        if (type == ITEM_COMPONENT) then
            local comp = GetListComponentIndex(index);
            if (comp ~= nil) then
                table.insert(selectedComponents, comp);
            end
        elseif (type == ITEM_NODE) then
            local node = GetListNode(index);
            if (node ~= nil) then
                table.insert(selectedNodes, node);
            end
        elseif (type == ITEM_UI_ELEMENT) then
            local element = GetListUIElement(index);
            if (element ~= nil and element ~= editorUIElement) then
            	table.insert(selectedUIElements, element)
            end
        end
    end

    -- If only one node/UIElement selected, use it for editing
    if (#selectedNodes == 1) then
        editNode = selectedNodes[1];
    end
    if (#selectedUIElements == 1) then
        editUIElement = selectedUIElements[1];
    end
    -- If selection contains only components, and they have a common node, use it for editing
    if (#selectedNodes == 0 and #selectedComponents > 0) then
        local commonNode;
        for i, comp in ipairs(selectedComponents) do
        	if (i == 1) then
        		commonNode = comp.node;
        	else
        		if (commonNode ~= comp.node) then
        			commonNode = nil;
        		end
        	end
       	end
       	editNode = commonNode;
    end

    -- Now check if the component(s) can be edited. If many selected, must have same type or have same edit node
    if (#selectedComponents > 0) then
    	if (editNode == nil) then
            local compType = selectedComponents[1].type;
            local sameType = true;
            local num = #selectedComponents - 1;
            for i=2,num do
                if (selectedComponents[i].type ~= compType) then
                    sameType = false;
                    break;
                end
            end
            if (sameType) then
                editComponents = selectedComponents;
            end
        else
            editComponents = selectedComponents;
            numEditableComponentsPerNode = #selectedComponents;
        end
    end

    -- If just nodes selected, and no components, show as many matching components for editing as possible
    if (#selectedNodes > 0 and #selectedComponents == 0 and selectedNodes[1].numComponents > 0) then
        local count = 0;
        for j = 0,selectedNodes[1].numComponents-1 do
        	local compType = selectedNodes[1].components[j].type;
        	local sameType = true;
        	for i = 2,#selectedNodes-1 do
        		if (selectedNodes[i].numComponents <= j and selectedNodes[i].components[j].type ~= compType) then
                    sameType = false;
                    break;
                end
        	end

            if (sameType) then
            	count = count + 1;
            	for i = 1, #selectedNodes do
            		table.insert(editComponents, selectedNodes[i].components[j])
            	end
            end
        end

        for j = 0, selectedNodes[1].numComponents - 1 do
        	local compType = selectedNodes[1].components[j].type;
        	local sameType = true;
        	for i = 2, #selectedNodes do
        		if (selectedNodes[i].numComponents <= j and selectedNodes[i].components[j].type ~= compType) then
                    sameType = false;
                    break;
                end
        	end

            if (sameType) then
            	count = count + 1;
                for i = 1,#selectedNodes do
                	table.insert(editComponents, selectedNodes[i].components[j])
                end
            end
        end

        if (count > 1) then
            numEditableComponentsPerNode = count;
        end
    end

    if (#selectedNodes == 0 and editNode) then
    	table.insert(editNodes, editNode);
    else
        editNodes = selectedNodes;

        -- Cannot multi-edit on scene and node(s) together as scene and node do not share identical attributes,
        -- editing via gizmo does not make too much sense either
        if (#editNodes > 1 and editNodes[1] == editorScene) then
        	table.remove(editNodes, 1);
        end
    end

    if (#selectedUIElements == 0 and editUIElement) then
    	table.insert(editUIElements, editUIElement)
    else
        editUIElements = selectedUIElements;
    end

    PositionGizmo();
    UpdateAttributeInspector();
    UpdateCameraPreview();

end


function HandleHierarchyListDoubleClick(eventType, eventData)
    local item = eventData["Item"]:GetPtr();
    local type = item:GetVar(TYPE_VAR):GetInt()

    -- Locate nodes from the scene by double-clicking
    if (type == ITEM_NODE) then
        local node = editorScene:GetNode(item:GetVar(NODE_ID_VAR):GetUInt());
        LocateNode(node);
    end
end

function HandleHierarchyItemClick(eventType, eventData)
    if (eventData["Button"]:GetInt() ~= MOUSEB_RIGHT) then
        return;
    end

    local uiElement = eventData["Item"]:GetPtr();
    local selectionIndex = eventData["Selection"]:GetInt();

    local actions = {};
    local type = uiElement:GetVar(TYPE_VAR):GetInt();

    -- Adds left clicked items to selection which is not normal listview behavior
    if (type == ITEM_COMPONENT and type == ITEM_NODE) then
        if (input:GetKeyDown(KEY_LSHIFT)) then
            hierarchyList:AddSelection(selectionIndex);
        else
            hierarchyList:ClearSelection();
            hierarchyList:AddSelection(selectionIndex);
        end
    end

    if (type == ITEM_COMPONENT) then
        local targetComponent = editorScene:GetComponent(uiElement:GetVar(COMPONENT_ID_VAR):GetUInt());
        if (targetComponent == nil) then
            return;
        end
        table.insert(actions, CreateContextMenuItem("Copy", "HandleHierarchyContextCopy"))
        table.insert(actions, CreateContextMenuItem("Cut", "HandleHierarchyContextCut"))
        table.insert(actions, CreateContextMenuItem("Delete", "HandleHierarchyContextDelete"))
        table.insert(actions, CreateContextMenuItem("Paste", "HandleHierarchyContextPaste"))
        table.insert(actions, CreateContextMenuItem("Enable/disable", "HandleHierarchyContextEnableDisable"))

        -- actions.Push(CreateBrowserFileActionMenu("Edit", "HandleBrowserEditResource", file));
    elseif (type == ITEM_NODE) then
        table.insert(actions,CreateContextMenuItem("Create Replicated Node", "HandleHierarchyContextCreateReplicatedNode"));
        table.insert(actions,CreateContextMenuItem("Create Local Node", "HandleHierarchyContextCreateLocalNode"));
        table.insert(actions,CreateContextMenuItem("Duplicate", "HandleHierarchyContextDuplicate"));
        table.insert(actions,CreateContextMenuItem("Copy", "HandleHierarchyContextCopy"));
        table.insert(actions,CreateContextMenuItem("Cut", "HandleHierarchyContextCut"));
        table.insert(actions,CreateContextMenuItem("Delete", "HandleHierarchyContextDelete"));
        table.insert(actions,CreateContextMenuItem("Paste", "HandleHierarchyContextPaste")); 
        table.insert(actions,CreateContextMenuItem("Reset to default", "HandleHierarchyContextResetToDefault"));
        table.insert(actions,CreateContextMenuItem("Reset position", "HandleHierarchyContextResetPosition"));
        table.insert(actions,CreateContextMenuItem("Reset rotation", "HandleHierarchyContextResetRotation"));
        table.insert(actions,CreateContextMenuItem("Reset scale", "HandleHierarchyContextResetScale"));
        table.insert(actions,CreateContextMenuItem("Enable/disable", "HandleHierarchyContextEnableDisable"));
        table.insert(actions,CreateContextMenuItem("Unparent", "HandleHierarchyContextUnparent"));
    elseif (type == ITEM_UI_ELEMENT) then
        -- close ui element
        table.insert(actions,CreateContextMenuItem("Close UI-Layout", "HandleHierarchyContextUIElementCloseUILayout"));
        table.insert(actions,CreateContextMenuItem("Close all UI-layouts", "HandleHierarchyContextUIElementCloseAllUILayouts"));
    end

    if (#actions > 0) then
        ActivateContextMenu(actions);
    end
end

function HandleDragDropTest(eventType, eventData)

    local source = eventData["Source"]:GetPtr();
    local target = eventData["Target"]:GetPtr();
    local itemType;
    eventData:SetBool("Accept", TestDragDrop(source, target, itemType));
end

function HandleDragDropFinish(eventType, eventData)
    local source = eventData["Source"]:GetPtr()
    local target = eventData["Target"]:GetPtr();
    local itemType = ITEM_NONE;
    local accept = TestDragDrop(source, target, itemType);
    --eventData["Accept"] = accept;
    eventData:SetBool("Accept",accept);
    if (not accept) then
        return;
    end

    -- resource browser
    if (source ~= nil and source:GetVar(TEXT_VAR_RESOURCE_TYPE):GetInt() > 0) then
        local type = source:GetVar(TEXT_VAR_RESOURCE_TYPE):GetInt();

        local browserFile = GetBrowserFileFromId(source:GetVar(TEXT_VAR_FILE_ID):GetUInt());
        if (browserFile == nil) then
            return;
        end

        local createdComponent;
        if (itemType == ITEM_NODE) then
            local targetNode = editorScene:GetNode(target:GetVar(NODE_ID_VAR):GetUInt());
            if (targetNode == nil) then
                return;
            end

            if (type == RESOURCE_TYPE_PREFAB) then
                LoadNode(browserFile:GetFullPath(), targetNode);
            elseif(type == RESOURCE_TYPE_SCRIPTFILE) then
                -- TODO: not sure what to do here.  lots of choices.
            elseif(type == RESOURCE_TYPE_MODEL) then
                CreateModelWithStaticModel(browserFile.resourceKey, targetNode);
                return;
            elseif (type == RESOURCE_TYPE_PARTICLEEFFECT) then
                if (browserFile.extension == "xml") then
                    local effect = cache:GetResource("ParticleEffect", browserFile.resourceKey);
                    if (effect == nil) then
                        return;
                    end

                    local emitter = targetNode:CreateComponent("ParticleEmitter");
                    emitter.effect = effect;
                    createdComponent = emitter;
                end
            elseif (type == RESOURCE_TYPE_2D_PARTICLE_EFFECT) then
                if (browserFile.extension == "xml") then
                    local effect = cache:GetResource("ParticleEffect2D", browserFile.resourceKey);
                    if (effect == nil) then
                        return;
                    end

                    --ResourceRef effectRef;
                    local effectRef = ResourceRef:new();
                    effectRef.type = effect.type;
                    effectRef.name = effect.name;

                    local emitter = targetNode:CreateComponent("ParticleEmitter2D");
                    emitter:SetAttribute("Particle Effect", Variant(effectRef));
                    createdComponent = emitter;
                end
            end
        elseif (itemType == ITEM_COMPONENT) then
            local targetComponent = editorScene:GetComponent(target:GetVar(COMPONENT_ID_VAR):GetUInt());

            if (targetComponent == nil) then
                return;
            end

            if (type == RESOURCE_TYPE_MATERIAL) then
                local model = tolua.cast(targetComponent, "StaticModel");
                if (model == nil) then
                    return;
                end

                AssignMaterial(model, browserFile.resourceKey);
            elseif (type == RESOURCE_TYPE_MODEL) then
                local staticModel = tolua.cast(targetComponent, "StaticModel");
                if (staticModel == nil) then
                    return;
                end
                AssignModel(staticModel, browserFile.resourceKey);
            end
        else
            local text = tolua.cast(target, "LineEdit");
            if (text == nil) then
                return;
            end

            text.text = browserFile.resourceKey;
            --VariantMap data();
            local data = VariantMap:new();
            data["Element"] = text;
            data["Text"] = text.text;
            text:SendEvent("TextFinished", data);
        end

        if (createdComponent ~= nil) then
            CreateLoadedComponent(createdComponent);
		end
        return;
    end

    if (itemType == ITEM_NODE) then
        local targetNode = editorScene:GetNode(target:GetVar(NODE_ID_VAR):GetUInt());

        -- If target is null, parent to scene
        if (targetNode == nil) then
            targetNode = editorScene;
        end

        local sourceNodes = GetMultipleSourceNodes(source);
        if (#sourceNodes > 0) then
            if (#sourceNodes > 1) then
                SceneChangeParent(sourceNodes[0], sourceNodes, targetNode);
            else
                SceneChangeParent(sourceNodes[0], targetNode);
            end

            -- Focus the node at its new position in the list which in turn should trigger a refresh in attribute inspector
            FocusNode(sourceNodes[0]);
        end
    elseif (itemType == ITEM_UI_ELEMENT) then
        local sourceElement = GetUIElementByID(source:GetVar(UI_ELEMENT_ID_VAR):GetUInt());
        local targetElement = GetUIElementByID(target:GetVar(UI_ELEMENT_ID_VAR):GetUInt());

        -- If target is null, cannot proceed
        if (targetElement == nil) then
            return;
        end

        -- Perform the reparenting
        if (not UIElementChangeParent(sourceElement, targetElement)) then
            return;
       	end

        -- Focus the element at its new position in the list which in turn should trigger a refresh in attribute inspector
        FocusUIElement(sourceElement);
    
    elseif (itemType == ITEM_COMPONENT) then
    
        local sourceNodes = GetMultipleSourceNodes(source);
        local targetComponent = editorScene:GetComponent(target:GetVar(COMPONENT_ID_VAR):GetUInt());
        if (targetComponent ~= nil and sourceNodes.length > 0) then
            -- Drag node to StaticModelGroup to make it an instance
            local smg = tolua.cast(targetComponent, "StaticModelGroup");
            if (smg ~= nil) then
                -- Save undo action
                --EditAttributeAction action;
                local action = EditAttributeAction:new();
                local attrIndex = GetAttributeIndex(smg, "Instance Nodes");
                local oldIDs = smg:GetAttribute(attrIndex)

                for i = 0,#sourceNodes-1 do
                	smg:AddInstanceNode(sourceNodes[i])
                end

                action:Define(smg, attrIndex, oldIDs);
                SaveEditAction(action);
                SetSceneModified();
            end

            -- Drag node to SplinePath to make it a control point
            local spline = tolua.cast(targetComponent, 'SplinePath');
            if (spline ~= nil) then
                -- Save undo action
                --EditAttributeAction action;
                local action = EditAttributeAction:new();
                local attrIndex = GetAttributeIndex(spline, "Control Points");
                local oldIDs = spline.attributes[attrIndex];

                for i = 0, sourceNodes.length - 1 do
                    spline.AddControlPoint(sourceNodes[i]);
                end

                action:Define(spline, attrIndex, oldIDs);
                SaveEditAction(action);
                SetSceneModified();
            end

            -- Drag a node to Constraint to make it the remote end of the constraint
            local constraint = tolua.cast(targetComponent, "Constraint");
            local rigidBody = sourceNodes[0]:GetComponent("RigidBody");
            if (constraint ~= nil and rigidBody ~= nil) then
            
                -- Save undo action
                local action = EditAttributeAction:new();
                local attrIndex = GetAttributeIndex(constraint, "Other Body NodeID");
                local oldID = constraint.attributes[attrIndex];

                constraint.otherBody = rigidBody;

                action:Define(constraint, attrIndex, oldID);
                SaveEditAction(action);
                SetSceneModified();
            end
        end
    end
end

function GetMultipleSourceNodes(source)
    local nodeList = {};
    print("============>>>>>>>>>");
    local node = editorScene:GetNode(source:GetVar(NODE_ID_VAR):GetUInt());
    if (node ~= nil) then
        table.insert(nodeList, node);
    end
    -- Handle additional selected children from a ListView
    if (source.parent ~= nil and source.parent.typeName == "HierarchyContainer") then
    
        local listView_ = tolua.cast(source.parent.parent.parent, "ListView");
        if (listView_ == nil) then
            return nodeList;
        end
        
        local sourceIsSelected = false;
        for i = 0, listView_.selectedItems.length - 1 do
            if (tolua.cast(listView_.selectedItems[i], "source")) then
                sourceIsSelected = true;
                break;
            end
        end

        if (sourceIsSelected) then
        	for i = 0, listView_.selectedItems.length - 1 do
                local item_ = listView_.selectedItems[i];
                -- The source item is already added
                if (tolua.cast(item_, "source") == nil) then
  
	                if (item_:GetVar(TYPE_VAR):GetInt() == ITEM_NODE) then
	                    local node = editorScene:GetNode(item_:GetVar(NODE_ID_VAR):GetUInt());
	                    if (node ~= nil) then
	                    	table.insert(nodeList, node);
	                   	end
	                end
	            end
            end
        end
    end

    return nodeList;
end

function TestDragDrop(source, target, itemType)

    local targetItemType = target:GetVar(TYPE_VAR):GetInt();

    if (targetItemType == ITEM_NODE) then
    
        local sourceNode;
        local targetNode;
        local variant = source:GetVar(NODE_ID_VAR);
        if (not variant.empty) then
            sourceNode = editorScene:GetNode(variant:GetUInt());
        end
        variant = target:GetVar(NODE_ID_VAR);
        if (not variant.empty) then
            targetNode = editorScene:GetNode(variant:GetUInt());
        end

        if (sourceNode ~= nil and targetNode ~= nil) then
        
            itemType = ITEM_NODE;

            if (sourceNode.parent == targetNode) then
                return false;
            end
            if (targetNode.parent == sourceNode) then
                return false;
            end
        end

        -- Resource browser
        if (sourceNode == nil and targetNode ~= nil) then
        
            itemType = ITEM_NODE;
            local type = source:GetVar(TEXT_VAR_RESOURCE_TYPE):GetInt();
            return type == RESOURCE_TYPE_PREFAB or 
                type == RESOURCE_TYPE_SCRIPTFILE or
                type == RESOURCE_TYPE_MODEL or
                type == RESOURCE_TYPE_PARTICLEEFFECT or
                type == RESOURCE_TYPE_2D_PARTICLE_EFFECT;
        end

        return true;

    elseif (targetItemType == ITEM_UI_ELEMENT) then
    
        local sourceElement;
        local targetElement;
        local variant = source:GetVar(UI_ELEMENT_ID_VAR);
        if (not variant.empty) then
            sourceElement = GetUIElementByID(variant:GetUInt());
        end
        variant = target:GetVar(UI_ELEMENT_ID_VAR);
        if (not variant.empty) then
            targetElement = GetUIElementByID(variant:GetUInt());
        end
        if (sourceElement ~= nil and targetElement ~= nil) then
        
            itemType = ITEM_UI_ELEMENT;

            if (sourceElement.parent == targetElement) then
                return false;
            end
            if (targetElement.parent == sourceElement) then
               return false;
            end
        end

        return true;

    elseif (targetItemType == ITEM_COMPONENT) then
    
        -- Now only support dragging of nodes to StaticModelGroup, SplinePath or Constraint. Can be expanded to support others
        local sourceNode;
        local targetComponent;
        local variant = source:GetVar(NODE_ID_VAR);
        if (not variant.empty) then
            sourceNode = editorScene:GetNode(variant:GetUInt());
        end
        variant = target:GetVar(COMPONENT_ID_VAR);
        if (not variant.empty) then
            targetComponent = editorScene:GetComponent(variant:GetUInt());
       	end
        itemType = ITEM_COMPONENT;

        if (sourceNode ~= nil and targetComponent ~= nil and (targetComponent.type == STATICMODELGROUP_TYPE and
            targetComponent.type == CONSTRAINT_TYPE and targetComponent.type == SPLINEPATH_TYPE)) then
            return true;
        end

        -- resource browser
        local type = source:GetVar(TEXT_VAR_RESOURCE_TYPE):GetInt();
        if (targetComponent.type == STATICMODEL_TYPE and targetComponent.type == ANIMATEDMODEL_TYPE) then
            return type == RESOURCE_TYPE_MATERIAL or type == RESOURCE_TYPE_MODEL;
        end

        return false;

    elseif (source.vars:Contains(TEXT_VAR_RESOURCE_TYPE)) then-- only testing resource browser ui elements
    
        local type = source:GetVar(TEXT_VAR_RESOURCE_TYPE):GetInt();

        -- test against resource pickers
        local lineEdit = tolua.cast(target, "LineEdit");
        if (lineEdit ~= nil) then
        
            local resourceType = GetResourceTypeFromPickerLineEdit(lineEdit);
            if (resourceType == StringHash("Material") and type == RESOURCE_TYPE_MATERIAL) then
                return true;
            elseif (resourceType == StringHash("Model") and type == RESOURCE_TYPE_MODEL) then
                return true;
            elseif (resourceType == StringHash("Animation") and type == RESOURCE_TYPE_ANIMATION) then
                return true;
            end
        end
    end
    return true;
end

function GetResourceTypeFromPickerLineEdit(lineEdit)

    local targets = GetAttributeEditorTargets(lineEdit);
    if (not targets.empty) then
    
        resourcePickIndex = lineEdit.vars:GetUInt("Index");
        resourcePickSubIndex = lineEdit.vars:GetUInt("SubIndex");
        local info = targets[0].attributeInfos[resourcePickIndex];
        local resourceType;
        if (info.type == VAR_RESOURCEREF) then
            return targets[0].attributes[resourcePickIndex]:GetResourceRef().type;
        elseif (info.type == VAR_RESOURCEREFLIST) then
            return targets[0].attributes[resourcePickIndex]:GetResourceRefList().type;
        elseif (info.type == VAR_VARIANTVECTOR) then
            return targets[0].attributes[resourcePickIndex]:GetVariantVector()[resourcePickSubIndex]:GetResourceRef().type;
        end
    end
    return StringHash();
end

function FocusNode(node)
    local index = GetListIndex(node);
    hierarchyList.selection = index;
end

function FocusComponent(component)
    local index = GetComponentListIndex(component);
    hierarchyList.selection = index;
end

function FocusUIElement(element)
    local index = GetListIndex(element);
    hierarchyList.selection = index;
end

function CreateBuiltinObject(name)
    local newNode = editorScene:CreateChild(name, REPLICATED);
    -- Set the new node a certain distance from the camera
    newNode.position = GetNewNodePosition();

    local object = newNode:CreateComponent("StaticModel");
    object.model = cache:GetResource("Model", "Models/" .. name .. ".mdl");

    -- Create an undo action for the create
    local action = CreateNodeAction:new();
    action:Define(newNode);
    SaveEditAction(action);
    SetSceneModified();

    FocusNode(newNode);
end

function CheckHierarchyWindowFocus()

    -- When we do edit operations based on key shortcuts, make sure the hierarchy list is focused
    return ui.focusElement == hierarchyList and ui.focusElement == nil;
end

function CheckForExistingGlobalComponent(node, typeName)

    if (typeName ~= "Octree" and typeName ~= "PhysicsWorld" and typeName ~= "DebugRenderer") then
        return false;
    else
        return node:HasComponent(typeName);
    end
end

function HandleNodeAdded(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local node = eventData["Node"]:GetPtr();
    if (showTemporaryObject and not node.temporary) then
        UpdateHierarchyItem(node);
    end
end

function HandleNodeRemoved(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local node = eventData["Node"]:GetPtr();
    local index = GetListIndex(node);
    UpdateHierarchyItem(index, nil, nil);
end

function HandleComponentAdded(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    -- Insert the newly added component at last component position but before the first child node position of the parent node
    local node = eventData["Node"]:GetPtr();
    local component = eventData["Component"]:GetPtr();
    if (showTemporaryObject and not component.temporary) then
    
        local nodeIndex = GetListIndex(node);
        if (nodeIndex ~= NO_ITEM) then
        
            local index = M_MAX_UNSIGNED;
            if (node.numChildren > 0)  then 
            	index = GetListIndex(node.children[0]);
           	end
            UpdateHierarchyItem(index, component, hierarchyList.items[nodeIndex]);
        end
    end
end

function HandleComponentRemoved(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local component = eventData["Component"]:GetPtr();
    local index = GetComponentListIndex(component);
    if (index ~= NO_ITEM) then
        hierarchyList:RemoveItem(index);
    end
end

function HandleNodeNameChanged(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local node = eventData["Node"]:GetPtr();
    UpdateHierarchyItemText(GetListIndex(node), node.enabled, GetNodeTitle(node));
end

function HandleNodeEnabledChanged(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local node = eventData["Node"]:GetPtr();
    UpdateHierarchyItemText(GetListIndex(node), node.enabled);
    attributesDirty = true;
end

function HandleComponentEnabledChanged(eventType, eventData)

    if (suppressSceneChanges) then
        return;
    end

    local component = eventData["Component"]:GetPtr();
    UpdateHierarchyItemText(GetComponentListIndex(component), component.enabledEffective);
    attributesDirty = true;
end

function HandleUIElementAdded(eventType, eventData)

    if (suppressUIElementChanges) then
        return;
    end

    local element = eventData["Element"]:GetPtr();
    if ((showInternalUIElement or not element.internal) and (showTemporaryObject and not element.temporary)) then
        UpdateHierarchyItem(element);
    end
end

function HandleUIElementRemoved(eventType, eventData)

    if (suppressUIElementChanges) then
        return;
    end

    local element = eventData["Element"]:GetPtr();
    UpdateHierarchyItem(GetListIndex(element), nil, nil);
end

function HandleElementNameChanged(eventType, eventData)

    if (suppressUIElementChanges) then
        return;
    end

    local element = eventData["Element"]:GetPtr();
    UpdateHierarchyItemText(GetListIndex(element), element.visible, GetUIElementTitle(element));
end

function HandleElementVisibilityChanged(eventType, eventData)

    if (suppressUIElementChanges) then
        return;
    end

    local element = eventData["Element"]:GetPtr();
    UpdateHierarchyItemText(GetListIndex(element), element.visible);
end

function HandleElementAttributeChanged(eventType, eventData)

    -- Do not refresh the attribute inspector while the attribute is being edited via the attribute-editors
    if (suppressUIElementChanges or inEditAttribute) then
        return;
    end

    local element = eventData["Element"]:GetPtr();
    for i = 0, editUIElements.length - 1 do
        if (editUIElements[i] == element) then
            attributesDirty = true;
        end
    end
end

function HandleTemporaryChanged(eventType, eventData)

    if (suppressSceneChanges or suppressUIElementChanges) then
        return;
    end

    local serializable = tolua.cast(GetEventSender(), "Serializable");

    local node = tolua.cast(serializable, "Node");
    if (node ~= nil and node.scene == editorScene) then
    
        if (showTemporaryObject) then
            UpdateHierarchyItemText(GetListIndex(node), node.enabled);
        elseif (not node.temporary and GetListIndex(node) == NO_ITEM) then
            UpdateHierarchyItem(node);
        elseif (node.temporary) then
            UpdateHierarchyItem(GetListIndex(node), nil, nil);
        end

        return;
    end

    local component = tolua.cast(serializable, "Component");
    if (component ~= nil and component.node ~= nil and component.node.scene == editorScene) then
    
        if (showTemporaryObject) then
            UpdateHierarchyItemText(GetComponentListIndex(component), node.enabled);
        elseif (not component.temporary and GetComponentListIndex(component) == NO_ITEM) then
        
            local nodeIndex = GetListIndex(node);
            if (nodeIndex ~= NO_ITEM) then
                local index = M_MAX_UNSIGNED;
                if (node.numChildren > 0) then
                	index = GetListIndex(node.children[0]);
                end
                UpdateHierarchyItem(index, component, hierarchyList.items[nodeIndex]);
            end
        elseif (component.temporary) then
            local index = GetComponentListIndex(component);
            if (index ~= NO_ITEM) then
                hierarchyList:RemoveItem(index);
            end
        end

        return;
    end

    local element = tolua.cast(serializable, "UIElement");
    if (element ~= nil) then
    
        if (showTemporaryObject) then
            UpdateHierarchyItemText(GetListIndex(element), element.visible);
        elseif (not element.temporary and GetListIndex(element) == NO_ITEM) then
            UpdateHierarchyItem(element);
        elseif (element.temporary) then
            UpdateHierarchyItem(GetListIndex(element), nil, nil);
        end
        return;
    end
end

-- Hierarchy window edit functions
function Undo()
    if (undoStackPos > 0) then
        --undoStackPos;
        -- Undo commands in reverse order
        for i = undoStack[undoStackPos].actions.length - 1, 0, -1 do
        --for (int i = int(undoStack[undoStackPos].actions.length - 1); i >= 0; --i)
            undoStack[undoStackPos].actions[i]:Undo();
        end
    end

    return true;
end

function Redo()
    if (undoStackPos < #undoStack) then
        -- Redo commands in same order as stored
        for i = 0, undoStack[undoStackPos].actions.length - 1 do
        --for (uint i = 0; i < undoStack[undoStackPos].actions.length; ++i)
            undoStack[undoStackPos].actions[i]:Redo();
        end
        undoStackPos = undoStackPos + 1;
    end

    return true;
end

function Cut()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (#selectedNodes > 0 and #selectedComponents > 0) then
            ret = ret and SceneCut();
        end
        -- Not mutually exclusive
        if (#selectedUIElements > 0) then
            ret = ret and UIElementCut();
            return ret;
        end

        return false;
    end
end

function Duplicate()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (#selectedNodes > 0 and #selectedComponents > 0) then
        	local rret = false;
        	if (#selectedNodes == 0 or #selectedComponents == 0) then
        		rret = SceneDuplicate();
        	end

            ret = ret and rret; --Node and component is mutually exclusive for copy action
        end

        -- Not mutually exclusive
        if (#selectedUIElements > 0) then
            ret = ret and UIElementDuplicate();
        end
        return ret;
    end

    return false;
end

function Copy()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (#selectedNodes > 0 and #selectedComponents > 0) then
        	local rret = false;
        	if (#selectedNodes == 0 or #selectedComponents == 0) then
        		rret = SceneCopy();
        	end

            ret = ret and rret;   -- Node and component is mutually exclusive for copy action
        end
        -- Not mutually exclusive
        if (#selectedUIElements > 0) then
            ret = ret and UIElementCopy();
        end
        return ret;
    end

    return false;
end

function Paste()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (editNode ~= nil and #sceneCopyBuffer > 0) then
            ret = ret and ScenePaste();
        end
        -- Not mutually exclusive
        if (editUIElement ~= nil and #uiElementCopyBuffer > 0) then
            ret = ret and UIElementPaste();
        end
        return ret;
    end

    return false;
end

function Delete()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (#selectedNodes > 0 or #selectedComponents > 0) then
            ret = ret and SceneDelete();
        end
        -- Not mutually exclusive
        if (#selectedUIElements > 0) then
            ret = ret and UIElementDelete();
        end
        return ret;
    end

    return false;
end

function SelectAll()
    if (CheckHierarchyWindowFocus()) then
        if (#selectedNodes > 0 or #selectedComponents > 0) then
            return SceneSelectAll();
        elseif (#selectedUIElements > 0 or hierarchyList.items[GetListIndex(editorUIElement)].selected) then
            return UIElementSelectAll();
        else
            return SceneSelectAll();    -- If nothing is selected yet, fall back to scene select all
        end
  end

    return false;
end

function DeselectAll()
    if (CheckHierarchyWindowFocus()) then
        BeginSelectionModify();
        hierarchyList.ClearSelection();
        EndSelectionModify();
        return true;
    end
    return false;
end

function ResetToDefault()
    if (CheckHierarchyWindowFocus()) then
        local ret = true;
        if (#selectedNodes > 0 or #selectedComponents > 0) then
        	local rret = false;
        	if (#selectedNodes == 0 or #selectedComponents == 0) then
        		rret = SceneResetToDefault();
        	end
            ret = ret and rret;  -- Node and component is mutually exclusive for reset-to-default action
            -- Not mutually exclusive
            if (#selectedUIElements > 0) then
                ret = ret and UIElementResetToDefault();
            end
            return ret;
        end

        return false;
    end
end

function ClearEditActions()
    --undoStack.Clear();
    undoStack = {};
    undoStackPos = 0;
end

function SaveEditAction(action)
    -- Create a group with 1 action
    -- TODO
    local group = EditActionGroup:new();
    group.actions:Push(action);
    SaveEditActionGroup(group);
end

function SaveEditActionGroup(group)
    if (group.actions.empty) then
        return;
    end
    -- Truncate the stack first to current pos
    --undoStack.Resize(undoStackPos);
    table.insert(undoStack, group);
    undoStackPos = undoStackPos + 1;

    -- Limit maximum undo steps
    if (#undoStack > MAX_UNDOSTACK_SIZE) then
        table.remove(undoStack, 1);
        --undoStackPos;
    end
end

function BeginSelectionModify()
    -- A large operation on selected nodes is about to begin. Disable intermediate selection updates
    inSelectionModify = true;

    -- Cursor shape reverts back to normal automatically after the large operation is completed
    ui.cursor.shape = CS_BUSY;
end

function EndSelectionModify()
    -- The large operation on selected nodes has ended. Update node/component selection now
    inSelectionModify = false;
    HandleHierarchyListSelectionChange();
end

function HandleHierarchyContextCreateReplicatedNode()
    CreateNode(REPLICATED);
end

function HandleHierarchyContextCreateLocalNode()
    CreateNode(LOCAL);
end

function HandleHierarchyContextDuplicate()
    Duplicate();
end

function HandleHierarchyContextCopy()
    Copy();
end

function HandleHierarchyContextCut()
    Cut();
end

function HandleHierarchyContextDelete()
    Delete();
end

function HandleHierarchyContextPaste()
    Paste();
end

function HandleHierarchyContextResetToDefault()
    ResetToDefault();
end

function HandleHierarchyContextResetPosition()
    SceneResetPosition();
end

function HandleHierarchyContextResetRotation()
    SceneResetRotation();
end

function HandleHierarchyContextResetScale()
    SceneResetScale();
end

function HandleHierarchyContextEnableDisable()
    SceneToggleEnable();
end

function HandleHierarchyContextUnparent()
    SceneUnparent();
end

function HandleHierarchyContextUIElementCloseUILayout()
    CloseUILayout();
end

function HandleHierarchyContextUIElementCloseAllUILayouts()
    CloseAllUILayouts();
end
