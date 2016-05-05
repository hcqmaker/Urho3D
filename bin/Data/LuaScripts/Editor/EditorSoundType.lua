-- Urho3D Sound Type manager

soundTypeEditorWindow = nil;
mappings = {};

DEFAULT_SOUND_TYPES_COUNT = 1;

SoundTypeMapping = {}
function SoundTypeMapping:new(key, value) 
	self.key = key;
	self.value = value;
	return simpleclass(SoundTypeMapping);
end

function SoundTypeMapping:Update(value)
	self.value = Clamp(value, 0.0, 1.0);
	audio.masterGain[self.key] = self.value;
end


function CreateSoundTypeEditor()
    if (soundTypeEditorWindow ~= nil) then
        return;
	end
        
    soundTypeEditorWindow = ui:LoadLayout(cache:GetResource("XMLFile", "UI/EditorSoundTypeWindow.xml"));
    ui.root:AddChild(soundTypeEditorWindow);
    soundTypeEditorWindow.opacity = uiMaxOpacity;

    InitSoundTypeEditorWindow();
    RefreshSoundTypeEditorWindow();

    local height = Min(ui.root.height - 60, 750);    
    soundTypeEditorWindow.SetSize(400, 0);
    CenterDialog(soundTypeEditorWindow);

    HideSoundTypeEditor();
    
    SubscribeToEvent(soundTypeEditorWindow:GetChild("CloseButton", true), "Released", "HideSoundTypeEditor");
    SubscribeToEvent(soundTypeEditorWindow:GetChild("AddButton", true), "Released", "AddSoundTypeMapping");
    
    SubscribeToEvent(soundTypeEditorWindow:GetChild("MasterValue", true), "TextFinished", "EditGain");
end

function InitSoundTypeEditorWindow()
    if (not mappings[SOUND_MASTER]) then
        mappings[SOUND_MASTER] = SoundTypeMapping:new(SOUND_MASTER, audio.masterGain[SOUND_MASTER]);
	end

	for k, v in pairs(mappings) do
		if (v ~= nil) then
			AddUserUIElements(key, v);
		end
	end
end

function RefreshSoundTypeEditorWindow()
    RefreshDefaults(soundTypeEditorWindow:GetChild("DefaultsContainer"));
    RefreshUser(soundTypeEditorWindow:GetChild("UserContainer"));
end

function RefreshDefaults(root)
    UpdateMappingValue(SOUND_MASTER, root:GetChild(SOUND_MASTER, true));
end

function RefreshUser(root)
	for k, v in pairs(mappings) do
		if (v ~= nil) then
			UpdateMappingValue(key, root:GetChild(key, true));
		end
	end
end

function UpdateMappingValue(key, root)
    if (root ~= nil) then
        local value = root:GetChild(key .. "Value");
        local mapping = mappings[key];
		if (mapping and value ~= nil) then 
            value.text = mapping.value;
			root:GetVars():SetString("DragDropContent", key);
		end
	end
end

function AddUserUIElements(key, gain)
    local container = soundTypeEditorWindow:GetChild("UserContainer", true);

    local itemParent = UIElement:new();
	container:AddItem(itemParent);

    itemParent.style = "ListRow";
    itemParent.name = key;
    itemParent.layoutSpacing = 10;

    local keyText = Text:new();
    local gainEdit = LineEdit:new();
    local removeButton = Button:new();

	itemParent:AddChild(keyText);
	itemParent:AddChild(gainEdit);
	itemParent:AddChild(removeButton);
    itemParent.dragDropMode = DD_SOURCE;

    keyText.text = key;
    keyText.textAlignment = HA_LEFT;
	keyText:SetStyleAuto();

    gainEdit.maxLength = 4;
    gainEdit.maxWidth = 2147483647;
    gainEdit.minWidth = 100;
    gainEdit.name = key + "Value";
    gainEdit.text = gain;
	gainEdit:SetStyleAuto();

    removeButton.style = "CloseButton";

    SubscribeToEvent(removeButton, "Released", "DeleteSoundTypeMapping");
    SubscribeToEvent(gainEdit, "TextFinished", "EditGain");
end

function AddSoundTypeMapping(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local key = button.parent:GetChild("Key");
    local gain = button.parent:GetChild("Gain");
    
    if (not empty(key.text) and not empty(gain.text)  and mappings[key.text]) then
        local mapping = SoundTypeMapping:new(key.text, ToFloat(gain.text));
    
        mappings[key.text] = mapping;
        AddUserUIElements(key.text, mapping.value);
	end
    
    key.text = "";
    gain.text = "";
    
    RefreshSoundTypeEditorWindow();
end

function DeleteSoundTypeMapping(eventType, eventData)
    local button = eventData["Element"]:GetPtr();
    local parent = button.parent;
    
	mappings[parent.name] = nil;
	parent:Remove();
end

function EditGain(eventType,  eventData)
    local input = eventData["Element"]:GetPtr();
    local key = input.parent.name;
    
    local mapping = mappings[key];
    
	if (mapping) then
        mapping:Update(ToFloat(input.text));
	end
        
    RefreshSoundTypeEditorWindow();
end

function ShowSoundTypeEditor()
    RefreshSoundTypeEditorWindow();
    soundTypeEditorWindow.visible = true;
    soundTypeEditorWindow.BringToFront();
    return true;
end

function HideSoundTypeEditor()
    soundTypeEditorWindow.visible = false;
end

function SaveSoundTypes(root)
	for k, v in pairs(mappings) do
		if (v ~= nil) then
            root:SetFloat(key, mapping.value);
		end
	end
end

function LoadSoundTypes(root)
	for i = 0, root.numAttributes - 1 do
        local key = root:GetAttributeNames()[i];
        local gain = root:GetFloat(key);
    
        if (not empty(key) and not mappings(key)) then
            mappings[key] = SoundTypeMapping:new(key, gain);
		end
	end
end



