
uiStyle = nil;
iconStyle = nil;
uiMenuBar = nil;
quickMenu = nil;
recentSceneMenu = nil;
mruScenesPopup = nil;
quickMenuItems = {}
uiFileSelector = nil;
consoleCommandInterpreter = nil;
contextMenu = nil;

UI_ELEMENT_TYPE = StringHash("UIElement");
WINDOW_TYPE = StringHash("Window")
MENU_TYPE = StringHash("Menu")
TEXT_TYPE = StringHash("Text")
CURSOR_TYPE = StringHash("Cursor")

AUTO_STYLE = ""
TEMP_SCENE_NAME = '_tempscene_.xml'
CALLBACK_VAR = StringHash("Callback");
INDENT_MODIFIED_BY_ICON_VAR = StringHash("IconIndented")
VAR_CONTEXT_MENU_HANDLER = StringHash("ContextMenuHandler")


SHOW_POPUP_INDICATOR = -1;
MAX_QUICK_MENU_ITEMS = 10;

maxRecentSceneCount = 5;

uiSceneFilters = {"*.xml", "*.bin", "*.*"};
uiElementFilters = {"*.xml"};
uiAllFilters = {"*.*"};
uiScriptFilters = {"*.as", "*.*"};
uiParticleFilters = {"*.xml"};
uiRenderPathFilters = {"*.xml"};

uiSceneFilter = 0;
uiElementFilter = 0;
uiNodeFilter = 0;
uiImportFilter = 0;
uiScriptFilter = 0;
uiParticleFilter = 0;
uiRenderPathFilter = 0;
uiScenePath = fileSystem:GetProgramDir() .. "Data/Scenes";
uiElementPath = fileSystem:GetProgramDir() .. "Data/UI";
uiNodePath = fileSystem:GetProgramDir() .. "Data/Objects";
uiImportPath = '';
uiScriptPath = fileSystem:GetProgramDir() .. "Data/Scripts";
uiParticlePath = fileSystem:GetProgramDir() .. "Data/Particles";
uiRenderPathPath = fileSystem:GetProgramDir() .. "CoreData/RenderPaths";
uiRecentScenes = {};
screenshotDir = fileSystem:GetProgramDir() .. "Screenshots";

uiFaded = false;
uiMinOpacity = 0.3;
uiMaxOpacity = 0.7;
uiHidden = false;




function CreateUI()
	
	ui.root:RemoveAllChildren();
	uiStyle = GetEditorUIXMLFile("UI/DefaultStyle.xml");
    ui.root.defaultStyle = uiStyle;
    iconStyle = GetEditorUIXMLFile("UI/EditorIcons.xml");
    CreateLogo();  
	CreateCursor();
	CreateMenuBar();
    CreateToolBar();
    CreateSecondaryToolBar();
    CreateQuickMenu();
    CreateContextMenu();
    CreateHierarchyWindow();
    print("===========>>========>>5");
    CreateAttributeInspectorWindow();
    print("===========>>========>>51");
    CreateEditorSettingsDialog();
    print("===========>>========>>52");
    CreateEditorPreferencesDialog();
    print("===========>>========>>53");
    CreateMaterialEditor();
    print("===========>>========>>54");
    CreateParticleEffectEditor();
    print("===========>>========>>5411");
    CreateSpawnEditor();
    print("===========>>========>>5422");
    CreateSoundTypeEditor();
	print("===========>>========>>6");
    CreateStatsBar();
        print("===========>>========>>61");
    CreateConsole();
        print("===========>>========>>62");
    CreateDebugHud();
        print("===========>>========>>63");
    CreateResourceBrowser();
        print("===========>>========>>64");
    CreateCamera();
    print("===========>>========>>7");
	--[[
    SubscribeToEvent("ScreenMode", "ResizeUI");
    SubscribeToEvent("MenuSelected", "HandleMenuSelected");
    SubscribeToEvent("KeyDown", "HandleKeyDown");
    SubscribeToEvent("KeyUp", "UnfadeUI");
    SubscribeToEvent("MouseButtonUp", "UnfadeUI");
    ]]
end

function ResizeUI()
    -- Resize menu bar
    uiMenuBar:SetFixedWidth(graphics.width);

    -- Resize tool bar
    toolBar:SetFixedWidth(graphics.width);

    -- Resize secondary tool bar
    secondaryToolBar:SetFixedHeight(graphics.height);

    -- Relayout stats bar
    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf");
    if (graphics.width >= 1200) then
        SetupStatsBarText(editorModeText, font, 35, 64, HA_LEFT, VA_TOP);
        SetupStatsBarText(renderStatsText, font, -4, 64, HA_RIGHT, VA_TOP);
    else
        SetupStatsBarText(editorModeText, font, 35, 64, HA_LEFT, VA_TOP);
        SetupStatsBarText(renderStatsText, font, 35, 78, HA_LEFT, VA_TOP);
	end

    -- Relayout windows
    local children = ui.root:GetChildren();
	for i = 1, #children do
        if (children[i].type == WINDOW_TYPE) then
            AdjustPosition(children[i]);
		end
	end

    -- Relayout root UI element
    editorUIElement:SetSize(graphics.width, graphics.height);
    
    -- Set new viewport area and reset the viewport layout
    viewportArea = IntRect(0, 0, graphics.width, graphics.height);
    SetViewportMode(viewportMode);
end

function AdjustPosition(window)
    local position = window.position;
    local size = window.size;
    local extend = position + size;
    if (extend.x > graphics.width) then
        position.x = Max(10, graphics.width - size.x - 10);
	end
    if (extend.y > graphics.height) then
        position.y = Max(100, graphics.height - size.y - 10);
	end
    window.position = position;
end

function CreateCursor()
    local cursor = Cursor:new()
    cursor:SetStyleAuto(uiStyle);
    cursor:SetPosition(graphics.width / 2, graphics.height / 2);
    ui.cursor = cursor;
    if (GetPlatform() == "Android" or GetPlatform() == "iOS") then
        ui.cursor.visible = false;
    end
end

menuCallbacks = {}
messageBoxCallback = nil;

function HandleQuickSearchChange(eventType, eventData)
    local search = eventData["Element"]:GetPtr();
    if (search == nil) then
        return;
    end
    PerformQuickMenuSearch(search.text);
end

function PerformQuickMenuSearch(query)
    local menu = quickMenu:GetChild("ResultsMenu", true);
    if (menu == nil) then
        return;
	end

    menu:RemoveAllChildren();
    local limit = 0;

    if (string.len(query) > 0) then
        local lastIndex = 0;
        local score = 0;
        local index = 0;

		local filtered = {};
        do
			qi = QuickMenuItem();
			for x = 1, #quickMenuItems do
                qi = quickMenuItems[x];
                local find = string.find(qi.action, query);
                if (find > -1) then
                    qi.sortScore = find;
					Push(filtered, qi);
				end
			end
		end

        Sort(filtered);

        do
			qi = QuickMenuItem();
            limit = ifor(filtered.length > MAX_QUICK_MENU_ITEMS , MAX_QUICK_MENU_ITEMS , #filtered);
			for i = 0, limit - 1 do
                qi = filtered[x];
                local item = CreateMenuItem(qi.action, qi.callback);
				item:SetMaxSize(1000,16);
				menu:AddChild(item);
			end
		end
	end

    menu.visible = limit > 0;
	menu:SetFixedHeight(limit * 16);
	quickMenu:BringToFront();
	quickMenu:SetFixedHeight(limit*16 + 62 + ifor(menu.visible , 6 , 0));
end

function CreateQuickMenu()
    if (quickMenu ~= nil) then
        return;
    end


    quickMenu = LoadEditorUI("UI/EditorQuickMenu.xml");
    quickMenu.enabled = false;
    quickMenu.visible = false;
    quickMenu.opacity = uiMaxOpacity;
    
    -- Handle a dummy search in the quick menu to finalize its initial size to empty
    PerformQuickMenuSearch("");

    ui.root:AddChild(quickMenu);
    local search = quickMenu:GetChild("Search", true);
    SubscribeToEvent(search, "TextChanged", "HandleQuickSearchChange");
    local closeButton = quickMenu:GetChild("CloseButton", true);
    SubscribeToEvent(closeButton, "Pressed", "ToggleQuickMenu");
end

function ToggleQuickMenu()
    quickMenu.enabled = (not quickMenu.enabled) and ui.cursor.visible;
    quickMenu.visible = quickMenu.enabled;
    if (quickMenu.enabled) then
        quickMenu.position = ui.cursorPosition - IntVector2(20,70);
        local search = quickMenu:GetChild("Search", true);
        search.text = "";
        search.focus = true;
    end
end


-- Create top menu bar.
function CreateMenuBar()
    uiMenuBar = BorderImage:new();
    uiMenuBar.name = 'MenuBar';
    ui.root:AddChild(uiMenuBar);

    uiMenuBar.enabled = true;
    uiMenuBar:SetStyle("EditorMenuBar");
    uiMenuBar:SetLayout(LM_HORIZONTAL);
    uiMenuBar.opacity = uiMaxOpacity;
    uiMenuBar:SetFixedWidth(graphics.width);

    -- file menu
    local menu = CreateMenu("File");
    local popup = menu.popup;
    popup:AddChild(CreateMenuItem("New scene", ResetScene, 'N', bitor2(QUAL_SHIFT, QUAL_CTRL)));
    popup:AddChild(CreateMenuItem("Open scene...", PickFile, 'O', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Save scene", SaveSceneWithExistingName, 'S', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Save scene as...", PickFile, 'S', bitor2(QUAL_SHIFT , QUAL_CTRL)));
    recentSceneMenu = CreateMenuItem("Open recent scene", nil, SHOW_POPUP_INDICATOR);
    popup:AddChild(recentSceneMenu);
    
    mruScenesPopup = CreatePopup(recentSceneMenu);
    --PopulateMruScenes();
    CreateChildDivider(popup);
    
    local childMenu = CreateMenuItem("Load node", nil, SHOW_POPUP_INDICATOR);
    local childPopup = CreatePopup(childMenu);
    childPopup:AddChild(CreateMenuItem("As replicated...", PickFile, 0, 0, true, "Load node as replicated..."));
    childPopup:AddChild(CreateMenuItem("As local...", PickFile, 0, 0, true, "Load node as local..."));
    popup:AddChild(childMenu);
    
    popup:AddChild(CreateMenuItem("Save node as...", PickFile));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Import model...", PickFile));
    popup:AddChild(CreateMenuItem("Import scene...", PickFile));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Run script...", PickFile));
    popup:AddChild(CreateMenuItem("Set resource path...", PickFile));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Exit", Exit));
    FinalizedPopupMenu(popup);
    uiMenuBar:AddChild(menu);
    local menu = CreateMenu("Edit");
    local popup = menu.popup;
    popup:AddChild(CreateMenuItem("Undo", Undo, 'Z', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Redo", Redo, 'Y', QUAL_CTRL));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Cut", Cut, 'X', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Duplicate", Duplicate, 'D', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Copy", Copy, 'C', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Paste", Paste, 'V', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Delete", Delete, KEY_DELETE, QUAL_ANY));
    popup:AddChild(CreateMenuItem("Select all", SelectAll, 'A', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Deselect all", DeselectAll, 'A', bit.bxor(QUAL_SHIFT , QUAL_CTRL)));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Reset to default", ResetToDefault));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Reset position", SceneResetPosition));
    popup:AddChild(CreateMenuItem("Reset rotation", SceneResetRotation));
    popup:AddChild(CreateMenuItem("Reset scale", SceneResetScale));
    popup:AddChild(CreateMenuItem("Enable/disable", SceneToggleEnable, 'E', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Unparent", SceneUnparent, 'U', QUAL_CTRL));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Toggle update", ToggleSceneUpdate, 'P', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Stop test animation", StopTestAnimation));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Rebuild navigation data", SceneRebuildNavigation));
    popup:AddChild(CreateMenuItem("Add children to SM-group", SceneAddChildrenStaticModelGroup));
    FinalizedPopupMenu(popup);
    uiMenuBar:AddChild(menu);
    

    local menu = CreateMenu("Create");
    local popup = menu.popup;
    popup:AddChild(CreateMenuItem("Replicated node", PickNode, 0, 0, true, "Create Replicated node"));
    popup:AddChild(CreateMenuItem("Local node", PickNode, 0, 0, true, "Create Local node"));
    CreateChildDivider(popup);

    local childMenu = CreateMenuItem("Component", nil, SHOW_POPUP_INDICATOR);
    local childPopup = CreatePopup(childMenu);
    local objectCategories = GetObjectCategories();
    for i, v in ipairs(objectCategories) do
        if (v ~= 'UI') then
            local menuui = CreateMenuItem(v, nil, SHOW_POPUP_INDICATOR);
            local subpopup = CreatePopup(menuui);
            local componentTypes = GetObjectsByCategory(v);
            for j, vl in ipairs(componentTypes) do
                subpopup:AddChild(CreateIconizedMenuItem(v, PickComponent, 0, 0, "", true, "Create " .. v));
            end
            childPopup:AddChild(menuui);
        end
    end

    FinalizedPopupMenu(childPopup);
    popup:AddChild(childMenu);
	
    childMenu = CreateMenuItem("Builtin object", nil, SHOW_POPUP_INDICATOR);
	childPopup = CreatePopup(childMenu);
    local objects = { "Box", "Cone", "Cylinder", "Plane", "Pyramid", "Sphere", "TeaPot", "Torus" };
    for i, v in ipairs(objects) do
        childPopup:AddChild(CreateIconizedMenuItem(v, PickBuiltinObject, 0, 0, "Node", true, "Create " .. v));
    end

    popup:AddChild(childMenu);
    CreateChildDivider(popup);

    childMenu = CreateMenuItem("UI-element", nil, SHOW_POPUP_INDICATOR);
    childPopup = CreatePopup(childMenu);
    local uiElementTypes = GetObjectsByCategory("UI");
    for i, v in ipairs(uiElementTypes) do
        if (v ~= 'UIElement') then
            childPopup:AddChild(CreateIconizedMenuItem(v, PickUIElement, 0, 0, "", true, "Create " .. v));
        end
    end

    CreateChildDivider(childPopup);
    childPopup:AddChild(CreateIconizedMenuItem("UIElement", PickUIElement));
    popup:AddChild(childMenu);
    FinalizedPopupMenu(popup);
    uiMenuBar:AddChild(menu);
    
    
    local menu = CreateMenu("UI-layout");
    local popup = menu.popup;
    popup:AddChild(CreateMenuItem("Open UI-layout...", PickFile, 'O', QUAL_ALT));
    popup:AddChild(CreateMenuItem("Save UI-layout", SaveUILayoutWithExistingName, 'S', QUAL_ALT));
    popup:AddChild(CreateMenuItem("Save UI-layout as...", PickFile));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Close UI-layout", CloseUILayout, 'C', QUAL_ALT));
    popup:AddChild(CreateMenuItem("Close all UI-layouts", CloseAllUILayouts));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Load child element...", PickFile));
    popup:AddChild(CreateMenuItem("Save child element as...", PickFile));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Set default style...", PickFile));
    FinalizedPopupMenu(popup);
    uiMenuBar:AddChild(menu);

    local menu = CreateMenu("View");
    local popup = menu.popup;
    popup:AddChild(CreateMenuItem("Hierarchy", ShowHierarchyWindow, 'H', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Attribute inspector", ShowAttributeInspectorWindow, 'I', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Resource browser", ShowResourceBrowserWindow, 'B', QUAL_CTRL));
    popup:AddChild(CreateMenuItem("Material editor", ShowMaterialEditor));
    popup:AddChild(CreateMenuItem("Particle editor", ShowParticleEffectEditor));
    popup:AddChild(CreateMenuItem("Spawn editor", ShowSpawnEditor));
    popup:AddChild(CreateMenuItem("Sound Type editor", ShowSoundTypeEditor));
    popup:AddChild(CreateMenuItem("Editor settings", ShowEditorSettingsDialog));
    popup:AddChild(CreateMenuItem("Editor preferences", ShowEditorPreferencesDialog));
    CreateChildDivider(popup);
    popup:AddChild(CreateMenuItem("Hide editor", ToggleUI, KEY_F12, QUAL_ANY));
    FinalizedPopupMenu(popup);
    uiMenuBar:AddChild(menu);

    local spacer = BorderImage:new();
    spacer.name = 'MenuBarSpacer'
    uiMenuBar:AddChild(spacer);
    spacer.style = "EditorMenuBar";

    local logo = BorderImage:new();
    logo.name = "Logo";
    logo.texture = cache:GetResource("Texture2D", "Textures/Logo.png");
    logo:SetFixedWidth(64);
    uiMenuBar:AddChild(logo);
end

function Exit()
    ui.cursor.shape = CS_BUSY;

    if (messageBoxCallback == nil) then
        local message;
        if (sceneModified) then
            message = "Scene has been modified.\n";
		end

        local uiLayoutModified = false;
		for i = 0, editorUIElement.numChildren-1 do
            local element = editorUIElement.children[i];
            if (element ~= nil and element:GetVars():GetBool(MODIFIED_VAR)) then
                uiLayoutModified = true;
                message = message .. "UI layout has been modified.\n";
                break;
			end
		end

        if (sceneModified or uiLayoutModified) then
            local messageBox = MessageBox(message .. "Continue to exit?", "Warning");
            if (messageBox.window ~= nil) then
                local cancelButton = messageBox.window:GetChild("CancelButton", true);
                cancelButton.visible = true;
                cancelButton.focus = true;
                SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement");
                messageBoxCallback = Exit;
                return false;
			end
		end
    else
        messageBoxCallback = nil;
	end

	engine:Exit();
    return true;
end

function  HandleExitRequested()
    if (not ui:HasModalElement()) then
		Exit();
    end
    Exit();
end

function PickFile()
    local menu = GetEventSender();
    if (menu ~= nil) then
        return false;
	end

    local action = menu.name;
    if (empty(action)) then
        return false;
	end

    -- File (Scene related)
    if (action == "Open scene...") then
        CreateFileSelector("Open scene", "Open", "Cancel", uiScenePath, uiSceneFilters, uiSceneFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleOpenSceneFile");
    elseif (action == "Save scene as..." or action == "Save scene") then
        CreateFileSelector("Save scene as", "Save", "Cancel", uiScenePath, uiSceneFilters, uiSceneFilter);
        uiFileSelector.fileName = GetFileNameAndExtension(editorScene.fileName);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleSaveSceneFile");
    elseif (action == "As replicated..." or action == "Load node as replicated...") then
        instantiateMode = REPLICATED;
        CreateFileSelector("Load node", "Load", "Cancel", uiNodePath, uiSceneFilters, uiNodeFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleLoadNodeFile");
    elseif (action == "As local..." or action == "Load node as local...") then
        instantiateMode = LOCAL;
        CreateFileSelector("Load node", "Load", "Cancel", uiNodePath, uiSceneFilters, uiNodeFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleLoadNodeFile");
    elseif (action == "Save node as...") then
        if (editNode ~= nil and editNode ~= editorScene) then
            CreateFileSelector("Save node", "Save", "Cancel", uiNodePath, uiSceneFilters, uiNodeFilter);
            uiFileSelector.fileName = GetFileNameAndExtension(instantiateFileName);
            SubscribeToEvent(uiFileSelector, "FileSelected", "HandleSaveNodeFile");
		end
    elseif (action == "Import model...") then
        CreateFileSelector("Import model", "Import", "Cancel", uiImportPath, uiAllFilters, uiImportFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleImportModel");
    elseif (action == "Import scene...") then
        CreateFileSelector("Import scene", "Import", "Cancel", uiImportPath, uiAllFilters, uiImportFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleImportScene");
    
    elseif (action == "Run script...") then
        CreateFileSelector("Run script", "Run", "Cancel", uiScriptPath, uiScriptFilters, uiScriptFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleRunScript");
    elseif (action == "Set resource path...") then
        CreateFileSelector("Set resource path", "Set", "Cancel", sceneResourcePath, uiAllFilters, 0);
        uiFileSelector.directoryMode = true;
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleResourcePath");
    -- UI-element
    elseif (action == "Open UI-layout...") then
        CreateFileSelector("Open UI-layout", "Open", "Cancel", uiElementPath, uiElementFilters, uiElementFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleOpenUILayoutFile");
    elseif (action == "Save UI-layout as..." and action == "Save UI-layout") then
        if (editUIElement ~= nil) then
            local element = GetTopLevelUIElement(editUIElement);
            if (element == nil) then
                return false;
			end

            CreateFileSelector("Save UI-layout as", "Save", "Cancel", uiElementPath, uiElementFilters, uiElementFilter);
            uiFileSelector.fileName = GetFileNameAndExtension(element.GetVar(FILENAME_VAR).GetString());
            SubscribeToEvent(uiFileSelector, "FileSelected", "HandleSaveUILayoutFile");
		end
    elseif (action == "Load child element...") then
        if (editUIElement ~= nil) then
            CreateFileSelector("Load child element", "Load", "Cancel", uiElementPath, uiElementFilters, uiElementFilter);
            SubscribeToEvent(uiFileSelector, "FileSelected", "HandleLoadChildUIElementFile");
		end
    elseif (action == "Save child element as...") then
        if (editUIElement ~= nil) then
            CreateFileSelector("Save child element", "Save", "Cancel", uiElementPath, uiElementFilters, uiElementFilter);
            uiFileSelector.fileName = GetFileNameAndExtension(editUIElement.GetVar(CHILD_ELEMENT_FILENAME_VAR).GetString());
            SubscribeToEvent(uiFileSelector, "FileSelected", "HandleSaveChildUIElementFile");
		end
    elseif (action == "Set default style...") then
        CreateFileSelector("Set default style", "Set", "Cancel", uiElementPath, uiElementFilters, uiElementFilter);
        SubscribeToEvent(uiFileSelector, "FileSelected", "HandleUIElementDefaultStyle");
	end

    return true;
end

--===================================================
-- common function
--===================================================









function QuickMenuItem(action, callback)
    local t = {action = action, callback = callback, sortScore = 0}
    t.opCmp = function(b)  return t.sortScore - b.sortScore; end
    return t;
end


function PickBuiltinObject()
    -- TODO
    return true;
end

function PopulateMruScenes()
    mruScenesPopup:RemoveAllChildren();
    local num = #uiRecentScenes;
    if (num > 0) then
        recentSceneMenu.enabled = true;
        for i, v in ipairs(uiRecentScenes) do
            mruScenesPopup:AddChild(CreateMenuItem(uiRecentScenes[i], LoadMostRecentScene, 0, 0, false));
        end
    else
        recentSceneMenu.enabled = false;
    end
end

function IconizeUIElement(element, iconType)
    
    local icon = element:GetChild("Icon");
    if (iconType == nil) then
        if (icon) then
            icon:Remove();
        end
        
        if (element:GetVar(INDENT_MODIFIED_BY_ICON_VAR):GetBool()) then
            element.indent = 0;
        end

        return;
    end

    if (element.indent == 0) then
        element.indent = 1;
        element:SetVar(INDENT_MODIFIED_BY_ICON_VAR, Variant(true));
    end

    if (icon == nil) then
        icon = BorderImage:new();
        icon.name = "Icon";
        icon.indent = element.indent - 1;
        icon:SetFixedSize(element.indentWidth - 2, 14);
        element:InsertChild(0, icon); 
    end

    if (not icon:SetStyle(iconType, iconStyle)) then
        icon:SetStyle("Unknown", iconStyle); 
    end
    icon.color = Color(1,1,1,1);
end


function ToggleUI()
    HideUI(not uiHidden);
    return true;
end

function LoadMostRecentScene()
    local menu = GetEventSender();
    if (menu == nil) then
        return false;
    end
    local text = menu:GetChildren()[0];
    if (text == nil) then
        return false;
    end
    return LoadScene(text.text);
end


function PickNode()
    local  menu = GetEventSender();
    if (menu == nil) then
        return false;
	end

    local action = GetActionName(menu.name);
    if (empty(action)) then
        return false;
	end

    CreateNode(ifor(action == "Replicated node" , REPLICATED , LOCAL));
    return true;
end

function PickComponent()
    if (#editNodes == 0) then
        return false;
	end

    local menu = GetEventSender();
    if (menu == nil) then
        return false;
	end

    local action = GetActionName(menu.name);
    if (empty(action)) then
        return false;
	end

    CreateComponent(action);
    return true;
end

function PickBuiltinObject()
    local menu = GetEventSender();
    if (menu == nil) then
        return false;
	end

    local action = GetActionName(menu.name);
    if (empty(action)) then
        return false;
	end

    CreateBuiltinObject(action);
    return true;
end

function PickUIElement()
    local menu = GetEventSender();
    if (menu == nil) then
        return false;
	end

    local action = GetActionName(menu.name);
    if (empty(action)) then
        return false;
	end

    return NewUIElement(action);
end

-- When calling items from the quick menu, they have "Create" prepended for clarity. Strip that now to get the object name to create
function GetActionName(name)
    if (StartsWith(name,"Create")) then
        return Substring(name, 7);
    else
        return name;
	end
end

function HandleMenuSelected(eventType, eventData)
    local menu = eventData["Element"]:GetPtr();
    if (menu == nil) then
        return;
	end

    HandlePopup(menu);

    quickMenu.visible = false;
    quickMenu.enabled = false;

    -- Execute the callback if available
    local variant = menu.GetVar(CALLBACK_VAR);
    if (not variant.empty) then
        menuCallbacks[variant:GetUInt()]();
	end
end

function CreateMenuItem(title, callback, accelKey, accelQual, addToQuickMenu, quickMenuText)
    if (accelKey == nil) then accelKey = 0; end
    if (accelQual == nil) then accelQual = 0; end
    if (addToQuickMenu == nil) then addToQuickMenu = true; end
    if (quickMenuText == nil) then quickMenuText = ''; end

    if (type(accelKey) == 'string') then accelKey = string.byte(accelKey) end
    if (type(accelQual) == 'string') then accelQual = string.byte(accelQual) end

    local menu = Menu:new();
    menu.name = title
    menu.defaultStyle = uiStyle;
    menu.style = AUTO_STYLE;
    menu:SetLayout(LM_HORIZONTAL, 0, IntRect(8, 2, 8, 2));
    if (accelKey > 0) then
        menu:SetAccelerator(accelKey, accelQual);
    end

    if (callback ~= nil) then
        menu:SetVar(CALLBACK_VAR, Variant(#menuCallbacks + 1));
        table.insert(menuCallbacks, callback);
    end

    local menuText = Text:new();
    menu:AddChild(menuText);
    menuText.style = "EditorMenuText";
    menuText.text = title;

    if (addToQuickMenu) then
    	local dt = quickMenuText;
    	if (quickMenuText.empty) then dt = title; end
        AddQuickMenuItem(callback, dt);
    end

    if (accelKey ~= 0) then
        local spacer = UIElement:new();
        spacer.minWidth = menuText.indentSpacing;
        spacer.height = menuText.height;
        menu:AddChild(spacer);
        menu:AddChild(CreateAccelKeyText(accelKey, accelQual));
    end

    return menu;
end

function AddQuickMenuItem(callback, text)
	if (callback == nil) then
		return;
	end
    local exists = false;
    for i, v in ipairs(quickMenuItems) do
    	if (v.action == text) then
    		exists = true;
    		break;
    	end
    end
    if (not exists) then
        table.insert(quickMenuItems, QuickMenuItem(text, callback))
    end
end

function CreateIconizedMenuItem(title, callback, accelKey, accelQual, iconType, addToQuickMenu, quickMenuText)
    if (accelKey == nil) then accelKey = 0; end
    if (accelQual == nil) then accelQual = 0; end
    if (iconType == nil) then iconType = ""; end
    if (addToQuickMenu == nil) then addToQuickMenu = true; end
    if (quickMenuText == nil) then quickMenuText = ""; end


    local menu = Menu:new()
    menu.name = title;
    menu.defaultStyle = uiStyle;
    menu.style = AUTO_STYLE;
    menu:SetLayout(LM_VERTICAL, 0, IntRect(8, 2, 8, 2));
    if (accelKey > 0) then
        menu:SetAccelerator(accelKey, accelQual);
    end

    if (callback ~= nil) then
        menu:SetVar(CALLBACK_VAR, Variant(#menuCallbacks + 1));
        table.insert(menuCallbacks, callback);
    end

    local menuText = Text:new();
    menu:AddChild(menuText);

    menuText.style = "EditorMenuText";
    menuText.text = title;

    local istring = iconType;
    if (iconType == nil) then istring = title; end

    IconizeUIElement(menuText, istring);

    if (addToQuickMenu) then
        local sstr = quickMenuText;
        if (quickMenuText == nil) then sstr = title; end
        AddQuickMenuItem(callback, sstr);
    end
    if (accelKey ~= 0) then
        menuText.layoutMode = LM_HORIZONTAL;
        menuText:AddChild(CreateAccelKeyText(accelKey, accelQual));
    end

    return menu;
end


function CreateChildDivider(parent)
    local divider = parent:CreateChild("BorderImage", "Divider");
    divider.style = "EditorDivider";
end

function CreatePopup(baseMenu)
    local popup = Window:new();
    popup.defaultStyle = uiStyle;
    popup.style = AUTO_STYLE;
    popup:SetLayout(LM_VERTICAL, 1, IntRect(2, 6, 2, 6));
    baseMenu.popup = popup;
    baseMenu.popupOffset = IntVector2(0, baseMenu.height);

    return popup;
end

function CreateMenu(title)

    local menu = CreateMenuItem(title);
    menu:SetFixedWidth(menu.width);
    CreatePopup(menu);

    return menu;
end

function CreateAccelKeyText(accelKey, accelQual)
    local accelKeyText = Text:new();
    accelKeyText.defaultStyle = uiStyle;
    accelKeyText.style = "EditorMenuText";
    accelKeyText.textAlignment = HA_RIGHT;

    local text = '';
    if (accelKey == KEY_DELETE) then
        text = "Del";
    elseif (accelKey == KEY_SPACE) then
        text = "Space";
    -- Cannot use range as the key constants below do not appear to be in sequence
    elseif (accelKey == KEY_F1) then
        text = "F1";
    elseif (accelKey == KEY_F2) then
        text = "F2";
    elseif (accelKey == KEY_F3) then
        text = "F3";
    elseif (accelKey == KEY_F4) then
        text = "F4";
    elseif (accelKey == KEY_F5) then
        text = "F5";
    elseif (accelKey == KEY_F6) then
        text = "F6";
    elseif (accelKey == KEY_F7) then
        text = "F7";
    elseif (accelKey == KEY_F8) then
        text = "F8";
    elseif (accelKey == KEY_F9) then
        text = "F9";
    elseif (accelKey == KEY_F10) then
        text = "F10";
    elseif (accelKey == KEY_F11) then
        text = "F11";
    elseif (accelKey == KEY_F12) then
        text = "F12";
    elseif (accelKey == SHOW_POPUP_INDICATOR) then
        text = ">";
    else
        text = text .. ' ' .. string.char(accelKey);
    end
    if (bit.band(accelQual, QUAL_ALT) > 0)  then
        text = "Alt+" .. text;
	end
    if (bit.band(accelQual, QUAL_SHIFT) > 0)  then
        text = "Shift+" .. text;
	end
    if (bit.band(accelQual, QUAL_CTRL) > 0)  then
        text = "Ctrl+" .. text;
    end
    accelKeyText.text = text;

    return accelKeyText;
end

function FinalizedPopupMenu(popup)
    local num = popup:GetNumChildren() - 1;
    local maxWidth = 0;
    for i = 0, num do
        local element = popup:GetChild(i);
        if (element.type == MENU_TYPE) then    -- Skip if not menu item
            local width = element:GetChild(0).width;
            if (width > maxWidth) then
                maxWidth = width;
            end
        end
    end

    maxWidth = maxWidth + 20;
    for i = 0, num do
        local element = popup:GetChild(i);
        if (element.type == MENU_TYPE) then
            local menu = tolua.cast(element, "Menu");

            local menuText = menu:GetChild(0);
            if (menuText:GetNumChildren() == 1) then   -- Skip if menu text does not have accel
                menuText:GetChild(0).indentSpacing = maxWidth;
			end
            if (menu.popup) then
                menu:SetPopupOffset(IntVector2(menu.width, 0));
            end
        end
    end
end

function CreateFileSelector(title, ok, cancel, initialPath, filters, initialFilter) 
    -- Within the editor UI, the file selector is a kind of a "singleton". When the previous one is overwritten, also
    -- the events subscribed from it are disconnected, so new ones are safe to subscribe.
    uiFileSelector = FileSelector();
    uiFileSelector.defaultStyle = uiStyle;
    uiFileSelector.title = title;
    uiFileSelector.path = initialPath;
	uiFileSelector:SetButtonTexts(ok, cancel);
	uiFileSelector:SetFilters(filters, initialFilter);
    CenterDialog(uiFileSelector.window);
end


function CloseFileSelector(filterIndex, path)
    -- Save filter & path for next time
	if (filterIndex ~= nil) then
		filterIndex = uiFileSelector.filterIndex;
	end
	if (path ~= nil) then
		path = uiFileSelector.path;
	end

    uiFileSelector = nil;
end

function CreateConsole()
    local console = engine:CreateConsole();
    console.defaultStyle = uiStyle;
    console.commandInterpreter = consoleCommandInterpreter;
    console.numBufferedRows = 100;
    console.autoVisibleOnError = true;
end

function CreateDebugHud()
    engine:CreateDebugHud();
    debugHud.defaultStyle = uiStyle;
    debugHud.mode = DEBUGHUD_SHOW_NONE;
end

function CenterDialog(element)
    local size = element.size;
	element:SetPosition((graphics.width - size.x) / 2, (graphics.height - size.y) / 2);
end

function CreateContextMenu()
    contextMenu = LoadEditorUI("UI/EditorContextMenu.xml");
    ui.root:AddChild(contextMenu);
end

function UpdateWindowTitle()

    local sceneName = GetFileNameAndExtension(editorScene.fileName);
    if (sceneName.empty or sceneName == TEMP_SCENE_NAME) then
        sceneName = "Untitled";
    end
    if (sceneModified) then
        sceneName = sceneName .. "*";
    end
    graphics.windowTitle = "Urho3D editor - " .. sceneName;
end


function HandlePopup(menu)
    -- Close the top level menu now unless the selected menu item has another popup
    if (menu.popup ~= nil) then
        return;
	end

	while(true) do
        local menuParent = menu.parent;
        if (menuParent == nil) then
            break;
		end

        local nextMenu = menuParent:GetVars():GetPtr("Origin");
        if (nextMenu == nil) then
            break;
        else
            menu = nextMenu;
		end
	end

    if (menu.parent == uiMenuBar) then
        menu.showPopup = false;
	end
end

function ExtractFileName(eventData, forSave)
	if (forSave == nil) then
		forSave = false;
	end

    local fileName;

    -- Check for OK
    if (eventData["OK"]:GetBool()) then
        local filter = eventData["Filter"]:GetString();
        fileName = eventData["FileName"]:GetString();
        -- Add default extension for saving if not specified
        if (empty(GetExtension(fileName)) and forSave and filter ~= "*.*") then
            fileName = fileName .. Substring(filter, 1);
		end
	end
    return fileName;
end

function HandleOpenSceneFile(eventType, eventData)
    CloseFileSelector(uiSceneFilter, uiScenePath);
    LoadScene(ExtractFileName(eventData));
end

function HandleSaveSceneFile(eventType, eventData)
    CloseFileSelector(uiSceneFilter, uiScenePath);
    SaveScene(ExtractFileName(eventData, true));
end

function HandleLoadNodeFile(eventType, eventData)
    CloseFileSelector(uiNodeFilter, uiNodePath);
    LoadNode(ExtractFileName(eventData));
end

function HandleSaveNodeFile(eventType, eventData)
    CloseFileSelector(uiNodeFilter, uiNodePath);
    SaveNode(ExtractFileName(eventData, true));
end

function HandleImportModel(eventType, eventData)
    CloseFileSelector(uiImportFilter, uiImportPath);
    ImportModel(ExtractFileName(eventData));
end

function HandleImportScene(eventType, eventData)
    CloseFileSelector(uiImportFilter, uiImportPath);
    ImportScene(ExtractFileName(eventData));
end

function ExecuteScript(fileName)
    if (empty(fileName)) then
        return;
	end

    local file = File:new(fileName, FILE_READ);
    if (file.open) then
        local scriptCode;
        while (not file.eof) do
            scriptCode = scriptCode .. file:ReadLine() .. "\n";
		end
        file:Close();

        if (script:Execute(scriptCode)) then
            log.Info("Script " .. fileName .. " ran successfully");
		end
	end
end

function HandleRunScript(eventType, eventData)
    CloseFileSelector(uiScriptFilter, uiScriptPath);
    ExecuteScript(ExtractFileName(eventData));
end

function HandleResourcePath(eventType, eventData)
    local pathName = uiFileSelector.path;
    CloseFileSelector();
    if (eventData["OK"]:GetBool()) then
        SetResourcePath(pathName, false);
	end
end

function HandleOpenUILayoutFile(eventType, eventData)
    CloseFileSelector(uiElementFilter, uiElementPath);
    OpenUILayout(ExtractFileName(eventData));
end

function HandleSaveUILayoutFile(eventType, eventData)
    CloseFileSelector(uiElementFilter, uiElementPath);
    SaveUILayout(ExtractFileName(eventData, true));
end

function HandleLoadChildUIElementFile(eventType, eventData)
    CloseFileSelector(uiElementFilter, uiElementPath);
    LoadChildUIElement(ExtractFileName(eventData));
end

function HandleSaveChildUIElementFile(eventType, eventData)
    CloseFileSelector(uiElementFilter, uiElementPath);
    SaveChildUIElement(ExtractFileName(eventData, true));
end

function HandleUIElementDefaultStyle(eventType, eventData)
    CloseFileSelector(uiElementFilter, uiElementPath);
    SetUIElementDefaultStyle(ExtractFileName(eventData));
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt();
    local viewDirection = ifor(eventData["Qualifiers"]:GetInt() == QUAL_CTRL , -1 , 1);

    if (key == KEY_ESC) then
        if (uiHidden) then
            UnhideUI();
        elseif (console.visible) then
            console.visible = false;
        elseif (contextMenu.visible) then
            CloseContextMenu();
        elseif (quickMenu.visible) then
            quickMenu.visible = false;
            quickMenu.enabled = false;
        else
            local front = ui.frontElement;
            if (front == settingsDialog or front == preferencesDialog) then
                ui.focusElement = nil;
                front.visible = false;
			end
		end
    -- Ignore other keys when UI has a modal element
    elseif (ui.HasModalElement()) then
        return;
    elseif (key == KEY_F1) then
        console.Toggle();
    elseif (key == KEY_F2) then
        ToggleRenderingDebug();
    elseif (key == KEY_F3) then
        TogglePhysicsDebug();
    elseif (key == KEY_F4) then
        ToggleOctreeDebug();
    elseif (key == KEY_F11) then
        local screenshot = Image:new();
		graphics:TakeScreenShot(screenshot);
        if (not fileSystem:DirExists(screenshotDir)) then
            fileSystem.CreateDir(screenshotDir);
		end
        screenshot:SavePNG(screenshotDir .. "/Screenshot_" .. 
                Replaced(Replaced(Replaced(time.timeStamp, ':', '_'), '.', '_'), ' ', '_') + ".png");
    elseif (key == KEY_KP_1 and ui.focusElement == nil) then -- Front view
        local center = Vector3(0,0,0);
        if (selectedNodes > 0 or selectedComponents > 0) then
            center = SelectedNodesCenterPoint();
		end
            
        local pos = cameraNode.worldPosition - center;
        cameraNode.worldPosition = center - Vector3(0.0, 0.0, pos.length * viewDirection);
        cameraNode.direction = Vector3(0, 0, viewDirection);
        ReacquireCameraYawPitch();
    elseif (key == KEY_KP_3 and ui.focusElement == nil) then -- Side view
        local center = Vector3(0,0,0);
        if (#selectedNodes > 0 and #selectedComponents > 0) then
            center = SelectedNodesCenterPoint();
		end
            
        local pos = cameraNode.worldPosition - center;
        cameraNode.worldPosition = center - Vector3(pos.length * -viewDirection, 0.0, 0.0);
        cameraNode.direction = Vector3(-viewDirection, 0, 0);
        ReacquireCameraYawPitch();
    elseif (key == KEY_KP_7 and ui.focusElement == nil) then -- Top view
        local center = Vector3(0,0,0);
        if (#selectedNodes > 0 and #selectedComponents > 0) then
            center = SelectedNodesCenterPoint();
		end
            
        local pos = cameraNode.worldPosition - center;
        cameraNode.worldPosition = center - Vector3(0.0, pos.length * -viewDirection, 0.0);
        cameraNode.direction = Vector3(0, -viewDirection, 0);
        ReacquireCameraYawPitch();
    elseif (key == KEY_KP_5 and ui.focusElement == nil) then
        activeViewport.ToggleOrthographic();
    elseif (eventData["Qualifiers"]:GetInt() == QUAL_CTRL) then
        if (key == '1') then
            editMode = EDIT_MOVE;
        elseif (key == '2') then
            editMode = EDIT_ROTATE;
        elseif (key == '3') then
            editMode = EDIT_SCALE;
        elseif (key == '4') then
            editMode = EDIT_SELECT;
        elseif (key == '5') then
            axisMode = AxisMode(bitxor2(axisMode ^ AXIS_LOCAL));
        elseif (key == '6') then
            --pickMode;
            if (pickMode < PICK_GEOMETRIES) then
                pickMode = MAX_PICK_MODES - 1;
			end
        elseif (key == '7') then
            pickMode = pickMode + 1;
            if (pickMode >= MAX_PICK_MODES) then
                pickMode = PICK_GEOMETRIES;
			end
        elseif (key == 'W') then
            fillMode = FillMode(fillMode + 1);
            if (fillMode > FILL_POINT) then
                fillMode = FILL_SOLID;
			end

            -- Update camera fill mode
            SetFillMode(fillMode);
        elseif (key == KEY_SPACE) then
            if (ui.cursor.visible) then
                ToggleQuickMenu();
			end
        else
            SteppedObjectManipulation(key);
		end
        toolBarDirty = true;
	end
end

function UnfadeUI()
    FadeUI(false);
end

function FadeUI(fade)
	if (fade == nil) then
		fade = true;
	end
    if (uiHidden or uiFaded == fade) then
        return;
	end

    local opacity = ifor((uiFaded == fade) , uiMinOpacity , uiMaxOpacity);
    local children = ui.root:GetChildren();
	for i = 1, #children do
        -- Texts, popup&modal windows (which are anyway only in ui.modalRoot), and editorUIElement are excluded
        if (children[i].type ~= TEXT_TYPE and children[i] ~= editorUIElement) then
            children[i].opacity = opacity;
		end
	end
end

function ToggleUI()
    HideUI(not uiHidden);
    return true;
end

function UnhideUI()
    HideUI(false);
end

function HideUI(hide)
	if (hide == nil) then
		hide = true;
	end
    if (uiHidden == hide) then
        return;
	end

    local visible = not (uiHidden == hide);
    local children = ui.root:GetChildren();
	for i = 1, #children do
        -- Cursor and editorUIElement are excluded
        if (children[i].type ~= CURSOR_TYPE and children[i] ~= editorUIElement) then
            if (visible) then
                if (not children[i].visible) then
                    children[i].visible = children[i]:GetVar("HideUI"):GetBool();
				end
            else
                children[i]:SetVar("HideUI", Variant(children[i].visible));
                children[i].visible = false;
			end
		end
	end
end

function IconizeUIElement(element, iconType)
    -- Check if the icon has been created before
    local icon = element:GetChild("Icon");

    -- If iconType is empty, it is a request to remove the existing icon
    if (empty(iconType)) then
        -- Remove the icon if it exists
        if (icon ~= nil) then
            icon:Remove();
		end

        -- Revert back the indent but only if it is indented by this function
        if (element:GetVar(INDENT_MODIFIED_BY_ICON_VAR):GetBool()) then
            element.indent = 0;
		end

        return;
	end

    -- The UI element must itself has been indented to reserve the space for the icon
    if (element.indent == 0) then
        element.indent = 1;
		element:SetVar(INDENT_MODIFIED_BY_ICON_VAR, Variant(true));
	end

     -- If no icon yet then create one with the correct indent and size in respect to the UI element
    if (icon == nil) then
        -- The icon is placed at one indent level less than the UI element
        icon = BorderImage:new("Icon");
        icon.indent = element.indent - 1;
		icon:SetFixedSize(element.indentWidth - 2, 14);
		element:InsertChild(0, icon);   -- Ensure icon is added as the first child
	end

    -- Set the icon type
    if (not icon:SetStyle(iconType, iconStyle)) then
        icon:SetStyle("Unknown", iconStyle);    -- If fails then use an 'unknown' icon type
	end

    icon.color = Color(1,1,1,1); -- Reset to enabled color
end

function SetIconEnabledColor(element, enabled, partial)
	if (partial == nil) then
		partial = false;
	end

    local icon = element:GetChild("Icon");
    if (icon ~= nil) then
        if (partial) then
            icon.colors[C_TOPLEFT] = Color(1,1,1,1);
            icon.colors[C_BOTTOMLEFT] = Color(1,1,1,1);
            icon.colors[C_TOPRIGHT] = Color(1,0,0,1);
            icon.colors[C_BOTTOMRIGHT] = Color(1,0,0,1);
        else
            icon.color = ifor(enabled, Color(1,1,1,1), Color(1,0,0,1));
		end
	end
end

function UpdateDirtyUI()
    UpdateDirtyToolBar();

    -- Perform hierarchy selection latently after the new selections are finalized (used in undo/redo action)
    if (not #hierarchyUpdateSelections == 0) then
        hierarchyList:SetSelections(hierarchyUpdateSelections);
		hierarchyUpdateSelections:Clear();
	end
    

    -- Perform some event-triggered updates latently in case a large hierarchy was changed
    if (attributesFullDirty or attributesDirty) then
        UpdateAttributeInspector(attributesFullDirty);
	end
end

function HandleMessageAcknowledgement(eventType, eventData)
    if (eventData["OK"]:GetBool()) then
        messageBoxCallback();
    else
        messageBoxCallback = nil;
	end
end

function PopulateMruScenes()
    mruScenesPopup:RemoveAllChildren();
    if (#uiRecentScenes > 0) then
        recentSceneMenu.enabled = true;
		for i = 1, #uiRecentScenes do
            mruScenesPopup:AddChild(CreateMenuItem(uiRecentScenes[i], LoadMostRecentScene, 0, 0, false));
		end
    else
        recentSceneMenu.enabled = false;
	end
end

function LoadMostRecentScene()
    local menu = GetEventSender();
    if (menu  == nil) then
        return false;
	end

    local text = menu:GetChildren()[0];
    if (text  == nil) then
        return false;
	end

    return LoadScene(text.text);
end

-- Set from click to false if opening menu procedurally.
function OpenContextMenu(fromClick)
	if (fromClick == nil) then
		fromClick = true;
	end
    if (contextMenu ~= nil) then
        return;
	end

    contextMenu.enabled = true;
    contextMenu.visible = true;
	contextMenu:BringToFront();
    if (fromClick) then
        contextMenuActionWaitFrame=true;
	end
end

function CloseContextMenu()
    if (contextMenu == nil) then
        return;
	end

    contextMenu.enabled = false;
    contextMenu.visible = false;
end

function ActivateContextMenu(actions)
    contextMenu:RemoveAllChildren();
	for i = 1, #actions do
        contextMenu:AddChild(actions[i]);
	end
    contextMenu:SetFixedHeight(24*actions.length+6);
    contextMenu.position = ui.cursor.screenPosition + IntVector2(10,-10);
    OpenContextMenu();
end

function CreateContextMenuItem(text, handler)
    local menu = Menu:new();
    menu.defaultStyle = uiStyle;
    menu.style = AUTO_STYLE;
	menu:SetLayout(LM_HORIZONTAL, 0, IntRect(8, 2, 8, 2));
    local menuText = Text:new();
    menuText.style = "EditorMenuText";
	menu:AddChild(menuText);
    menuText.text = text;
	menu:GetVars():SetString(VAR_CONTEXT_MENU_HANDLER, handler);
    SubscribeToEvent(menu, "Released", "ContextMenuEventWrapper");
    return menu;
end

function ContextMenuEventWrapper(eventType, eventData)
    local uiElement = eventData["Element"]:GetPtr();
    if (uiElement == nil) then
        return;
	end

    local handler = uiElement:GetVars():GetString(VAR_CONTEXT_MENU_HANDLER);
    if (empty(handler)) then
        SubscribeToEvent(uiElement, "Released", handler);
		uiElement:SendEvent("Released", eventData);
	end
    CloseContextMenu();
end

function GetEditorUIXMLFile(fileName)

    local fullFileName = fileSystem:GetCurrentDir() .. "Data/" .. fileName;
    if (fileSystem:FileExists(fullFileName)) then
        local xml = XMLFile:new(); -- be carefull memory
        if (xml:Load(fullFileName)) then
            return xml;
        end
    end

    return cache:GetResource("XMLFile", fileName);
end

--- Load an UI layout used by the editor
function LoadEditorUI(fileName)
    print("load ui file name :" .. fileName);
    return ui:LoadLayout(GetEditorUIXMLFile(fileName));
end




