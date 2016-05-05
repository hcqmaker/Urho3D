-- Attribute editor
--
-- Functions that caller must implement:
-- - function SetAttributeEditorID(UIElement@ attrEdit, Array<Serializable@>@ serializables);
-- - bool PreEditAttribute(Array<Serializable@>@ serializables, uint index);
-- - function PostEditAttribute(Array<Serializable@>@ serializables, uint index, const Array<Variant>& oldValues);
-- - Array<Serializable@>@ GetAttributeEditorTargets(UIElement@ attrEdit);
-- - String GetVariableName(hash);

MIN_NODE_ATTRIBUTES = 4;
MAX_NODE_ATTRIBUTES = 8;
ATTRNAME_WIDTH = 150;
ATTR_HEIGHT = 19;
TEXT_CHANGED_EVENT_TYPE = StringHash("TextChanged");

inLoadAttributeEditor = false;
inEditAttribute = false;
inUpdateBitSelection = false;
showNonEditableAttribute = false;

normalTextColor = Color(1.0, 1.0, 1.0);
modifiedTextColor = Color(1.0, 0.8, 0.5);
nonEditableTextColor = Color(0.7, 0.7, 0.7);

sceneResourcePath = AddTrailingSlash(fileSystem:GetProgramDir() .. "Data");
rememberResourcePath = true;

-- Exceptions for string attributes that should not be continuously edited
noTextChangedAttrs = {"Script File", "Class Name", "Script Object Type", "Script File Name"};

-- List of attributes that should be created with a bit selection editor
bitSelectionAttrs = {"Collision Mask", "Collision Layer", "Light Mask", "Zone Mask", "View Mask", "Shadow Mask"};

-- Number of editable bits for bit selection editor
MAX_BITMASK_BITS = 8;
MAX_BITMASK_VALUE = bit.blshift(1, MAX_BITMASK_BITS) - 1;
nonEditableBitSelectorColor = Color(0.5, 0.5, 0.5);
editableBitSelectorColor =  Color(1.0, 1.0, 1.0);

testAnimState = {};

dragEditAttribute = false;

function SetEditable(element, editable)
    if (element == nil) then
        return element;
    end

    element.editable = editable;
    element.colors[C_TOPLEFT] = ifor(editable , element.colors[C_BOTTOMRIGHT] , nonEditableTextColor);
    element.colors[C_BOTTOMLEFT] = element.colors[C_TOPLEFT];
    element.colors[C_TOPRIGHT] = element.colors[C_TOPLEFT];
    return element;
end

function SetValue(element, value, sameValue)
    element.text = ifor(sameValue , value , STRIKED_OUT);
    element.cursorPosition = 0;
    return element;
end

function SetValue(element, value, sameValue)
    element.checked = ifor(sameValue , value , false);
    return element;
end

function SetValue(element, value, sameValue)
    element.selection = ifor(sameValue , value , M_MAX_UNSIGNED);
    return element;
end

function CreateAttributeEditorParentWithSeparatedLabel(list, name, index, subIndex, suppressedSeparatedLabel)
    if (suppressedSeparatedLabel == nil) then
        suppressedSeparatedLabel = false;
    end
    local editorParent = UIElement("Edit" .. String(index) .. "_" .. String(subIndex));
    editorParent:SetVar("Index",Variant(index));
    editorParent:SetVar("SubIndex",Variant(subIndex));
    editorParent:SetLayout(LM_VERTICAL, 2);
    list:AddItem(editorParent);

    if (suppressedSeparatedLabel) then
        local placeHolder = UIElement(name);
        editorParent:AddChild(placeHolder);
    else
        local attrNameText = Text:new();
        editorParent:AddChild(attrNameText);
        attrNameText.style = "EditorAttributeText";
        attrNameText.text = name;
    end 

    return editorParent;
end

function CreateAttributeEditorParentAsListChild(list, name, index, subIndex)
    local editorParent = UIElement("Edit" .. String(index) .. "_" .. String(subIndex));
    editorParent:SetVar("Index",Variant(index));
    editorParent:SetVar("SubIndex",Variant(subIndex));
    editorParent:SetLayout(LM_HORIZONTAL);
    list:AddChild(editorParent);

    local placeHolder = UIElement(name);
    editorParent:AddChild(placeHolder);

    return editorParent;
end

function CreateAttributeEditorParent(list, name, index, subIndex)
    local editorParent = UIElement("Edit" .. String(index) .. "_" .. String(subIndex));
    editorParent:SetVar("Index",Variant(index));
    editorParent:SetVar("SubIndex",Variant(subIndex));
    editorParent:SetLayout(LM_HORIZONTAL);
    editorParent:SetFixedHeight(ATTR_HEIGHT);
    list:AddItem(editorParent);

    local attrNameText = Text:new();
    editorParent:AddChild(attrNameText);
    attrNameText.style = "EditorAttributeText";
    attrNameText.text = name;
    attrNameText:SetFixedWidth(ATTRNAME_WIDTH);

    return editorParent;
end

function CreateAttributeLineEdit(parent, serializables, index, subIndex)
    local attrEdit = LineEdit:new();
    parent:AddChild(attrEdit);
    attrEdit.dragDropMode = DD_TARGET;
    attrEdit.style = "EditorAttributeEdit";
    attrEdit:SetFixedHeight(ATTR_HEIGHT - 2);
    attrEdit:SetVar("Index",Variant(index));
    attrEdit:SetVar("SubIndex",Variant(subIndex));
    SetAttributeEditorID(attrEdit, serializables);

    return attrEdit;
end

function CreateAttributeBitSelector(parent, serializables, index, subIndex)
    local container = UIElement();
    parent:AddChild(container);
    parent:SetFixedHeight(38);
    container:SetFixedWidth(16 * 4 + 4);

    for i = 0, 1 do
        for j = 0, 3 do
            local bitBox = CheckBox:new();
            bitBox.name = "BitSelect_" .. String(i * 4 + j);
            container:AddChild(bitBox);
            bitBox.position = IntVector2(16 * j, 16 * i);
            bitBox.style = "CheckBox";
            bitBox:SetFixedHeight(16);

            SubscribeToEvent(bitBox,"Toggled", "HandleBitSelectionToggled");
        end 
    end

    local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex);
    attrEdit.name = "LineEdit";
    SubscribeToEvent(attrEdit, "TextChanged", "HandleBitSelectionEdit");
    SubscribeToEvent(attrEdit, "TextFinished", "HandleBitSelectionEdit");
    return attrEdit;
end

function UpdateBitSelection(parent)
    local mask = 0;
    for i = 0, MAX_BITMASK_BITS - 1 do
        local bitBox = parent:GetChild("BitSelect_" .. String(i), true);
        mask = bitor2(mask, ifor(bitBox.checked , bitlshift(1, i) , 0));
    end

    if (mask == MAX_BITMASK_VALUE) then
        mask = -1;
    end

    inUpdateBitSelection = true;
    local attrEdit = parent.parent:GetChild("LineEdit", true);
    attrEdit.text = String(mask);
    inUpdateBitSelection = false;
end

function SetBitSelection(parent, value)
    local mask = value;
    local enabled = true;

    if (mask ==  -1) then
        mask = MAX_BITMASK_VALUE;
    elseif (mask > MAX_BITMASK_VALUE) then
        enabled = false;
    end

    for i = 0, MAX_BITMASK_BITS - 1 do
        local bitBox = parent:GetChild("BitSelect_" .. String(i), true);
        bitBox.enabled = enabled;
        if (not enabled) then
            bitBox.color = nonEditableBitSelectorColor;
        else
            bitBox.color = editableBitSelectorColor;
        end

        if (bitand2(bitlshift(1 , i) , mask) ~= 0) then
            bitBox.checked = true;
        else
            bitBox.checked = false;
        end
    end
end

function HandleBitSelectionToggled(eventType, eventData)
    if (inUpdateBitSelection) then
        return;
    end

    local bitBox = eventData["Element"]:GetPtr();

    UpdateBitSelection(bitBox.parent);
end

function HandleBitSelectionEdit(eventType, eventData)
    if (not tinUpdateBitSelection) then
        local attrEdit = eventData["Element"]:GetPtr();

        inUpdateBitSelection = true;
        SetBitSelection(attrEdit.parent, ToInt(attrEdit.text));
        inUpdateBitSelection = false;
    end

    EditAttribute(eventType, eventData);
end

function CreateStringAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex);
    local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex);
    attrEdit.dragDropMode = DD_TARGET;
    -- Do not subscribe to continuous edits of certain attributes (script class names) to prevent unnecessary errors getting printed
    if (Find(noTextChangedAttrs, info.name) == -1) then
        SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute");
    end
    SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute");

    return parent;
end

function CreateBoolAttributeEditor(list, serializables, info, index, subIndex)
    local isUIElement = tolua.cast(serializables[0], "UIElement") ~= nil;
    local parent;
    if (info.name == ifor(isUIElement , "Is Visible" , "Is Enabled")) then
        parent = CreateAttributeEditorParentAsListChild(list, info.name, index, subIndex);
    else
        parent = CreateAttributeEditorParent(list, info.name, index, subIndex);
    end

    local attrEdit = CheckBox:new();
    parent:AddChild(attrEdit);
    attrEdit.style = AUTO_STYLE;
    attrEdit:SetVar("Index",Variant(index));
    attrEdit:SetVar("SubIndex",Variant(subIndex));
    SetAttributeEditorID(attrEdit, serializables);
    SubscribeToEvent(attrEdit, "Toggled", "EditAttribute");

    return parent;
end

function CreateNumAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex);
    local type = info.type;
    local numCoords = 1;
    if (type == VAR_VECTOR2 or type == VAR_INTVECTOR2) then
        numCoords = 2;
    elseif (type == VAR_VECTOR3 or type == VAR_QUATERNION) then
        numCoords = 3;
    elseif (type == VAR_VECTOR4 or type == VAR_COLOR or type == VAR_INTRECT) then
        numCoords = 4;
    end

    for i = 0, numCoords - 1 do
        local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex);
        attrEdit.vars["Coordinate"] = i;
        
        CreateDragSlider(attrEdit);

        SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute");
        SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute");
    end

    return parent;
end

function CreateIntAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex);

    -- Check for masks and layers
    if (bitSelectionAttrs.Find(info.name) > -1) then
        local attrEdit = CreateAttributeBitSelector(parent, serializables, index, subIndex);
    -- Check for enums
    elseif (info.enumNames == nil or empty(info.enumNames)) then
        -- No enums, create a numeric editor
        local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex);
        CreateDragSlider(attrEdit);
        -- If the attribute is a counter for things like billboards or animation states, disable apply at each change
        if (Find(info.name, " Count", 0, false) == -1)  then
            SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute");
        end
        SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute");
        -- If the attribute is a node ID, make it a drag/drop target
        if (info.name:Contains("NodeID", false) or info.name:Contains("Node ID", false) or bitand2(info.mode , AM_NODEID) ~= 0) then
            attrEdit.dragDropMode = DD_TARGET;
		end
    else
        local attrEdit = DropDownList:new();
        parent:AddChild(attrEdit);
        attrEdit.style = AUTO_STYLE;
        attrEdit:SetFixedHeight(ATTR_HEIGHT - 2);
        attrEdit.resizePopup = true;
        attrEdit.placeholderText = STRIKED_OUT;
        attrEdit:SetVar("Index",Variant(index));
        attrEdit:SetVar("SubIndex",Variant(subIndex));
        attrEdit:SetLayout(LM_HORIZONTAL, 0, IntRect(4, 1, 4, 1));
        SetAttributeEditorID(attrEdit, serializables);

        for i = 0, info.enumNames.length - 1 do
            local choice = Text:new();
            attrEdit:AddItem(choice);
            choice.style = "EditorEnumAttributeText";
            choice.text = info.enumNames[i];
        end 

        SubscribeToEvent(attrEdit, "ItemSelected", "EditAttribute");
    end 

    return parent;
end

function CreateResourceRefAttributeEditor(list, serializables, info, index, subIndex, suppressedSeparatedLabel)
    if (suppressedSeparatedLabel == nil) then
        suppressedSeparatedLabel = false;
    end
    local parent;
    local resourceType;

    -- Get the real attribute info from the serializable for the correct resource type
    local attrInfo = serializables[0].attributeInfos[index];
    if (attrInfo.type == VAR_RESOURCEREF) then
        resourceType = serializables[0].attributes[index]:GetResourceRef().type;
    elseif (attrInfo.type == VAR_RESOURCEREFLIST) then
        resourceType = serializables[0].attributes[index]:GetResourceRefList().type;
    elseif (attrInfo.type == VAR_VARIANTVECTOR) then
        resourceType = serializables[0].attributes[index]:GetVariantVector()[subIndex]:GetResourceRef().type;
    end

    local picker = GetResourcePicker(resourceType);

    -- Create the attribute name on a separate non-interactive line to allow for more space
    parent = CreateAttributeEditorParentWithSeparatedLabel(list, info.name, index, subIndex, suppressedSeparatedLabel);

    local container = UIElement:new();
    container:SetLayout(LM_HORIZONTAL, 4, IntRect(ifor(StartsWith(info.name, "   ") , 20 , 10), 0, 4, 0));    -- Left margin is indented more when the name is so
    container:SetFixedHeight(ATTR_HEIGHT);
    parent:AddChild(container);

    local attrEdit = CreateAttributeLineEdit(container, serializables, index, subIndex);
    attrEdit:SetVar(TYPE_VAR,Variant(resourceType.value));
    SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute");

    if (picker ~= nil) then
        if (bitand2(picker.actions , ACTION_PICK) ~= 0) then
            local pickButton = CreateResourcePickerButton(container, serializables, index, subIndex, "Pick");
            SubscribeToEvent(pickButton, "Released", "PickResource");
        end
        if (bitand2(picker.actions , ACTION_OPEN) ~= 0) then
            local openButton = CreateResourcePickerButton(container, serializables, index, subIndex, "Open");
            SubscribeToEvent(openButton, "Released", "OpenResource");
        end
        if (bitand2(picker.actions , ACTION_EDIT) ~= 0) then
            local editButton = CreateResourcePickerButton(container, serializables, index, subIndex, "Edit");
            SubscribeToEvent(editButton, "Released", "EditResource");
        end
        if (bitand2(picker.actions , ACTION_TEST) ~= 0) then
            local testButton = CreateResourcePickerButton(container, serializables, index, subIndex, "Test");
            SubscribeToEvent(testButton, "Released", "TestResource");
        end
    end 

    return parent;
end

function CreateResourcePickerButton(container, serializables, index, subIndex, text)
    local button = Button:new();
    container:AddChild(button);
    button.style = AUTO_STYLE;
    button:SetFixedSize(36, ATTR_HEIGHT - 2);
    button:SetVar("Index",Variant(index));
    button:SetVar("SubIndex",Variant(subIndex));
    SetAttributeEditorID(button, serializables);

    local buttonText = Text:new();
    button:AddChild(buttonText);
    buttonText.style = "EditorAttributeText";
    buttonText.SetAlignment(HA_CENTER, VA_CENTER);
    buttonText.text = text;

    return button;
end

function CreateAttributeEditor(list, serializables, info, index, subIndex, suppressedSeparatedLabel)
    if (suppressedSeparatedLabel == nil) then
        suppressedSeparatedLabel = false;
    end
    local parent;

    local type = info.type;
    if (type == VAR_STRING or type == VAR_BUFFER) then
        parent = CreateStringAttributeEditor(list, serializables, info, index, subIndex);
    elseif (type == VAR_BOOL) then
        parent = CreateBoolAttributeEditor(list, serializables, info, index, subIndex);
    elseif ((type >= VAR_FLOAT and type <= VAR_VECTOR4) or type == VAR_QUATERNION or type == VAR_COLOR or type == VAR_INTVECTOR2 or type == VAR_INTRECT or type == VAR_DOUBLE) then
        parent = CreateNumAttributeEditor(list, serializables, info, index, subIndex);
    elseif (type == VAR_INT) then
        parent = CreateIntAttributeEditor(list, serializables, info, index, subIndex);
    elseif (type == VAR_RESOURCEREF) then
        parent = CreateResourceRefAttributeEditor(list, serializables, info, index, subIndex, suppressedSeparatedLabel);
    elseif (type == VAR_RESOURCEREFLIST) then
        local numRefs = serializables[0].attributes[index]:GetResourceRefList().length;

        -- Straightly speaking the individual resource reference in the list is not an attribute of the serializable
        -- However, the AttributeInfo structure is used here to reduce the number of parameters being passed in the function
        local refInfo = AttributeInfo:new();
        refInfo.name = info.name;
        refInfo.type = VAR_RESOURCEREF;
        for i = 0, numRefs - 1 do
            CreateAttributeEditor(list, serializables, refInfo, index, i, i > 0);
        end
    elseif (type == VAR_VARIANTVECTOR) then
        local vectorStruct = GetVectorStruct(serializables, index);
        if (vectorStruct ~= nil) then
            return nil;
        end
        local nameIndex = 0;

        local vector = serializables[0].attributes[index]:GetVariantVector();
        for i = 1, #vector do
            -- The individual variant in the vector is not an attribute of the serializable, the structure is reused for convenience
            local vectorInfo = AttributeInfo:new();
            vectorInfo.name = vectorStruct.variableNames[nameIndex];
            vectorInfo.type = vector[i].type;
            CreateAttributeEditor(list, serializables, vectorInfo, index, i);
            nameIndex = nameIndex + 1
            if (nameIndex >= vectorStruct.variableNames.length) then
                nameIndex = vectorStruct.restartIndex;
            end
        end 
    elseif (type == VAR_VARIANTMAP) then
        local map = serializables[0].attributes[index]:GetVariantMap();
        local keys = map.keys;
        for i = 1, #keys do
            local varName = GetVarName(keys[i]);
            if (empty(varName)) then
                -- UIElements will contain internal vars, which do not have known mappings. Skip these
                if (tolua.cast(serializables[0], "UIElement") == nil) then
                    -- Else, for scene nodes, show as hexadecimal hashes if nothing else is available
                    varName = keys[i].ToString();
                end
            end
            local value = map[keys[i]];

            -- The individual variant in the map is not an attribute of the serializable, the structure is reused for convenience
            local mapInfo = AttributeInfo:new();
            mapInfo.name = varName .. " (Var)";
            mapInfo.type = value.type;
            parent = CreateAttributeEditor(list, serializables, mapInfo, index, i);
            -- Add the variant key to the parent. We may fail to add the editor in case it is unsupported
            if (parent ~= nil) then
                parent:SetVar("Key", Variant(keys[i].value));
                -- If variable name is not registered (i.e. it is an editor internal variable) then hide it
                if (empty(varName)) then
                    parent.visible = false;
                end
            end
        end
    end

    return parent;
end

function GetAttributeEditorCount(serializables)
    local count = 0;

    if (not empty(serializables)) then
        --/ \todo When multi-editing, this only counts the editor count of the first serializable
        local isUIElement = tolua.cast(serializables[0], "UIElement") ~= nil;
        for i = 0, serializables[0].numAttributes - 1 do
                local info = serializables[0].attributeInfos[i];
            if (not showNonEditableAttribute and bitand2(info.mode , AM_NOEDIT) ~= 0) then
            else
                -- "Is Enabled" is not inserted into the main attribute list, so do not count
                -- Similarly, for UIElement, "Is Visible" is not inserted
                if (info.name == ifor(isUIElement , "Is Visible" , "Is Enabled")) then
                else
                    if (info.type == VAR_RESOURCEREFLIST) then
                        count = count + serializables[0].attributes[i]:GetResourceRefList().length;
                    elseif (info.type == VAR_VARIANTVECTOR and GetVectorStruct(serializables, i) ~= nil) then
                        count = count + serializables[0].attributes[i]:GetVariantVector().length;
                    elseif (info.type == VAR_VARIANTMAP) then
                        count = count + serializables[0].attributes[i]:GetVariantMap().length;
                    else
                        count = count + 1;
                    end
                end
            end
        end
    end

    return count;
end

function  GetAttributeEditorParent(parent, index, subIndex)
    return parent:GetChild("Edit" .. String(index) .. "_" + String(subIndex), true);
end

function LoadAttributeEditor(list, serializables, info, index)
    local editable = bitand2(info.mode , AM_NOEDIT) == 0;

    local parent = GetAttributeEditorParent(list, index, 0);
    if (parent == nil) then
        return;
    end

    inLoadAttributeEditor = true;

    local sameName = true;
    local sameValue = true;
    local value = serializables[0].attributes[index];
    local values = {};
    for i = 1, #serializables do
        if (index >= serializables[i].numAttributes or serializables[i].attributeInfos[index].name ~= info.name) then
            sameName = false;
            break;
        end

        local val = serializables[i].attributes[index];
        if (val ~= value) then
            sameValue = false;
        end
        Push(values, val);
    end

    -- Attribute with different values from multiple-select is loaded with default/empty value and non-editable
    if (sameName) then
        LoadAttributeEditor(parent, value, info, editable, sameValue, values);
    else
        parent.visible = false;
    end

    inLoadAttributeEditor = false;
end

function LoadAttributeEditor(parent, value, info, editable, sameValue, values)
    local index = parent.vars:GetUInt("Index");

    -- Assume the first child is always a text label element or a container that containing a text label element
    local label = parent.children[0];
    if (label.type == UI_ELEMENT_TYPE and label.numChildren > 0) then
        label = label.children[0];
    end
    if (label.type == TEXT_TYPE) then
        local modified;
        if (info.defaultValue.type == VAR_NONE or info.defaultValue.type == VAR_RESOURCEREFLIST) then
            modified = not value.zero;
        else
            modified = value ~= info.defaultValue;
        end
        tolua.cast(label, "Text").color = ifor(editable , ifor(modified , modifiedTextColor , normalTextColor) , nonEditableTextColor);
    end

    local type = info.type;
    if (type == VAR_FLOAT or type == VAR_DOUBLE or type == VAR_STRING or type == VAR_BUFFER) then
        SetEditable(SetValue(parent.children[1], value.ToString(), sameValue), editable and sameValue);
    elseif (type == VAR_BOOL) then
        SetEditable(SetValue(parent.children[1], value.GetBool(), sameValue), editable and sameValue);
    elseif (type == VAR_INT) then
        if (bitSelectionAttrs.Find(info.name) > -1) then
            SetEditable(SetValue(parent:GetChild("LineEdit", true), value:ToString(), sameValue), editable and sameValue);
        elseif (info.enumNames == nil or info.enumNames.empty) then
            SetEditable(SetValue(parent.children[1], value:ToString(), sameValue), editable and sameValue);
        else
            SetEditable(SetValue(parent.children[1], value:GetInt(), sameValue), editable and sameValue);
        end
    elseif (type == VAR_RESOURCEREF) then
        SetEditable(SetValue(parent.children[1].children[0], value:GetResourceRef().name, sameValue), editable and sameValue);
        SetEditable(parent.children[1].children[1], editable and sameValue);  -- If editable then can pick
        for i = 2, parent.children[1].numChildren - 1 do
            SetEditable(parent.children[1].children[i], sameValue); -- If same value then can open/edit/test
        end
    elseif (type == VAR_RESOURCEREFLIST) then
        local list = parent.parent;
        local refList = value:GetResourceRefList();
        for subIndex = 1, #refList do
            parent = GetAttributeEditorParent(list, index, subIndex);
            if (parent == nil) then
                break;
            end

            local firstName = refList.names[subIndex];
            local nameSameValue = true;
            if (not sameValue) then
                -- Reevaluate each name in the list
                for i = 1, #values do
                    local refList = values[i]:GetResourceRefList();
                    if (subIndex >= #refList or refList.names[subIndex] ~= firstName) then
                        nameSameValue = false;
                        break;
                    end
                end
            end
            SetEditable(SetValue(parent.children[1].children[0], firstName, nameSameValue), editable and nameSameValue);
        end
    elseif (type == VAR_VARIANTVECTOR) then
        local list = parent.parent;
        local vector = value:GetVariantVector();
        for subIndex = 1, #vector do
            parent = GetAttributeEditorParent(list, index, subIndex);
            if (parent == nil) then
                break;
            end

            local firstValue = vector[subIndex];
            local sameValue = true;
            local varValues = {};

            -- Reevaluate each variant in the vector
            for i = 1, #values do
                local vector = values[i]:GetVariantVector();
                if (subIndex < #vector) then
                    local value = vector[subIndex];
                    Push(varValues, value);
                    if (value ~= firstValue) then
                        sameValue = false;
                    end
                else
                    sameValue = false;
                end
            end

            -- The individual variant in the list is not an attribute of the serializable, the structure is reused for convenience
            local info = AttributeInfo:new();
            info.type = firstValue.type;
            LoadAttributeEditor(parent, firstValue, info, editable, sameValue, varValues);
        end
    elseif (type == VAR_VARIANTMAP) then
        local list = parent.parent;
        local map = value:GetVariantMap();
        local keys = map.keys;
        for subIndex = 1, #keys do
            parent = GetAttributeEditorParent(list, index, subIndex);
            if (parent == nil) then
                break;
            end

            local varName = GetVarName(keys[subIndex]);
            if (empty(varName)) then
                varName = keys[subIndex].ToString(); -- Use hexadecimal if nothing else is available
            end

            local firstValue = map[keys[subIndex]];
            local sameValue = true;
            local varValues = {};

            -- Reevaluate each variant in the map
            for i = 1, #values do
                local map = values[i]:GetVariantMap();
                if (map:Contains(keys[subIndex])) then
                    local value = map[keys[subIndex]];
                    Push(varValues, value);
                    if (value ~= firstValue) then
                       sameValue = false;
                    end
                else
                    sameValue = false;
                end
            end

            -- The individual variant in the map is not an attribute of the serializable, the structure is reused for convenience
            local info = AttributeInfo:new();
            info.type = firstValue.type;
            LoadAttributeEditor(parent, firstValue, info, editable, sameValue, varValues);
        end
    else
        local coordinates = {};
        for i = 1, #values do
            local value = values[i];

            -- Convert Quaternion value to Vector3 value first
            if (type == VAR_QUATERNION) then
                value = value.GetQuaternion().eulerAngles;
            end

            Push(coordinates, Split(value:ToString(),' '));
        end
        for i = 1, #coordinates do
            local value = coordinates[0][i];
            local coordinateSameValue = true;
            if (not sameValue) then
                -- Reevaluate each coordinate
                for j = 2, #coordinates do
                    if (coordinates[j][i] ~= value) then
                        coordinateSameValue = false;
                        break;
                    end
                end
            end
            SetEditable(SetValue(parent.children[i + 1], value, coordinateSameValue), editable and coordinateSameValue);
        end
    end
end

function StoreAttributeEditor(parent, serializables, index, subIndex, coordinate)
    local info = serializables[0].attributeInfos[index];

    if (info.type == VAR_RESOURCEREFLIST) then
        for i = 1, #serializables do
            local refList = serializables[i].attributes[index]:GetResourceRefList();
            local vlaues = {};
            GetEditorValue(parent, VAR_RESOURCEREF, nil, coordinate, values);
            local ref = values[0]:GetResourceRef();
            refList.names[subIndex] = ref.name;
            serializables[i].attributes[index] = Variant(refList);
        end
    elseif (info.type == VAR_VARIANTVECTOR) then
        for i = 1, #serializables - 1 do
            local vector = serializables[i].attributes[index]:GetVariantVector();
            local vlaues = {};
            Push(values, vector[subIndex]);  -- Each individual variant may have multiple coordinates itself
            GetEditorValue(parent, vector[subIndex].type, nil, coordinate, values);
            vector[subIndex] = values[0];
            serializables[i].attributes[index] = Variant(vector);
        end
    elseif (info.type == VAR_VARIANTMAP) then
        local map = serializables[0].attributes[index]:GetVariantMap();
        key(parent.vars:GetUInt("Key"));
        for i = 1, #serializables do
            local map = serializables[i].attributes[index].GetVariantMap();
            local values = {};
            Push(values, map[key]);  -- Each individual variant may have multiple coordinates itself
            GetEditorValue(parent, map[key].type, nil, coordinate, values);
            map[key] = values[0];
            serializables[i].attributes[index] = Variant(map);
        end
    else
        local values = {};
        for i = 1, #serializables do
            Push(values, serializables[i].attributes[index]);
        end
        GetEditorValue(parent, info.type, info.enumNames, coordinate, values);
        for i = 1, #serializables do
            serializables[i].attributes[index] = values[i];
        end
    end
end

function FillValue(values, value)
    for i = 1, #values do
        values[i] = value;
    end
end

function SanitizeNumericalValue(type, value)
    if (type >= VAR_FLOAT and type <= VAR_COLOR) then
        value = String(value:ToFloat());
    elseif (type == VAR_INT or type == VAR_INTRECT or type == VAR_INTVECTOR2) then
        value = String(value:ToInt());
    elseif (type == VAR_DOUBLE) then
        value = String(value:ToDouble());
    end
end

function GetEditorValue(parent, type, enumNames, coordinate, values)
    local attrEdit = parent.children[coordinate + 1];

    if (attrEdit == nil) then
        attrEdit = parent:GetChild("LineEdit", true);
    end

    if (type == VAR_STRING)  then
        FillValue(values, Variant(Trimmed(attrEdit.text)));
    elseif (type == VAR_BOOL) then
        local attrEdit = parent.children[1];
        FillValue(values, Variant(attrEdit.checked));
    elseif (type == VAR_FLOAT) then
        FillValue(values, Variant(ToFloat(attrEdit.text)));
    elseif (type == VAR_DOUBLE) then
        FillValue(values, Variant(attrEdit.text.ToDouble()));
    elseif (type == VAR_QUATERNION) then
        local value = ToFloat(attrEdit.text);
        for i = 1, #values do
            local data = values[i]:GetQuaternion().eulerAngles.data;
            data[coordinate] = value;
            values[i] = Quaternion(Vector3(data));
        end
    elseif (type == VAR_INT) then
        if (enumNames == nil or empty(enumNames)) then
            FillValue(values, Variant(ToInt(attrEdit.text)));
        else
            local attrEdit = parent.children[1];
            FillValue(values, Variant(attrEdit.selection));
        end
    elseif (type == VAR_RESOURCEREF) then
        local attrEdit = parent.children[0];
        local ref;
        ref.name = Trimmed(attrEdit.text);
        ref.type = StringHash(attrEdit.vars:GetUInt(TYPE_VAR));
        FillValue(values, Variant(ref));
    else
        local value = attrEdit.text;
        SanitizeNumericalValue(type, value);
        for i = 1, #values do
            local data = Split(values[i]:ToString(), ' ');
            data[coordinate] = value;
            values[i] = Variant(type, Join(data, " "));
        end
    end
end

function UpdateAttributes(serializables, list, fullUpdate)
    -- If attributes have changed structurally, do a full update
    local count = GetAttributeEditorCount(serializables);
    if (fullUpdate == false) then
        if (list.contentElement.numChildren ~= count) then
            fullUpdate = true;
        end
    end

    -- Remember the old scroll position so that a full update does not feel as jarring
    local oldViewPos = list.viewPosition;

    if (fullUpdate) then
        list:RemoveAllItems();
        local children = list:GetChildren();
        for i = 1, #children do
            if (not children[i].internal) then
                children[i]:Remove();
            end
        end
    end

    if (empty(serializables)) then
        return;
    end

    -- If there are many serializables, they must share same attribute structure (up to certain number if not all)
    for i = 0, serializables[1].numAttributes do
        local info = serializables[1].attributeInfos[i];
        if (not showNonEditableAttribute and ifor(info.mode , AM_NOEDIT) ~= 0) then
        else
            -- Use the default value (could be instance's default value) of the first serializable as the default for all
            info.defaultValue = serializables[1].attributeDefaults[i];

            if (fullUpdate) then
                CreateAttributeEditor(list, serializables, info, i, 0);
            end

            LoadAttributeEditor(list, serializables, info, i);
        end
    end

    if (fullUpdate) then
        list.viewPosition = oldViewPos;
    end
end

function EditScriptAttributes(component, index)
    if (component ~= nil and component.typeName:Contains("ScriptInstance")) then
        local hash = GetComponentAttributeHash(component, index);
        if (empty(hash)) then
            scriptAttributes[hash] = component.attributes[index];
        end
    end
end

function CreateDragSlider(parent)
    local dragSld = Button:new();
    dragSld.style = "EditorDragSlider";
    dragSld:SetFixedHeight(ATTR_HEIGHT - 3);
    dragSld:SetFixedWidth(dragSld.height);
    dragSld.SetAlignment(HA_RIGHT, VA_TOP);
    dragSld.focusMode = FM_NOTFOCUSABLE;
    parent:AddChild(dragSld);

    SubscribeToEvent(dragSld, "DragBegin", "LineDragBegin");
    SubscribeToEvent(dragSld, "DragMove", "LineDragMove");
    SubscribeToEvent(dragSld, "DragEnd", "LineDragEnd");
    SubscribeToEvent(dragSld, "DragCancel", "LineDragCancel");
end

function EditAttribute(eventType, eventData)
    -- Changing elements programmatically may cause events to be sent. Stop possible infinite loop in that case.
    if (inLoadAttributeEditor) then
        return;
    end

    local attrEdit = eventData["Element"]:GetPtr();
    local parent = attrEdit.parent;
    local serializables = GetAttributeEditorTargets(attrEdit);
    if (empty(serializables)) then
        return;
    end

    local index = attrEdit.vars:GetUInt("Index");
    local subIndex = attrEdit.vars:GetUInt("SubIndex");
    local coordinate = attrEdit.vars:GetUInt("Coordinate");
    local intermediateEdit = eventType == TEXT_CHANGED_EVENT_TYPE;

    -- Do the editor pre logic before attribute is being modified
    if (not PreEditAttribute(serializables, index)) then
        return;
    end

    inEditAttribute = true;

    local oldValues = {};

    if (not dragEditAttribute) then
        -- Store old values so that PostEditAttribute can create undo actions
        for i = 1, #serializables do
            Push(oldValues, serializables[i].attributes[index]);
        end
    end 

    StoreAttributeEditor(parent, serializables, index, subIndex, coordinate);
    for i = 1, #serializables do
        serializables[i]:ApplyAttributes();
    end
    
    if (not dragEditAttribute) then
        -- Do the editor post logic after attribute has been modified.
        PostEditAttribute(serializables, index, oldValues);
    end 

    -- Update the stored script attributes if this is a ScriptInstance
    EditScriptAttributes(serializables[0], index);

    inEditAttribute = false;

    -- If not an intermediate edit, reload the editor fields with validated values
    -- (attributes may have interactions; therefore we load everything, not just the value being edited)
    if (not intermediateEdit) then
        attributesDirty = true;
    end
end

function LineDragBegin(eventType, eventData)
    local label = eventData["Element"]:GetPtr();
    local x = eventData["X"]:GetInt();
    label:SetVar(StringHash("posX"), Variant(x));

    -- Store the old value before dragging
    dragEditAttribute = false;
    local selectedNumEditor = label.parent;

    selectedNumEditor:SetVar(StringHash("DragBeginValue"), Variant(selectedNumEditor.text));
    selectedNumEditor.cursorPosition = 0;

    -- Set mouse mode to user preference
    SetMouseMode(true);
end

function LineDragMove(eventTypem, eventData)
    local label = eventData["Element"]:GetPtr();
    local selectedNumEditor = label.parent;

    -- Prevent undo
    dragEditAttribute = true;

    local x = eventData["X"]:GetInt();
    local posx = label:GatVar(StringHash("posX")):GetInt();
    local val = input.mouseMoveX;

    local fieldVal = ToFloat(selectedNumEditor.text);
    fieldVal = fieldVal + val/100;
    label:SetVar(StringHash("posX"), Variant(x));
    selectedNumEditor.text = fieldVal;
    selectedNumEditor.cursorPosition = 0;
end

function LineDragEnd(eventType, eventData)
    local label = eventData["Element"]:GetPtr();
    local selectedNumEditor = label.parent;

    -- Prepare the attributes to store an undo with:
    -- - old value = drag begin value
    -- - new value = final value

    local finalValue = selectedNumEditor.text;
    -- Reset attribute to begin value, and prevent 
    dragEditAttribute = true;
    selectedNumEditor.text = selectedNumEditor:GetVar(StringHash("DragBeginValue")):GetString();

    -- Store final value, allow undo
    dragEditAttribute = false;
    selectedNumEditor.text = finalValue;
    selectedNumEditor.cursorPosition = 0;

    -- Revert mouse to normal behaviour
    SetMouseMode(false);
end

function LineDragCancel(eventType, eventData)
    local label = eventData["Element"]:GetPtr();

    -- Reset value to what it was when drag edit began, preventing undo.
    dragEditAttribute = true;
    local selectedNumEditor = label.parent;
    selectedNumEditor.text = selectedNumEditor:GetVar(StringHash("DragBeginValue")):GetString();
    selectedNumEditor.cursorPosition = 0;

    -- Revert mouse to normal behaviour
    SetMouseMode(false);
end

-- Resource picker functionality
ACTION_PICK = 1;
ACTION_OPEN = 2;
ACTION_EDIT = 4;
ACTION_TEST = 8;

ResourcePicker = {
    typeName = '',
    type = 0,
    lastPath = '',
    lastFilter = 0,
    filters = {},
    actions = 0
};

function ResourcePicker.new(typeName_, filter_, actions_ )
    local self = simpleclass(ResourcePicker);
    if (actions_ == nil) then
        actions_ = bitor2(ACTION_PICK , ACTION_OPEN)
    end
    self.typeName = typeName_;
    self.type = StringHash(typeName_);
    self.actions = actions_;
    if (type(filter_) == 'table') then
        self.filters = filter_;
    else
        Push(self.filters, filter_);
    end
    Push(self.filters, "*.*");
    self.lastFilter = 0;
    return self;
end


resourcePickers = {}; -- Array<ResourcePicker@> 
resourceTargets = {}; -- Array<Serializable@> 
resourcePickIndex = 0;
resourcePickSubIndex = 0;
resourcePicker = nil; -- ResourcePicker

function InitResourcePicker()
    -- Fill resource picker data
    local fontFilters = {"*.ttf", "*.otf", "*.fnt", "*.xml"};
    local imageFilters = {"*.png", "*.jpg", "*.bmp", "*.tga"};
    local luaFileFilters = {"*.lua", "*.luc"};
    local scriptFilters = {"*.as", "*.asc"};
    local soundFilters = {"*.wav","*.ogg"};
    local textureFilters = {"*.dds", "*.png", "*.jpg", "*.bmp", "*.tga", "*.ktx", "*.pvr"};
    local materialFilters = {"*.xml", "*.material"};
    local anmSetFilters = {"*.scml"};
    local pexFilters = {"*.pex"};
    local tmxFilters = {"*.tmx"};
    Push(resourcePickers, ResourcePicker.new("Animation", "*.ani", bitor2(ACTION_PICK , ACTION_TEST)));
    Push(resourcePickers, ResourcePicker.new("Font", fontFilters));
    Push(resourcePickers, ResourcePicker.new("Image", imageFilters));
    Push(resourcePickers, ResourcePicker.new("LuaFile", luaFileFilters));
    Push(resourcePickers, ResourcePicker.new("Material", materialFilters, bitor3(ACTION_PICK , ACTION_OPEN , ACTION_EDIT)));
    Push(resourcePickers, ResourcePicker.new("Model", "*.mdl", ACTION_PICK));
    Push(resourcePickers, ResourcePicker.new("ParticleEffect", "*.xml", bitor3(ACTION_PICK , ACTION_OPEN , ACTION_EDIT)));
    Push(resourcePickers, ResourcePicker.new("ScriptFile", scriptFilters));
    Push(resourcePickers, ResourcePicker.new("Sound", soundFilters));
    Push(resourcePickers, ResourcePicker.new("Technique", "*.xml"));
    Push(resourcePickers, ResourcePicker.new("Texture2D", textureFilters));
    Push(resourcePickers, ResourcePicker.new("TextureCube", "*.xml"));
    Push(resourcePickers, ResourcePicker.new("Texture3D", "*.xml"));
    Push(resourcePickers, ResourcePicker.new("XMLFile", "*.xml"));
    Push(resourcePickers, ResourcePicker.new("Sprite2D", textureFilters, bitor2(ACTION_PICK , ACTION_OPEN)));
    Push(resourcePickers, ResourcePicker.new("AnimationSet2D", anmSetFilters, bitor2(ACTION_PICK , ACTION_OPEN)));
    Push(resourcePickers, ResourcePicker.new("ParticleEffect2D", pexFilters, bitor2(ACTION_PICK , ACTION_OPEN)));
    Push(resourcePickers, ResourcePicker.new("TmxFile2D", tmxFilters, bitor2(ACTION_PICK , ACTION_OPEN)));
end

function GetResourcePicker(resourceType)
    for i = 1, #resourcePickers do
        if (resourcePickers[i].type == resourceType) then
            return resourcePickers[i];
        end
    end
    return nil;
end

function PickResource(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local attrEdit = button.parent.children[0];

    local targets = GetAttributeEditorTargets(attrEdit);
    if (empty(targets)) then
        return;
    end

    resourcePickIndex = attrEdit:GetVar(StringHash("Index")):GetUInt();
    resourcePickSubIndex = attrEdit:GetVar(StringHash("SubIndex")):GetUInt();
    local info = targets[0].attributeInfos[resourcePickIndex];

    local resourceType;
    if (info.type == VAR_RESOURCEREF) then
        resourceType = targets[0].attributes[resourcePickIndex]:GetResourceRef().type;
    elseif (info.type == VAR_RESOURCEREFLIST) then
        resourceType = targets[0].attributes[resourcePickIndex]:GetResourceRefList().type;
    elseif (info.type == VAR_VARIANTVECTOR) then
        resourceType = targets[0].attributes[resourcePickIndex]:GetVariantVector()[resourcePickSubIndex]:GetResourceRef().type;
    end

    resourcePicker = GetResourcePicker(resourceType);
    if (resourcePicker == nil) then
        return;
    end

    Clear(resourceTargets);
    for i = 1, #targets do
        resourceTargets.Push(targets[i]);
    end

    local lastPath = resourcePicker.lastPath;
    if (empty(lastPath)) then
        lastPath = sceneResourcePath;
    end
    CreateFileSelector("Pick " .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter);
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickResourceDone");
end

function PickResourceDone(eventType, eventData)
    StoreResourcePickerPath();
    CloseFileSelector();

    if (not eventData["OK"]:GetBool()) then
        Clear(resourceTargets);
        resourcePicker = nil;
        return;
    end

    if (resourcePicker == nil) then
        return;
    end

    -- Validate the resource. It must come from within a registered resource directory, and be loaded successfully
    local resourceName = eventData["FileName"]:GetString();
    local res = GetPickedResource(resourceName);
    if (res == nil) then
        resourcePicker = nil;
        return;
    end

    -- Store old values so that PostEditAttribute can create undo actions
    local oldValues = {};
    for i = 1, #resourceTargets do
        Push(oldValues, resourceTargets[i].attributes[resourcePickIndex]);
    end

    for i = 1, #resourceTargets do
        local target = resourceTargets[i];
        local info = target.attributeInfos[resourcePickIndex];
        if (info.type == VAR_RESOURCEREF) then
            local ref = target.attributes[resourcePickIndex]:GetResourceRef();
            ref.type = res.type;
            ref.name = res.name;
            target.attributes[resourcePickIndex] = Variant(ref);
            target.ApplyAttributes();
        elseif (info.type == VAR_RESOURCEREFLIST) then
            local refList = target.attributes[resourcePickIndex]:GetResourceRefList();
            if (resourcePickSubIndex < refList.length) then
                refList.names[resourcePickSubIndex] = res.name;
                target.attributes[resourcePickIndex] = Variant(refList);
                target.ApplyAttributes();
            end 
        elseif (info.type == VAR_VARIANTVECTOR) then
            local attrs = target.attributes[resourcePickIndex]:GetVariantVector();
            local ref = attrs[resourcePickSubIndex]:GetResourceRef();
            ref.type = res.type;
            ref.name = res.name;
            attrs[resourcePickSubIndex] = ref;
            target.attributes[resourcePickIndex] = Variant(attrs);
            target.ApplyAttributes();
        end

        EditScriptAttributes(target, resourcePickIndex);
    end

    PostEditAttribute(resourceTargets, resourcePickIndex, oldValues);
    UpdateAttributeInspector(false);

    resourceTargets.Clear();
    resourcePicker = nil;
end

function StoreResourcePickerPath()
    -- Store filter and directory for next time
    if (resourcePicker ~= nil and uiFileSelector ~= nil) then
        resourcePicker.lastPath = uiFileSelector.path;
        resourcePicker.lastFilter = uiFileSelector.filterIndex;
    end
end

function GetPickedResource(resourceName)
    resourceName = GetResourceNameFromFullName(resourceName);
    local type = resourcePicker.typeName;
    -- Cube and 3D textures both use .xml extension. In that case interrogate the proper resource type
    -- from the file itself
    if (type == "Texture3D" or type == "TextureCube") then
        local xmlRes = cache:GetResource("XMLFile", resourceName);
        if (xmlRes ~= nil) then
            if (xmlRes.root.name.Compare("cubemap", false) == 0 or xmlRes.root.name:Compare("texturecube", false) == 0) then
                type = "TextureCube";
            elseif (xmlRes.root.name.Compare("texture3d", false) == 0) then
                type = "Texture3D";
            end
        end
    end

    local res = cache:GetResource(type, resourceName);

    if (res == nil) then
        log:Warning("Cannot find resource type: " .. type .. " Name:" .. resourceName);
    end

    return res;
end

function GetResourceNameFromFullName(resourceName)
    local resourceDirs = cache.resourceDirs;
    for i = 1, #resourceDirs do
        if (StartsWith(ToLower(resourceName, ToLower(resourceDirs[i])))) then
            return resourceName.Substring(resourceDirs[i].length);
        end
    end
    
    return ""; -- Not found
end

function OpenResource(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local attrEdit = button.parent.children[0];

    local fileName = attrEdit.text.Trimmed();
    if (empty(fileName)) then
        return;
    end

    OpenResource(fileName);
end

function OpenResource(fileName)
    local resourceDirs = cache.resourceDirs;
    for i = 1, #resourceDirs do
        local fullPath = resourceDirs[i] .. fileName;
        if (fileSystem:FileExists(fullPath)) then
            fileSystem:SystemOpen(fullPath, "");
            return;
        end
    end
end

function EditResource(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local attrEdit = button.parent.children[0];

    local fileName = Trimmed(attrEdit.text);
    if (empty(fileName)) then
        return;
    end

    resourceType = attrEdit:GetVar(TYPE_VAR):GetUInt();
    local resource = cache:GetResource(resourceType, fileName);

    if (resource ~= nil) then
        -- For now only Materials can be edited
        if (resource.typeName == "Material") then
            EditMaterial(tolua.cast(resource, "Material"));
        elseif (resource.typeName == "ParticleEffect") then
            EditParticleEffect(tolua.cast(resource, "ParticleEffect"));
        end
    end
end

function TestResource(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local attrEdit = button.parent.children[0];

    resourceType(attrEdit:GetVar(TYPE_VAR):GetUInt());
    
    -- For now only Animations can be tested
    animType("Animation");
    if (resourceType == animType) then
        TestAnimation(attrEdit);
    end
end

function TestAnimation(attrEdit)
    -- Note: only supports the AnimationState array in AnimatedModel, and if only 1 model selected
    local targets = GetAttributeEditorTargets(attrEdit);
    if (targets.length ~= 1) then
        return;
    end
    local model = tolua.cast(targets[0], "AnimatedModel");
    if (model == nil) then
        return;
    end

    local animStateIndex = (attrEdit:GetVar(StringHash("SubIndex")):GetUInt() - 1) / 6;
    if (testAnimState:Get() == nil) then
        testAnimState = model:GetAnimationState(animStateIndex);
        local animState = testAnimState:Get();
        if (animState ~= nil) then
            animState.time = 0; -- Start from beginning
        end
    else
        testAnimState = nil;
    end
end

function UpdateTestAnimation(timeStep)
    local animState = testAnimState:Get();
    if (animState ~= nil) then
        -- If has also an AnimationController, and scene update is enabled, check if it is also driving the animation
        -- and skip in that case (afunction double speed animation)
        if (runUpdate) then
            local model = animState.model;
            if (model ~= nil) then
                local node = model.node;
                if (node ~= nil) then
                    local ctrl = node.GetComponent("AnimationController");
                    local anim = animState.animation;
                    if (ctrl ~= nil and anim ~= nil) then
                        if (ctrl:IsPlaying(anim.name)) then
                            return;
                        end
                    end
                end
            end
        end

        animState:AddTime(timeStep);
    end
end

-- VariantVector decoding & editing for certain components
VectorStruct = {
    componentTypeName = '',
    attributeName = '',
    variableNames = {},
    restartIndex = 0
};

function VectorStruct.new(componentTypeName_, attributeName_, variableNames_, restartIndex_)
    local self = simpleclass(VectorStruct);
    self.componentTypeName = componentTypeName_;
    self.attributeName = attributeName_;
    self.variableNames = variableNames_;
    self.restartIndex = restartIndex_;
    return self;
end

vectorStructs = {};

function InitVectorStructs()
    -- Fill vector structure data
    local billboardVariables = {
        "Billboard Count",
        "   Position",
        "   Size",
        "   UV Coordinates",
        "   Color",
        "   Rotation",
        "   Is Enabled"
    };
    Push(vectorStructs, VectorStruct.new("BillboardSet", "Billboards", billboardVariables, 1));

    local animationStateVariables = {
        "Anim State Count",
        "   Animation",
        "   Start Bone",
        "   Is Looped",
        "   Weight",
        "   Time",
        "   Layer"
    };
    Push(vectorStructs, VectorStruct.new("AnimatedModel", "Animation States", animationStateVariables, 1));

    local staticModelGroupInstanceVariables = {
        "Instance Count",
        "   NodeID"
    };
    Push(vectorStructs, VectorStruct.new("StaticModelGroup", "Instance Nodes", staticModelGroupInstanceVariables, 1));

    local splinePathInstanceVariables = {
        "Control Point Count",
        "   NodeID"
    };
    Push(vectorStructs, VectorStruct.new("SplinePath", "Control Points", splinePathInstanceVariables, 1));
end

function GetVectorStruct(serializables, index)
    local info = serializables[0].attributeInfos[index];
    for i = 1, #vectorStructs do
        if (vectorStructs[i].componentTypeName == serializables[0].typeName and vectorStructs[i].attributeName == info.name) then
            return vectorStructs[i];
        end
    end
    return nil;
end

function GetAttributeIndex(serializable, attrName)
    for i = 0, serializable.numAttributes - 1 do
        if (serializable.attributeInfos[i].name.Compare(attrName, false) == 0) then
            return i;
        end
    end
    
    return -1;
end
