

EditActionGroup = {}
actions = {}

CreateNodeAction = {};
function CreateNodeAction.new()
    local self = simpleclass(CreateNodeAction);
	self.nodeID = 0;
	self.parentID = 0;
	self.nodeData = nil;
    return self;
end
function CreateNodeAction:Define(node)
	self.nodeID = node.ID;
	self.parentID = node.parent.ID;
	self.nodeData = XMLFile:new();
	local rootElem = nodeData:CreateRoot("node");
	node:SaveXML(rootElem);
end
function CreateNodeAction:Undo()
	local parent = editorScene:GetNode(self.parentID);
    local node = editorScene:GetNode(self.nodeID);
    if (parent ~= nil and node ~= nil) then
        parent:RemoveChild(node);
        hierarchyList:ClearSelection();
    end
end
function CreateNodeAction:Redo()
	local parent = editorScene:GetNode(self.parentID);
    if (parent ~= nil) then
    	local vv = LOCAL;
    	if (self.nodeID < FIRST_LOCAL_ID) then
    		vv = REPLICATED;
    	end
        local node = parent:CreateChild("",  vv, self.nodeID);
        node:LoadXML(self.nodeData.root);
        FocusNode(node);
    end
end

DeleteNodeAction = {} 
function DeleteNodeAction:new()
	self.nodeID = 0;
	self.parentID = 0;
	self.nodeData = nil;
    return simpleclass(DeleteNodeAction)
end

function DeleteNodeAction:Define(node)
	self.nodeID = node.ID;
	self.parentID = node.parent.ID;
	local rootElem = nodeData:CreateRoot("node")
	node:SaveXML(rootElem);
	rootElem:SetUInt("listItemIndex", GetListIndex(node));
end

function DeleteNodeAction:Undo()
	local parent = editorScene:GetNode(parentID);
	if (parent == nil) then
        -- Handle update manually so that the node can be reinserted back into its previous list index
        suppressSceneChanges = true;

        local ret = LOCAL;
        if (nodeID < FIRST_LOCAL_ID) then
        	ret = REPLICATED;
        end
        local node = parent:CreateChild("", ret, nodeID);
        if (node:LoadXML(nodeData.root)) then
            local listItemIndex = nodeData.root:GetUInt("listItemIndex");
            local parentItem = hierarchyList.items[GetListIndex(parent)];
            UpdateHierarchyItem(listItemIndex, node, parentItem);
            FocusNode(node);
        end

        suppressSceneChanges = false;
    end
end


function DeleteNodeAction:Redo()

    local parent = editorScene:GetNode(self.parentID);
    local node = editorScene:GetNode(self.nodeID);
    if (parent ~= nil and node ~= nil) then
        parent:RemoveChild(node);
        hierarchyList:ClearSelection();
    end
end

ReparentNodeAction = {} 
function ReparentNodeAction:new()
    local self = simpleclass(ReparentNodeAction);
	self.nodeID = 0;
	self.oldParentID = 0;
	self.newParentID = 0;
	self.nodeList = {};
	self.multiple = false;
    return self;
end

function ReparentNodeAction:Define(node, newParent)
	if (type(node) == "table") then
		self.multiple = true;
        self.newParentID = newParent.ID;
        for k, v in pairs(node) do
            table.insert(self.nodeList, v.ID)
            table.insert(self.nodeList, v.parent.ID)
        end
	else
	    self.multiple = false;
	    self.nodeID = node.ID;
	    self.oldParentID = node.parent.ID;
	    self.newParentID = newParent.ID;
	end
end

function ReparentNodeAction:Undo()
    if (self.multiple) then
    	local num = #self.nodeList;
    	for i = 1, num, 2 do
        	local nodeID_ = self.nodeList[i];
            local oldParentID_ = self.nodeList[i+1];
            local parent = editorScene:GetNode(oldParentID_);
            local node = editorScene:GetNode(nodeID_);
            if (parent ~= nil and node ~= nil) then
                node.parent = parent;
            end
        end
    else
        local parent = editorScene:GetNode(self.oldParentID);
        local node = editorScene:GetNode(self.nodeID);
        if (parent ~= nil and node ~= nil) then
            node.parent = parent;
        end
    end
end


function ReparentNodeAction:Redo()
    if (multiple) then
        local parent = editorScene:GetNode(newParentID);
        if (parent == nil) then
            return;
        end

        for i = 1, #self.nodeList, 2 do
            local nodeID_ = nodeList[i];
            local node = editorScene:GetNode(nodeID_);
            if (node ~= nil) then
                node.parent = parent;
            end
        end
    else
        local parent = editorScene:GetNode(newParentID);
        local node = editorScene:GetNode(nodeID);
        if (parent ~= nil and node ~= nil) then
            node.parent = parent;
        end
    end
end

CreateComponentAction = {}
function CreateComponentAction:new()
	self.nodeID = 0;
	self.componentID = 0;
	self.componentData = nil;
    return simpleclass(CreateComponentAction)
end

function CreateComponentAction:Define(component)
	self.componentID = component.ID;
    self.nodeID = component.node.ID;
    self.componentData = XMLFile:new();
    local rootElem = componentData:CreateRoot("component");
    component:SaveXML(rootElem);
end

function CreateComponentAction:Redo()
    local node = editorScene.GetNode(nodeID);
    if (node ~= nil) then
    	local ret = LOCAL;
    	if (self.componentID < FIRST_LOCAL_ID) then
    		ret = REPLICATED;
    	end
        local component = node:CreateComponent(self.componentData.root:GetAttribute("type"), ret, self.componentID);
        component:LoadXML(componentData.root);
        component:ApplyAttributes();
        FocusComponent(component);
    end
end

DeleteComponentAction = {}
function DeleteComponentAction.new()
    local self = simpleclass(DeleteComponentAction)
	self.nodeID = 0;
	self.componentID = 0;
	self.componentData = nil;
    return self;
end

function DeleteComponentAction:Define(component)
	self.componentID = component.ID;
	self.nodeID = component.node.ID;
	self.componentData = XMLFile:new();
	local rootElem = self.componentData:CreateRoot("component");
	component:SaveXML(rootElem);
	rootElem:SetUInt("listItemIndex", GetComponentListIndex(component));
end

function DeleteComponentAction:Undo()
	local node = editorScene:GetNode(self.nodeID);
    if (node ~= nil) then
        -- Handle update manually so that the component can be reinserted back into its previous list index
        suppressSceneChanges = true;

        local component = node:CreateComponent(componentData.root.GetAttribute("type"), returnor(componentID < FIRST_LOCAL_ID, REPLICATED,LOCAL), componentID);
        if (component:LoadXML(componentData.root)) then
            component:ApplyAttributes();

            local listItemIndex = componentData.root:GetUInt("listItemIndex");
            local parentItem = hierarchyList.items[GetListIndex(node)];
            UpdateHierarchyItem(listItemIndex, component, parentItem);
            FocusComponent(component);
        end

        suppressSceneChanges = false;
    end
end

function DeleteComponentAction:Redo()
    local node = editorScene:GetNode(self.nodeID);
    local component = editorScene:GetComponent(self.componentID);
    if (node ~= nil and component ~= nil) then
        node:RemoveComponent(component);
        hierarchyList:ClearSelection();
    end
end

EditAttributeAction = {};
function EditAttributeAction:new()
	self.targetType = 0;
	self.targetID = 0;
	self.attrIndex = 0;
	self.undoValue = nil;
	self.redoValue = nil;
    return simpleclass(EditAttributeAction)
end

function EditAttributeAction:Define(target, index, oldValue)

    self.attrIndex = index;
    self.undoValue = oldValue;
    self.redoValue = target.attributes[index];

    self.targetType = GetType(target);
    self.targetID = GetID(target, targetType);
end

function EditAttributeAction:GetTarget()
	if (targetType == ITEM_NODE) then
        return editorScene:GetNode(targetID);
    elseif (targetType == ITEM_COMPONENT) then
        return editorScene:GetComponent(targetID);
    elseif (targetType == ITEM_UI_ELEMENT) then
        return GetUIElementByID(targetID);
    end

    return nil;
end

function EditAttributeAction:Undo()
	local target = self:GetTarget();
    if (target ~= nil) then
        target.attributes[attrIndex] = undoValue;
        target:ApplyAttributes();
        -- Can't know if need a full update, so assume true
        attributesFullDirty = true;
        -- Apply side effects
        PostEditAttribute(target, attrIndex);

        if (targetType == ITEM_UI_ELEMENT) then
            SetUIElementModified(target);
        else
            SetSceneModified();
        end
            
        EditScriptAttributes(target, attrIndex);
    end
end

function EditAttributeAction:Redo()
    local target = GetTarget();
    if (target ~= nil) then
        target.attributes[attrIndex] = redoValue;
        target:ApplyAttributes();
        -- Can't know if need a full update, so assume true
        attributesFullDirty = true;
        -- Apply side effects
        PostEditAttribute(target, attrIndex);

        if (targetType == ITEM_UI_ELEMENT) then
            SetUIElementModified(target);
        else
            SetSceneModified();
        end
            
        EditScriptAttributes(target, attrIndex);
    end
end


ResetAttributesAction = {} 
function ResetAttributesAction:new()
	self.targetType = 0;
    self.targetID = 0;
    self.undoValues = {};
    self.internalVars = VariantMap:new();
    return simpleclass(ResetAttributesAction)
end

function ResetAttributesAction:Define(target)

	for i = 0, target.numAttributes - 1 do
		table.insert(self.undoValues, target.attributes[i]);
	end

    self.targetType = GetType(target);
    self.targetID = GetID(target, targetType);

    if (targetType == ITEM_UI_ELEMENT) then
        -- Special handling for UIElement to preserve the internal variables containing the element's generated ID among others
        local element = target;
        local keys = element:GetVars().keys;
        for k,v in pairs(keys) do
            -- If variable name is empty (or unregistered) then it is an internal variable and should be preserved
            local name = GetVarName(v);
            if (name == nil) then
            	internalVars:SetInt(v, element:GetVar(v));
            end
        end
    end
end

function ResetAttributesAction:GetTarget()

    if (targetType == ITEM_NODE) then
        return editorScene.GetNode(targetID);
    elseif targetType == ITEM_COMPONENT then
        return editorScene.GetComponent(targetID);
    elseif targetType == ITEM_UI_ELEMENT then
        return GetUIElementByID(targetID);
    end

    return nil;
end

function ResetAttributesAction:SetInternalVars(element)

    -- Revert back internal variables
    local keys = self.internalVars.keys;
    for k, v in ipairs(keys) do
        element:SetInt(v, internalVars[v]);
    end

    if (element:GetVar(FILENAME_VAR) ~= nil) then
        CenterDialog(element);
    end
end

function ResetAttributesAction:Undo()
    ui.cursor.shape = CS_BUSY;

    local target = GetTarget();
    if (target ~= nil) then
        for i = 0, target.numAttributes - 1 do
            local info = target.attributeInfos[i];
            if (bitand2(info.mode, AM_NOEDIT) ~= 0 or bitand2(info.mode, AM_NODEID) ~= 0 or bitand2(info.mode, AM_COMPONENTID) ~= 0) then
            else
                target.attributes[i] = undoValues[i];
            end
        end
        target:ApplyAttributes();

        -- Apply side effects
        for i = 0, target.numAttributes - 1 do
            PostEditAttribute(target, i);
        end
        if (targetType == ITEM_UI_ELEMENT) then
            SetUIElementModified(target);
        else
            SetSceneModified();
        end

        attributesFullDirty = true;
    end
end

function ResetAttributesAction:Redo()
    ui.cursor.shape = CS_BUSY;

    local target = GetTarget();
    if (target ~= nil) then
        for i = 0, target.numAttributes - 1 do
            local info = target.attributeInfos[i];
            if (bitand2(info.mode, AM_NOEDIT) ~= 0 or bitand2(info.mode, AM_NODEID) ~= 0 or bitand2(info.mode, AM_COMPONENTID) ~= 0) then
            else
                target.attributes[i] = target.attributeDefaults[i];
            end
        end
        if (targetType == ITEM_UI_ELEMENT) then
            SetInternalVars(target);
        end
        target:ApplyAttributes();

        -- Apply side effects
        for i = 0, target.numAttributes - 1 do
            PostEditAttribute(target, i);
        end

        if (targetType == ITEM_UI_ELEMENT) then
            SetUIElementModified(target);
        else
            SetSceneModified();
        end

        attributesFullDirty = true;
    end
end

ToggleNodeEnabledAction = {}
function ToggleNodeEnabledAction:new()
    self.nodeID = 0;
    self.undoValue = false;
    return simpleclass(ToggleNodeEnabledAction)
end


function ToggleNodeEnabledAction:Define(node, oldEnabled)
    self.nodeID = node.ID;
    self.undoValue = oldEnabled;
end


function ToggleNodeEnabledAction:Undo()
     local node = editorScene:GetNode(nodeID);
    if (node ~= nil) then
        node:SetEnabledRecursive(self.undoValue);
    end
end

function ToggleNodeEnabledAction:Redo()
    local node = editorScene.GetNode(nodeID);
    if (node ~= nil) then
        node:SetEnabledRecursive(not self.undoValue);
    end
end



Transform = {}
function Transform:new()
    self.position = nil;
    self.rotation = nil;
    self.scale = nil;
    return simpleclass(Transform)
end

function Transform:Define(node)
    self.position = node.position;
    self.rotation = node.rotation;
    self.scale = node.scale;
end

function Transform:Apply(node)
    node:SetTransform(self.position, self.rotation, self.scale);
end


EditNodeTransformAction = {}
function EditNodeTransformAction:new()
    self.nodeID = 0;
    self.undoTransform = nil;
    seof.redoTransform = nil;
    return simpleclass(EditNodeTransformAction)
end


function EditNodeTransformAction:Define(node, oldTransform)

    self.nodeID = node.ID;
    self.undoTransform = oldTransform;
    self.redoTransform:Define(node);
end

function EditNodeTransformAction:Undo()
    local node = editorScene:GetNode(nodeID);
    if (node ~= nil) then
        self.undoTransform:Apply(node);
        UpdateNodeAttributes();
    end
end

function EditNodeTransformAction:Redo()
    local node = editorScene:GetNode(self.nodeID);
    if (node ~= nil) then
        self.redoTransform:Apply(node);
        UpdateNodeAttributes();
    end
end


CreateUIElementAction = {}
function CreateUIElementAction:new()
    self.elementID = nil;
    self.parentID = nil;
    self.elementData = nil;
    self.styleFile  = nil;
    return simpleclass(CreateUIElementAction)
end

function CreateUIElementAction:Define(element)
    self.elementID = GetUIElementID(element);
    self.parentID = GetUIElementID(element.parent);
    self.elementData = XMLFile:new();
    local rootElem = elementData:CreateRoot("element");
    element:SaveXML(rootElem);
    self.styleFile = element.defaultStyle;
end

function CreateUIElementAction:Undo()
    local parent = GetUIElementByID(self.parentID);
    local element = GetUIElementByID(self.elementID);
    if (parent ~= nil and element ~= nil) then
        parent:RemoveChild(element);
        hierarchyList:ClearSelection();
        SetUIElementModified(parent);
    end
end

function CreateUIElementAction:Redo()

    local parent = GetUIElementByID(parentID);
    if (parent ~= nil) then
        -- Have to update manually because the element ID var is not set yet when the E_ELEMENTADDED event is sent
        suppressUIElementChanges = true;

        if (parent:LoadChildXML(elementData.root, styleFile)) then
            local element = parent.children[parent.numChildren - 1];
            UpdateHierarchyItem(element);
            FocusUIElement(element);
            SetUIElementModified(parent);
        end

        suppressUIElementChanges = false;
    end
end

DeleteUIElementAction = {}
function DeleteUIElementAction:new()
    self.elementID = nil;
    self.parentID = nil;
    self.elementData = nil;
    self.styleFile = nil;
    return simpleclass(DeleteUIElementAction)
end

function DeleteUIElementAction:Define(element)

    self.elementID = GetUIElementID(element);
    self.parentID = GetUIElementID(element.parent);
    self.elementData = XMLFile:new();
    local rootElem = elementData:CreateRoot("element");
    element:SaveXML(rootElem);
    rootElem:SetUInt("index", element.parent.FindChild(element));
    rootElem:SetUInt("listItemIndex", GetListIndex(element));
    self.styleFile = element.defaultStyle;
end


function DeleteUIElementAction:Undo()

    local parent = GetUIElementByID(parentID);
    if (parent ~= nil) then
    
        -- Have to update manually because the element ID var is not set yet when the E_ELEMENTADDED event is sent
        suppressUIElementChanges = true;

        if (parent:LoadChildXML(elementData.root, styleFile)) then
        
            local rootElem = elementData.root;
            local index = rootElem:GetUInt("index");
            local listItemIndex = rootElem:GetUInt("listItemIndex");
            local element = parent.children[index];
            local parentItem = hierarchyList.items[GetListIndex(parent)];
            UpdateHierarchyItem(listItemIndex, element, parentItem);
            FocusUIElement(element);
            SetUIElementModified(parent);
        end

        suppressUIElementChanges = false;
    end
end


function DeleteUIElementAction:Redo()
    local parent = GetUIElementByID(self.parentID);
    local element = GetUIElementByID(self.elementID);
    if (parent ~= nil and element ~= nil) then
        parent:RemoveChild(element);
        hierarchyList:ClearSelection();
        SetUIElementModified(parent);
    end
end

ReparentUIElementAction = {}
function ReparentUIElementAction:new()
    self.elementID = nil;
    self.oldParentID = nil;
    self.oldChildIndex = 0;
    self.newParentID = nil;
    return simpleclass(ReparentUIElementAction)
end
function ReparentUIElementAction:Define(element, newParent)

    self.elementID = GetUIElementID(element);
    self.oldParentID = GetUIElementID(element.parent);
    self.oldChildIndex = element.parent:FindChild(element);
    self.newParentID = GetUIElementID(newParent);
end

function ReparentUIElementAction:Undo()

    local parent = GetUIElementByID(self.oldParentID);
    local element = GetUIElementByID(self.elementID);
    if (parent ~= nil and element ~= nil) then
        element:SetParent(parent, self.oldChildIndex);
        SetUIElementModified(parent);
    end
end

function ReparentUIElementAction:Redo()

    local parent = GetUIElementByID(self.newParentID);
    local element = GetUIElementByID(self.elementID);
    if (parent ~= nil and element ~= nil) then
        element.parent = parent;
        SetUIElementModified(parent);
    end
end

ApplyUIElementStyleAction = {}
function ApplyUIElementStyleAction:new()
    self.elementID = nil;
    self.parentID = nil;
    self.elementData = nil;
    self.styleFile = nil;
    self.elementOldStyle = '';
    self.elementNewStyle = '';
    return simpleclass(ApplyUIElementStyleAction)
end

function ApplyUIElementStyleAction:Define(element, newStyle)

    self.elementID = GetUIElementID(element);
    self.parentID = GetUIElementID(element.parent);
    self.elementData = XMLFile:new();
    local rootElem = elementData:CreateRoot("element");
    element:SaveXML(rootElem);
    rootElem:SetUInt("index", element.parent:FindChild(element));
    rootElem:SetUInt("listItemIndex", GetListIndex(element));
    self.styleFile = element.defaultStyle;
    self.elementOldStyle = element.style;
    self.elementNewStyle = newStyle;
end

function ApplyUIElementStyleAction:ApplyStyle(style)

    local parent = GetUIElementByID(self.parentID);
    local element = GetUIElementByID(self.elementID);
    if (parent ~= nil and element ~= nil) then
        -- Apply the style in the XML data
        elementData.root:SetAttribute("style", style);

        -- Have to update manually because the element ID var is not set yet when the E_ELEMENTADDED event is sent
        suppressUIElementChanges = true;

        parent:RemoveChild(element);
        if (parent:LoadChildXML(elementData.root, styleFile)) then
            local rootElem = elementData.root;
            local index = rootElem:GetUInt("index");
            local listItemIndex = rootElem:GetUInt("listItemIndex");
            local element = parent.children[index];
            local parentItem = hierarchyList.items[GetListIndex(parent)];
            UpdateHierarchyItem(listItemIndex, element, parentItem);
            SetUIElementModified(element);
            table.insert(hierarchyUpdateSelections, listItemIndex)
       end

        suppressUIElementChanges = false;
   end
end

function ApplyUIElementStyleAction:Undo()
    self:ApplyStyle(elementOldStyle);
end

function ApplyUIElementStyleAction:Redo()
    self:ApplyStyle(elementNewStyle);
end


EditMaterialAction = {}
function EditMaterialAction:new()
    self.oldState = nil;
    self.newState = nil;
    self.material = nil;
    return simpleclass(EditMaterialAction)
end

function EditMaterialAction:Define(material_, oldState_)

    self.material = material_;
    self.oldState = oldState_;
    self.newState = XMLFile:new();

    local materialElem = self.newState:CreateRoot("material");
    material_:Save(materialElem);

    return simpleclass(EditMaterialAction)
end

function EditMaterialAction:Undo()
    local mat = self.material:Get();
    if (mat ~= nil) then
        mat:Load(self.oldState.root);
        RefreshMaterialEditor();
    end
end

function EditMaterialAction:Redo()
    local mat = self.material:Get();
    if (mat ~= nil) then
        mat:Load(self.newState.root);
        RefreshMaterialEditor();
    end
end

EditParticleEffectAction = {}
function EditParticleEffectAction:new()
    self.oldState = nil;
    self.newState = nil;
    self.particleEffect = nil;
    self.particleEmitter = nil;
    return simpleclass(EditParticleEffectAction)
end

function EditParticleEffectAction:Define(particleEmitter_, particleEffect_, oldState_)
    self.particleEmitter = particleEmitter_;
    self.particleEffect = particleEffect_;
    self.oldState = oldState_;
    self.newState = XMLFile:new();
    local particleElem = self.newState:CreateRoot("particleeffect");
    particleEffect_:Save(particleElem);
end

function EditParticleEffectAction:Undo()

    local effect = self.particleEffect:Get();
    if (effect ~= nil) then
        effect:Load(self.oldState.root);
        particleEmitter:ApplyEffect();
        RefreshParticleEffectEditor();
    end
end

function EditParticleEffectAction:Redo()

    local effect = particleEffect:Get();
    if (effect ~= nil) then
        self.effect:Load(self.newState.root);
        self.particleEmitter:ApplyEffect();
        RefreshParticleEffectEditor();
    end
end

AssignMaterialAction ={}
function AssignMaterialAction:new()
    self.model = nil;
    self.oldMaterials = nil;
    self.newMaterialName = '';
    return simpleclass(AssignMaterialAction)
end


function AssignMaterialAction:Define(model_, oldMaterials_, newMaterial_)

    self.model = model_;
    self.oldMaterials = oldMaterials_;
    self.newMaterialName = newMaterial_.name;
end

function AssignMaterialAction:Undo()
    local staticModel = model:Get();
    if (staticModel == nil) then
        return;
    end

    for k, v in ipairs(self.oldMaterials) do
        local material = cache:GetResource("Material", v);
        staticModel.materials[k - 1] = material;
    end
end

function AssignMaterialAction:Redo()
    local staticModel = self.model:Get();
    if (staticModel == nil) then
        return;
    end
    local material = cache:GetResource("Material", self.newMaterialName);
    staticModel.material = material;
end


AssignModelAction = {}
function AssignModelAction:new()
    self.staticModel = nil;
    self.oldModel = '';
    self.newModel = '';
    return simpleclass(AssignModelAction)
end

function AssignModelAction:Define(staticModel_, oldModel_, newModel_)

    staticModel = staticModel_;
    oldModel = oldModel_.name;
    newModel = newModel_.name;
end

function AssignModelAction:Undo()

    local staticModel_ = staticModel:Get();
    if (staticModel_ == nil) then
        return;
    end

    local model = cache:GetResource("Model", self.oldModel);
    if (model == nil) then
        return;
    end
    staticModel_.model = model;
end

function AssignModelAction:Redo()

    local staticModel_ = self.staticModel:Get();
    if (staticModel_ == nil) then
        return;
    end

    local model = cache:GetResource("Model", self.newModel);
    if (model == nil) then
        return;
    end
    staticModel_.model = model;
end

