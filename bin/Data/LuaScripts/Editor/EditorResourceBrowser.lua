browserWindow = nil; -- UIElement
browserFilterWindow = nil; -- Window
browserDirList = nil; -- ListView
browserFileList = nil; -- ListView
browserSearch = nil; -- LineEdit
browserDragFile = nil; -- BrowserFile
browserDragNode = nil; -- Node
browserDragComponent = nil; -- Component
resourceBrowserPreview = nil; -- View3D
resourcePreviewScene = nil; -- Scene
resourcePreviewNode = nil; -- Node
resourcePreviewCameraNode = nil; -- Node
resourcePreviewLightNode = nil; -- Node
resourcePreviewLight = nil; -- Light
browserSearchSortMode = 0;

rootDir = nil; -- BrowserDir
browserFiles = {}; -- Array<BrowserFile@>
browserDirs = {}; -- Dictionary 
activeResourceTypeFilters = {}; -- Array<int> 
activeResourceDirFilters = {}; -- Array<int> 

 browserFilesToScan = {} --Array<BrowserFile@>;
BROWSER_WORKER_ITEMS_PER_TICK = 10;
BROWSER_SEARCH_LIMIT = 50;
BROWSER_SORT_MODE_ALPHA = 1;
BROWSER_SORT_MODE_SEARCH = 2;

RESOURCE_TYPE_UNUSABLE = -2;
RESOURCE_TYPE_UNKNOWN = -1;
RESOURCE_TYPE_NOTSET = 0;
RESOURCE_TYPE_SCENE = 1;
RESOURCE_TYPE_SCRIPTFILE = 2;
RESOURCE_TYPE_MODEL = 3;
RESOURCE_TYPE_MATERIAL = 4;
RESOURCE_TYPE_ANIMATION = 5;
RESOURCE_TYPE_IMAGE = 6;
RESOURCE_TYPE_SOUND = 7;
RESOURCE_TYPE_TEXTURE = 8;
RESOURCE_TYPE_FONT = 9;
RESOURCE_TYPE_PREFAB = 10;
RESOURCE_TYPE_TECHNIQUE = 11;
RESOURCE_TYPE_PARTICLEEFFECT = 12;
RESOURCE_TYPE_UIELEMENT = 13;
RESOURCE_TYPE_UIELEMENTS = 14;
RESOURCE_TYPE_ANIMATION_SETTINGS = 15;
RESOURCE_TYPE_RENDERPATH = 16;
RESOURCE_TYPE_TEXTURE_ATLAS = 17;
RESOURCE_TYPE_2D_PARTICLE_EFFECT = 18;
RESOURCE_TYPE_TEXTURE_3D = 19;
RESOURCE_TYPE_CUBEMAP = 20;
RESOURCE_TYPE_PARTICLEEMITTER = 21;
RESOURCE_TYPE_2D_ANIMATION_SET = 22;

-- any resource type > 0 is valid
NUMBER_OF_VALID_RESOURCE_TYPES = 22;

XML_TYPE_SCENE = StringHash("scene");
XML_TYPE_NODE = StringHash("node");
XML_TYPE_MATERIAL = StringHash("material");
XML_TYPE_TECHNIQUE = StringHash("technique");
XML_TYPE_PARTICLEEFFECT = StringHash("particleeffect");
XML_TYPE_PARTICLEEMITTER = StringHash("particleemitter");
XML_TYPE_TEXTURE = StringHash("texture");
XML_TYPE_ELEMENT = StringHash("element");
XML_TYPE_ELEMENTS = StringHash("elements");
XML_TYPE_ANIMATION_SETTINGS = StringHash("animation");
XML_TYPE_RENDERPATH = StringHash("renderpath");
XML_TYPE_TEXTURE_ATLAS = StringHash("TextureAtlas");
XML_TYPE_2D_PARTICLE_EFFECT = StringHash("particleEmitterConfig");
XML_TYPE_TEXTURE_3D = StringHash("texture3d");
XML_TYPE_CUBEMAP = StringHash("cubemap");
XML_TYPE_SPRITER_DATA = StringHash("spriter_data");

BINARY_TYPE_SCENE = StringHash ("USCN");
BINARY_TYPE_PACKAGE = StringHash ("UPAK");
BINARY_TYPE_COMPRESSED_PACKAGE = StringHash ("ULZ4");
BINARY_TYPE_ANGLESCRIPT = StringHash ("ASBC");
BINARY_TYPE_MODEL = StringHash ("UMDL");
BINARY_TYPE_SHADER = StringHash ("USHD");
BINARY_TYPE_ANIMATION = StringHash ("UANI");

EXTENSION_TYPE_TTF = StringHash (".ttf");
EXTENSION_TYPE_OTF = StringHash (".otf");
EXTENSION_TYPE_OGG = StringHash (".ogg");
EXTENSION_TYPE_WAV = StringHash (".wav");
EXTENSION_TYPE_DDS = StringHash (".dds");
EXTENSION_TYPE_PNG = StringHash (".png");
EXTENSION_TYPE_JPG = StringHash (".jpg");
EXTENSION_TYPE_JPEG = StringHash (".jpeg");
EXTENSION_TYPE_TGA = StringHash (".tga");
EXTENSION_TYPE_OBJ = StringHash (".obj");
EXTENSION_TYPE_FBX = StringHash (".fbx");
EXTENSION_TYPE_COLLADA = StringHash (".dae");
EXTENSION_TYPE_BLEND = StringHash (".blend");
EXTENSION_TYPE_ANGELSCRIPT = StringHash (".as");
EXTENSION_TYPE_LUASCRIPT = StringHash (".lua");
EXTENSION_TYPE_HLSL = StringHash (".hlsl");
EXTENSION_TYPE_GLSL = StringHash (".glsl");
EXTENSION_TYPE_FRAGMENTSHADER = StringHash (".frag");
EXTENSION_TYPE_VERTEXSHADER = StringHash (".vert");
EXTENSION_TYPE_HTML = StringHash (".html");

TEXT_VAR_FILE_ID = StringHash ("browser_file_id");
TEXT_VAR_DIR_ID = StringHash ("browser_dir_id");
TEXT_VAR_RESOURCE_TYPE = StringHash ("resource_type");
TEXT_VAR_RESOURCE_DIR_ID = StringHash ("resource_dir_id");

BROWSER_FILE_SOURCE_RESOURCE_DIR = 1;

browserDirIndex = 1;
browserFileIndex = 1;
selectedBrowserDirectory = nil; -- BrowserDir
selectedBrowserFile = nil; -- BrowserDir
browserStatusMessage = nil; -- Text
browserResultsMessage = nil; -- Text
ignoreRefreshBrowserResults = false;
resourceDirsCache = '';


function CreateResourceBrowser()
    if (browserWindow ~= nil) then 
		return; 
	end

    CreateResourceBrowserUI();
    InitResourceBrowserPreview();
    RebuildResourceDatabase();
end

function RebuildResourceDatabase()
    if (browserWindow == nil) then
        return;
	end

    local newResourceDirsCache = Join(cache.resourceDirs, ';');
    ScanResourceDirectories();
    if (newResourceDirsCache ~= resourceDirsCache) then
        resourceDirsCache = newResourceDirsCache;
        PopulateResourceDirFilters();
	end
    PopulateBrowserDirectories();
    PopulateResourceBrowserFilesByDirectory(rootDir);
end

function ScanResourceDirectories()
    Clear(browserDirs);
    Clear(browserFiles);
    Clear(browserFilesToScan);

    rootDir = BrowserDir("");
	browserDirs[""] = rootDir;

    -- collect all of the items and sort them afterwards
	for i = 1, #cache.resourceDirs do
		if (Find(activeResourceDirFilters, i) == -1) then
			ScanResourceDir(i);
		end
	end
end

-- used to stop ui from blocking while determining file types
function DoResourceBrowserWork()
    if (empty(browserFilesToScan)) then
        return;
	end

    local counter = 0;
    local updateBrowserUI = false;
    local scanItem = browserFilesToScan[0];
    while(counter < BROWSER_WORKER_ITEMS_PER_TICK) do
        scanItem:DetermainResourceType();

        -- next
        Erase(browserFilesToScan, 0);
        if (empty(browserFilesToScan) > 0) then
            scanItem = browserFilesToScan[0];
        else
            break;
		end
        counter = counter + 1;
	end

    if (empty(browserFilesToScan) > 0) then
        browserStatusMessage.text = "Files left to scan: " .. length(browserFilesToScan);
    else
        browserStatusMessage.text = "Scan complete";
	end
end

function CreateResourceBrowserUI()
    browserWindow = LoadEditorUI("UI/EditorResourceBrowser.xml");
    browserDirList = browserWindow:GetChild("DirectoryList", true);
    browserFileList = browserWindow:GetChild("FileList", true);
    browserSearch = browserWindow:GetChild("Search", true);
    browserStatusMessage = browserWindow:GetChild("StatusMessage", true);
    browserResultsMessage = browserWindow:GetChild("ResultsMessage", true);
    -- browserWindow.visible = false;
    browserWindow.opacity = uiMaxOpacity;

    browserFilterWindow = LoadEditorUI("UI/EditorResourceFilterWindow.xml");
    CreateResourceFilterUI();
    HideResourceFilterWindow();

    local height = Min(ui.root.height / 4, 300);
	browserWindow:SetSize(900, height);
	browserWindow:SetPosition(35, ui.root.height - height - 25);

    CloseContextMenu();
    ui.root:AddChild(browserWindow);
    ui.root:AddChild(browserFilterWindow);

    SubscribeToEvent(browserWindow:GetChild("CloseButton", true), "Released", "HideResourceBrowserWindow");
    SubscribeToEvent(browserWindow:GetChild("RescanButton", true), "Released", "HandleRescanResourceBrowserClick");
    SubscribeToEvent(browserWindow:GetChild("FilterButton", true), "Released", "ToggleResourceFilterWindow");
    SubscribeToEvent(browserDirList, "SelectionChanged", "HandleResourceBrowserDirListSelectionChange");
    SubscribeToEvent(browserSearch, "TextChanged", "HandleResourceBrowserSearchTextChange");
    SubscribeToEvent(browserFileList, "ItemClicked", "HandleBrowserFileClick");
    SubscribeToEvent(browserFileList, "SelectionChanged", "HandleResourceBrowserFileListSelectionChange");
    SubscribeToEvent(cache, "FileChanged", "HandleFileChanged");
end

function CreateResourceFilterUI()
    local options = browserFilterWindow:GetChild("TypeOptions", true);
    local toggleAllTypes = browserFilterWindow:GetChild("ToggleAllTypes", true);
    local toggleAllResourceDirs = browserFilterWindow:GetChild("ToggleAllResourceDirs", true);
    SubscribeToEvent(toggleAllTypes, "Toggled", "HandleResourceTypeFilterToggleAllTypesToggled");
    SubscribeToEvent(toggleAllResourceDirs, "Toggled", "HandleResourceDirFilterToggleAllTypesToggled");
    SubscribeToEvent(browserFilterWindow:GetChild("CloseButton", true), "Released", "HideResourceFilterWindow");

    local columns = 2;
    local col1 = browserFilterWindow:GetChild("TypeFilterColumn1", true);
    local col2 = browserFilterWindow:GetChild("TypeFilterColumn2", true);

    -- use array to get sort of items
    local sorted = {};
	for i = 1, NUMBER_OF_VALID_RESOURCE_TYPES do
        Push(sorted, ResourceType(i, ResourceTypeName(i)));
	end
        
    -- 2 unknown types are reserved for the top, the rest are alphabetized
    Sort(sorted);
    Insert(sorted, 0, ResourceType(RESOURCE_TYPE_UNKNOWN, ResourceTypeName(RESOURCE_TYPE_UNKNOWN)) );
    Insert(sorted, 0, ResourceType(RESOURCE_TYPE_UNUSABLE,  ResourceTypeName(RESOURCE_TYPE_UNUSABLE)) );
    local halfColumns = Ceil( length(sorted) / columns);

	for i = 1, #sorted do
        local type = sorted[i];
        local resourceTypeHolder = UIElement();
        if (i < halfColumns) then
            col1:AddChild(resourceTypeHolder);
        else
            col2:AddChild(resourceTypeHolder);
		end

        resourceTypeHolder.layoutMode = LM_HORIZONTAL;
        resourceTypeHolder.layoutSpacing = 4;

        local label = Text:new();
        label.style = "EditorAttributeText";
        label.text = type.name;
        local checkbox = CheckBox();
        checkbox.name = type.ID;
		checkbox:SetStyleAuto();
		checkbox:GetVars():SetInt(TEXT_VAR_RESOURCE_TYPE, i);
        checkbox.checked = true;
        SubscribeToEvent(checkbox, "Toggled", "HandleResourceTypeFilterToggled");

		resourceTypeHolder:AddChild(checkbox);
		resourceTypeHolder:AddChild(label);
	end
end

function CreateDirList(dir, parentUI)
    local dirText = Text:new();
	browserDirList:InsertItem(browserDirList.numItems, dirText, parentUI);
    dirText.style = "FileSelectorListText";
    dirText.text = ifor(empty(dir.resourceKey), "Root" , dir.name);
    dirText.name = dir.resourceKey;
	dirText:GetVars():SetString(TEXT_VAR_DIR_ID, dir.resourceKey);

    -- Sort directories alphetically
    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA;
    dir.children:Sort();
	
	for i = 0, dir.children.length do
        CreateDirList(dir.children[i], dirText);
	end
end

function CreateFileList(file)
    local fileText = Text:new();
    fileText.style = "FileSelectorListText";
    fileText.layoutMode = LM_HORIZONTAL;
	browserFileList:InsertItem(browserFileList.numItems, fileText);
    file.browserFileListRow = fileText;
    InitializeBrowserFileListRow(fileText, file);
end

function InitializeBrowserFileListRow(fileText, file)
    fileText:RemoveAllChildren();
    local params = VariantMap:new();
	fileText:GetVars():SetInt(TEXT_VAR_FILE_ID, file.ID);
	fileText:GetVars():SetString(TEXT_VAR_RESOURCE_TYPE, file.resourceType);
    if (file.resourceType > 0) then
        fileText.dragDropMode = DD_SOURCE;
	end

    do
        local text = Text:new();
		fileText:AddChild(text);
        text.style = "FileSelectorListText";
        text.text = file.fullname;
        text.name = file.resourceKey;
	end

    do
        local text = Text:new();
		fileText:AddChild(text);
        text.style = "FileSelectorListText";
        text.text = file.ResourceTypeName();
	end

    if (file.resourceType == RESOURCE_TYPE_MATERIAL or 
            file.resourceType == RESOURCE_TYPE_MODEL or 
            file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT or 
            file.resourceType == RESOURCE_TYPE_PREFAB
        ) then
        SubscribeToEvent(fileText, "DragBegin", "HandleBrowserFileDragBegin");
        SubscribeToEvent(fileText, "DragEnd", "HandleBrowserFileDragEnd");
	end
end

function InitResourceBrowserPreview()
    resourcePreviewScene = Scene:new("PreviewScene");
	resourcePreviewScene:CreateComponent("Octree");
    local physicsWorld = resourcePreviewScene:CreateComponent("PhysicsWorld");
    physicsWorld.enabled = false;
    physicsWorld.gravity = Vector3(0.0, 0.0, 0.0);

    local zoneNode = resourcePreviewScene:CreateChild("Zone");
    local zone = zoneNode:CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000, 1000);
    zone.ambientColor = Color(0.15, 0.15, 0.15);
    zone.fogColor = Color(0, 0, 0);
    zone.fogStart = 10.0;
    zone.fogEnd = 100.0;

    resourcePreviewCameraNode = resourcePreviewScene:CreateChild("PreviewCamera");
    resourcePreviewCameraNode.position = Vector3(0, 0, -1.5);
    local camera = resourcePreviewCameraNode:CreateComponent("Camera");
    camera.nearClip = 0.1;
    camera.farClip = 100.0;

    resourcePreviewLightNode = resourcePreviewScene:CreateChild("PreviewLight");
    resourcePreviewLightNode.direction = Vector3(0.5, -0.5, 0.5);
    resourcePreviewLight = resourcePreviewLightNode:CreateComponent("Light");
    resourcePreviewLight.lightType = LIGHT_DIRECTIONAL;
    resourcePreviewLight.specularIntensity = 0.5;

    resourceBrowserPreview = browserWindow:GetChild("ResourceBrowserPreview", true);
	resourceBrowserPreview:SetFixedHeight(200);
	resourceBrowserPreview:SetFixedWidth(266);
	resourceBrowserPreview:SetView(resourcePreviewScene, camera);
    resourceBrowserPreview.autoUpdate = false;

    resourcePreviewNode = resourcePreviewScene:CreateChild("PreviewNodeContainer");

    SubscribeToEvent(resourceBrowserPreview, "DragMove", "RotateResourceBrowserPreview");

    RefreshBrowserPreview();
end

-- Opens a contextual menu based on what resource item was actioned
function HandleBrowserFileClick(eventType, eventData)
    if (eventData["Button"]:GetInt() ~= MOUSEB_RIGHT) then
        return;
	end

    local uiElement = eventData["Item"]:GetPtr();
    local file = GetBrowserFileFromUIElement(uiElement);

    if (file == nil) then
        return;
	end

    local actions = {};
    if (file.resourceType == RESOURCE_TYPE_MATERIAL) then
        Push(actions, CreateBrowserFileActionMenu("Edit", "HandleBrowserEditResource", file));
    elseif (file.resourceType == RESOURCE_TYPE_MODEL) then
        Push(actions, CreateBrowserFileActionMenu("Instance Animated Model", "HandleBrowserInstantiateAnimatedModel", file));
        Push(actions, CreateBrowserFileActionMenu("Instance Static Model", "HandleBrowserInstantiateStaticModel", file));
    elseif (file.resourceType == RESOURCE_TYPE_PREFAB) then
        Push(actions, CreateBrowserFileActionMenu("Instance Prefab", "HandleBrowserInstantiatePrefab", file));
        Push(actions, CreateBrowserFileActionMenu("Instance in Spawner", "HandleBrowserInstantiateInSpawnEditor", file));
    elseif (file.fileType == EXTENSION_TYPE_OBJ  or
        file.fileType == EXTENSION_TYPE_COLLADA  or
        file.fileType == EXTENSION_TYPE_FBX  or
        file.fileType == EXTENSION_TYPE_BLEND) then
        Push(actions, CreateBrowserFileActionMenu("Import Model", "HandleBrowserImportModel", file));
        Push(actions, CreateBrowserFileActionMenu("Import Scene", "HandleBrowserImportScene", file));
    elseif (file.resourceType == RESOURCE_TYPE_UIELEMENT) then
        Push(actions, CreateBrowserFileActionMenu("Open UI Layout", "HandleBrowserOpenUILayout", file));
    elseif (file.resourceType == RESOURCE_TYPE_SCENE) then
        Push(actions, CreateBrowserFileActionMenu("Load Scene", "HandleBrowserLoadScene", file));
    elseif (file.resourceType == RESOURCE_TYPE_SCRIPTFILE) then
        Push(actions, CreateBrowserFileActionMenu("Execute Script", "HandleBrowserRunScript", file));
    elseif (file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT) then
       Push(actions, CreateBrowserFileActionMenu("Edit", "HandleBrowserEditResource", file));
	end

    Push(actions, CreateBrowserFileActionMenu("Open", "HandleBrowserOpenResource", file));

    ActivateContextMenu(actions);
end

function GetBrowserDir(path)
    local browserDir;
	browserDirs:Get(path, browserDir);
    return browserDir;
end

-- Makes sure the entire directory tree exists and new dir is linked to parent
function InitBrowserDir(path)
    local browserDir;
    if (browserDirs:Get(path, browserDir)) then
        return browserDir;
	end

    local parts = Split(path, '/');
    local finishedParts = {};
    if (length(parts) > 0) then
        local parent = rootDir;
		for i = 1, #parts do
            Push(finishedParts, parts[i]);
            local currentPath = Join(finishedParts, "/");
            if (not browserDirs:Get(currentPath, browserDir)) then
                browserDir = BrowserDir(currentPath);
				browserDirs:Set(currentPath, browserDir);
                parent.children:Push(browserDir);
			end
            parent = browserDir;
		end
        return browserDir;
	end
    return nil;
end

function ScanResourceDir(resourceDirIndex)
    local resourceDir = cache.resourceDirs[resourceDirIndex];
    ScanResourceDirFiles("", resourceDirIndex);
    local dirs = fileSystem:ScanDir(resourceDir, "*", SCAN_DIRS, true);
	for i = 1, #dir do
        local path = dirs[i];
        if (not EndsWith(path, ".")) then

	        InitBrowserDir(path);
			ScanResourceDirFiles(path, resourceDirIndex);
		end
	end
end

function ScanResourceDirFiles(path, resourceDirIndex)
    local fullPath = cache.resourceDirs[resourceDirIndex] .. path;
    if (not fileSystem:DirExists(fullPath)) then
        return;
	end

    local dir = GetBrowserDir(path);

    if (dir == nil) then
        return;
	end

    -- get files in directory
    local dirFiles = fileSystem:ScanDir(fullPath, "*.*", SCAN_FILES, false);

    -- add new files
	for x = 1, #dirFiles do
        local filename = dirFiles[x];
        local browserFile = dir:AddFile(filename, resourceDirIndex, BROWSER_FILE_SOURCE_RESOURCE_DIR);
        Push(browserFiles, browserFile);
        Push(browserFilesToScan, browserFile);
	end
end

function HideResourceBrowserWindow()
    browserWindow.visible = false;
end

function ShowResourceBrowserWindow()
    browserWindow.visible = true;
    browserWindow:BringToFront();
    ui.focusElement = browserSearch;
    return true;
end

function ToggleResourceFilterWindow()
    if (browserFilterWindow.visible) then
        HideResourceFilterWindow();
    else
        ShowResourceFilterWindow();
	end
end

function HideResourceFilterWindow()
    browserFilterWindow.visible = false;
end

function ShowResourceFilterWindow()
    local x = browserWindow.position.x + browserWindow.width - browserFilterWindow.width;
    local y = browserWindow.position.y - browserFilterWindow.height - 1;
    browserFilterWindow.position = IntVector2(x,y);
    browserFilterWindow.visible = true;
	browserFilterWindow:BringToFront();
end

function PopulateResourceDirFilters()
    local resourceDirs = browserFilterWindow:GetChild("DirFilters", true);
	resourceDirs:RemoveAllChildren();
    Clear(activeResourceDirFilters);
	for i = 0, cache.resourceDirs.length - 1 do
        local resourceDirHolder = UIElement:new();
		resourceDirs:AddChild(resourceDirHolder);
        resourceDirHolder.layoutMode = LM_HORIZONTAL;
        resourceDirHolder.layoutSpacing = 4;
		resourceDirHolder:SetFixedHeight(16);

        local label = Text:new();
        label.style = "EditorAttributeText";
        label.text = cache.resourceDirs[i].Replaced(fileSystem.programDir, "");
        local checkbox = CheckBox:new();
        checkbox.name = i;
		checkbox:SetStyleAuto();
		checkbox:GetVars():SetInt(TEXT_VAR_RESOURCE_DIR_ID, i);
        checkbox.checked = true;
        SubscribeToEvent(checkbox, "Toggled", "HandleResourceDirFilterToggled");


		resourceDirHolder:AddChild(checkbox);
		resourceDirHolder:AddChild(label);
	end

end

function PopulateBrowserDirectories()
    browserDirList:RemoveAllItems();
    CreateDirList(rootDir);
    browserDirList.selection = 0;
end

function PopulateResourceBrowserFilesByDirectory(dir)
    selectedBrowserDirectory = dir;
	browserFileList:RemoveAllItems();
    if (dir == nil) then return; end

    local files = {};
	for x = 0, dir.files.length - 1 do
        local file = dir.files[x];

        if (Find(activeResourceTypeFilters, file.resourceType) == -1) then
            Push(files, file);
		end
	end

    -- Sort alphetically
    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA;
    Sort(files);
    PopulateResourceBrowserResults(files);
    browserResultsMessage.text = "Showing " .. length(files).. " files";
end


function PopulateResourceBrowserBySearch()
    local query = browserSearch.text;

    local scores = {};
    local scored = {};
    local filtered = {};
    do 
        local file;
		for x = 0, x < browserFiles.length - 1 do
            file = browserFiles[x];
            file.sortScore = -1;
            if (not Find(activeResourceTypeFilters, file.resourceType) > -1) then
	            if (not Find(activeResourceDirFilters, file.resourceSourceIndex) > -1) then

                    local find = Find(file.fullname, query, 0, false);
                    if (find > -1) then
                        local fudge = query.length - file.fullname.length;
                        local score = find * int(Abs(fudge*2)) + int(Abs(fudge));
                        file.sortScore = score;
                        Push(scored, file);
                        Push(scores, score);
        			end
                end
            end
		end
	end

    -- cut this down for a faster sort
    if (scored.length > BROWSER_SEARCH_LIMIT) then
        Sort(scores);
        local scoreThreshold = scores[BROWSER_SEARCH_LIMIT];
        local file;
		for i = 1, #scored do
            file = scored[x];
            if (file.sortScore <= scoreThreshold) then
                Push(filtered, file);
			end
		end
    else
        filtered = scored;
	end

    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA;
    Sort(filtered);
    PopulateResourceBrowserResults(filtered);
    browserResultsMessage.text = "Showing top " .. filtered.length .. " of " .. length(scored) .. " results";
end

function PopulateResourceBrowserResults(files)
    browserFileList:RemoveAllItems();
	for i = 1, #files do
        CreateFileList(files[i]);
	end
end

function RefreshBrowserResults()
    if (empty(browserSearch.text)) then
        browserDirList.visible = true;
        PopulateResourceBrowserFilesByDirectory(selectedBrowserDirectory);
    else
        browserDirList.visible = false;
        PopulateResourceBrowserBySearch();
	end
end

function HandleResourceTypeFilterToggleAllTypesToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr();
    local filterHolder = browserFilterWindow:GetChild("TypeFilters", true);
    local children = filterHolder:GetChildren(true);

    ignoreRefreshBrowserResults = true;
	for i = 1, #children do
        local filter = children[i];
        if (filter ~= nil) then
            filter.checked = checkbox.checked;
		end
	end
    ignoreRefreshBrowserResults = false;
    RefreshBrowserResults();
end

function HandleResourceTypeFilterToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr();
    if (not checkbox:GetVar():Contains(TEXT_VAR_RESOURCE_TYPE)) then
        return;
	end

    local resourceType = checkbox:GetVar():GetInt(TEXT_VAR_RESOURCE_TYPE);
    local find = Find(activeResourceTypeFilters, resourceType);

    if (checkbox.checked and find ~= -1) then
        Erase(activeResourceTypeFilters, find);
    elseif (not checkbox.checked and find == -1) then
        Push(activeResourceTypeFilters, resourceType);
	end

    if (ignoreRefreshBrowserResults == false) then
        RefreshBrowserResults();
	end
end

function HandleResourceDirFilterToggleAllTypesToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr();
    local filterHolder = browserFilterWindow:GetChild("DirFilters", true);
    local children = filterHolder:GetChildren(true);

    ignoreRefreshBrowserResults = true;
	for i = 1, #children do
        local filter = children[i];
        if (filter ~= nil) then
            filter.checked = checkbox.checked;
		end
	end
    ignoreRefreshBrowserResults = false;
    RebuildResourceDatabase();
end

function HandleResourceDirFilterToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr();
    if (not checkbox:GetVars():Contains(TEXT_VAR_RESOURCE_DIR_ID)) then
        return;
	end

    local resourceDir = checkbox:GetVar():GetInt(TEXT_VAR_RESOURCE_DIR_ID);
    local find = Find(activeResourceDirFilters, resourceDir);

    if (checkbox.checked and find ~= -1) then
        Erase(activeResourceDirFilters, find);
    elseif (not checkbox.checked and find == -1) then
        Push(activeResourceDirFilters, resourceDir);
	end

    if (ignoreRefreshBrowserResults == false) then
        RebuildResourceDatabase();
	end
end

function HandleRescanResourceBrowserClick(eventType, eventData)
    RebuildResourceDatabase();
end

function HandleResourceBrowserDirListSelectionChange(eventType, eventData)
    if (browserDirList.selection == M_MAX_UNSIGNED) then
        return;
	end

    local uiElement = browserDirList:GetItems()[browserDirList.selection];
    local dir = GetBrowserDir(uiElement:GetVars():GetString(TEXT_VAR_DIR_ID));
    if (dir == nil) then
        return;
	end

    PopulateResourceBrowserFilesByDirectory(dir);
end

function HandleResourceBrowserFileListSelectionChange(eventType, eventData)
    if (browserFileList.selection == M_MAX_UNSIGNED) then
        return;
	end

    local uiElement = browserFileList:GetItems()[browserFileList.selection];
    local file = GetBrowserFileFromUIElement(uiElement);
    if (file == nil) then
        return;
	end

    if (resourcePreviewNode ~= nil) then 
        resourcePreviewNode:Remove();
	end

    resourcePreviewNode = resourcePreviewScene:CreateChild("PreviewNodeContainer");
    CreateResourcePreview(file.GetFullPath(), resourcePreviewNode);

    if (resourcePreviewNode ~= nil) then
        local boxes = {};
        local staticModels = resourcePreviewNode:GetComponents("StaticModel", true);
        local animatedModels = resourcePreviewNode:GetComponents("AnimatedModel", true);

		for i = 1, #staticModels do
            Push(boxes, tolua.cast(staticModels[i], "StaticModel").worldBoundingBox);
		end

		for i = 1, #animatedModels do
            Push(boxes, tolua.cast(animatedModels[i], "AnimatedModel").worldBoundingBox);
		end

        if (#boxes > 0) then
            local camPosition = Vector3(0.0, 0.0, -1.2);
            local biggestBox = boxes[1];
			for i = 2, #boxes do
                if (boxes[i].size.length > biggestBox.size.length) then
                    biggestBox = boxes[i];
				end
			end
            resourcePreviewCameraNode.position = biggestBox.center + camPosition * biggestBox.size.length;
		end

        resourcePreviewScene.AddChild(resourcePreviewNode);
        RefreshBrowserPreview();
	end
end

function HandleResourceBrowserSearchTextChange(eventType, eventData)
    RefreshBrowserResults();
end

function GetBrowserFileFromId(id)
    if (id == 0) then
        return nil;
	end

    local file;
	for i = 1, #browserFiles do
        file = browserFiles[i];
        if (file.ID == id) then 
			return file;
		end
	end
    return nil;
end

function GetBrowserFileFromUIElement(element)
    if (element == nil or not element:GetVars():Contains(TEXT_VAR_FILE_ID)) then
        return nil;
	end
    return GetBrowserFileFromId(element:GetVars():GetUInt(TEXT_VAR_FILE_ID));
end

function GetBrowserFileFromPath(path)
	for i = 1, #browserFiles do
        local file = browserFiles[i];
        if (path == file:GetFullPath()) then
            return file;
		end
	end
    return nil;
end

function HandleBrowserEditResource(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file == nil) then
        return;
	end

    if (file.resourceType == RESOURCE_TYPE_MATERIAL) then
        local material = cache:GetResource("Material", file.resourceKey);
        if (material ~= nil) then
            EditMaterial(material);
		end
	end

    if (file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT) then
        local particleEffect = cache:GetResource("ParticleEffect", file.resourceKey);
        if (particleEffect ~= nil) then
            EditParticleEffect(particleEffect);
		end
	end
end

function HandleBrowserOpenResource(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        OpenResource(file.resourceKey);
	end
end

function HandleBrowserImportScene(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        ImportScene(file.GetFullPath());
	end
end

function HandleBrowserImportModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        ImportModel(file.GetFullPath());
	end
end

function HandleBrowserOpenUILayout(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        OpenUILayout(file.GetFullPath());
	end
end

function HandleBrowserInstantiateStaticModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        CreateModelWithStaticModel(file.resourceKey, editNode);
	end
end

function HandleBrowserInstantiateAnimatedModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        CreateModelWithAnimatedModel(file.resourceKey, editNode);
	end
end

function HandleBrowserInstantiatePrefab(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        LoadNode(file.GetFullPath());
	end
end

function HandleBrowserInstantiateInSpawnEditor(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        spawnedObjectsNames:Resize(1);
        spawnedObjectsNames[0] = VerifySpawnedObjectFile(file.GetPath());
        RefreshPickedObjects();
        ShowSpawnEditor();
	end 
end

function HandleBrowserLoadScene(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        LoadScene(file.GetFullPath());
	end
end

function HandleBrowserRunScript(eventType, eventData)
    local element = eventData["Element"]:GetPtr();
    local file = GetBrowserFileFromUIElement(element);
    if (file ~= nil) then
        ExecuteScript(ExtractFileName(eventData));
	end
end

function HandleBrowserFileDragBegin(eventType, eventData)
    local uiElement = eventData["Element"]:GetPtr();
    browserDragFile = GetBrowserFileFromUIElement(uiElement);
end

function HandleBrowserFileDragEnd(eventType, eventData)
    if (browserDragFile == nil) then
        return;
	end

    local element = ui.GetElementAt(ui.cursor.screenPosition);
    if (element ~= nil) then
        return;
	end

    if (browserDragFile.resourceType == RESOURCE_TYPE_MATERIAL) then
        local model = tolua.cast(GetDrawableAtMousePostion(), "StaticModel");
        if (model ~= nil) then
            AssignMaterial(model, browserDragFile.resourceKey);
		end
	end

    browserDragFile = nil;
    browserDragComponent = nil;
    browserDragNode = nil;
end

function HandleFileChanged(eventType, eventData)
    local filename = eventData["FileName"]:GetString();
    local file = GetBrowserFileFromPath(filename);
    
    if (file == nil) then
        -- TODO: new file logic when watchers are supported 
        return;
    else
        file.FileChanged();
	end
end

function CreateBrowserFileActionMenu(text, handler, browserFile)
    local menu = CreateContextMenuItem(text, handler);
    if (browserFile ~= nil) then
        menu:GetVars():SetInt(TEXT_VAR_FILE_ID, browserFile.ID);
	end

    return menu;
end

function GetResourceType(path)
    local fileType;
    return GetResourceType(path, fileType);
end

function GetResourceType(path, fileType, useCache)
	if (useCache == nil) then
		useCache = false;
	end
    if (GetExtensionType(path, fileType) or GetBinaryType(path, fileType, useCache) or GetXmlType(path, fileType, useCache)) then
        return GetResourceType(fileType);
	end

    return RESOURCE_TYPE_UNKNOWN;
end


function GetResourceType(fileType)
    -- binary fileTypes
    if (fileType == BINARY_TYPE_SCENE) then
        return RESOURCE_TYPE_SCENE;
    elseif (fileType == BINARY_TYPE_PACKAGE) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif (fileType == BINARY_TYPE_COMPRESSED_PACKAGE) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif (fileType == BINARY_TYPE_ANGLESCRIPT) then
        return RESOURCE_TYPE_SCRIPTFILE;
    elseif (fileType == BINARY_TYPE_MODEL) then
        return RESOURCE_TYPE_MODEL;
    elseif (fileType == BINARY_TYPE_SHADER) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif (fileType == BINARY_TYPE_ANIMATION) then
        return RESOURCE_TYPE_ANIMATION;

    -- xml fileTypes
    elseif (fileType == XML_TYPE_SCENE) then
        return RESOURCE_TYPE_SCENE;
    elseif (fileType == XML_TYPE_NODE) then
        return RESOURCE_TYPE_PREFAB;
    elseif(fileType == XML_TYPE_MATERIAL) then
        return RESOURCE_TYPE_MATERIAL;
    elseif(fileType == XML_TYPE_TECHNIQUE) then
        return RESOURCE_TYPE_TECHNIQUE;
    elseif(fileType == XML_TYPE_PARTICLEEFFECT) then
        return RESOURCE_TYPE_PARTICLEEFFECT;
    elseif(fileType == XML_TYPE_PARTICLEEMITTER) then
        return RESOURCE_TYPE_PARTICLEEMITTER;
    elseif(fileType == XML_TYPE_TEXTURE) then
        return RESOURCE_TYPE_TEXTURE;
    elseif(fileType == XML_TYPE_ELEMENT) then
        return RESOURCE_TYPE_UIELEMENT;
    elseif(fileType == XML_TYPE_ELEMENTS) then
        return RESOURCE_TYPE_UIELEMENTS;
    elseif (fileType == XML_TYPE_ANIMATION_SETTINGS) then
        return RESOURCE_TYPE_ANIMATION_SETTINGS;
    elseif (fileType == XML_TYPE_RENDERPATH) then
        return RESOURCE_TYPE_RENDERPATH;
    elseif (fileType == XML_TYPE_TEXTURE_ATLAS) then
        return RESOURCE_TYPE_TEXTURE_ATLAS;
    elseif (fileType == XML_TYPE_2D_PARTICLE_EFFECT) then
        return RESOURCE_TYPE_2D_PARTICLE_EFFECT;
    elseif (fileType == XML_TYPE_TEXTURE_3D) then
        return RESOURCE_TYPE_TEXTURE_3D;
    elseif (fileType == XML_TYPE_CUBEMAP) then
        return RESOURCE_TYPE_CUBEMAP;
    elseif (fileType == XML_TYPE_SPRITER_DATA) then
        return RESOURCE_TYPE_2D_ANIMATION_SET;

    -- extension fileTypes
    elseif (fileType == EXTENSION_TYPE_TTF) then
        return RESOURCE_TYPE_FONT;
    elseif (fileType == EXTENSION_TYPE_OTF) then
        return RESOURCE_TYPE_FONT;
    elseif (fileType == EXTENSION_TYPE_OGG) then
        return RESOURCE_TYPE_SOUND;
    elseif(fileType == EXTENSION_TYPE_WAV) then
        return RESOURCE_TYPE_SOUND;
    elseif(fileType == EXTENSION_TYPE_DDS) then
        return RESOURCE_TYPE_IMAGE;
    elseif(fileType == EXTENSION_TYPE_PNG) then
        return RESOURCE_TYPE_IMAGE;
    elseif(fileType == EXTENSION_TYPE_JPG) then
        return RESOURCE_TYPE_IMAGE;
    elseif(fileType == EXTENSION_TYPE_JPEG) then
        return RESOURCE_TYPE_IMAGE;
    elseif(fileType == EXTENSION_TYPE_TGA) then
        return RESOURCE_TYPE_IMAGE;
    elseif(fileType == EXTENSION_TYPE_OBJ) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_FBX) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_COLLADA) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_BLEND) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_ANGELSCRIPT)  then
        return RESOURCE_TYPE_SCRIPTFILE;
    elseif(fileType == EXTENSION_TYPE_LUASCRIPT) then
        return RESOURCE_TYPE_SCRIPTFILE;
    elseif(fileType == EXTENSION_TYPE_HLSL) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_GLSL) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_FRAGMENTSHADER) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_VERTEXSHADER) then
        return RESOURCE_TYPE_UNUSABLE;
    elseif(fileType == EXTENSION_TYPE_HTML) then
        return RESOURCE_TYPE_UNUSABLE;
	end

    return RESOURCE_TYPE_UNKNOWN;
end

function GetExtensionType(path, fileType)
    local type = StringHash(GetExtension(path));
    if (type == EXTENSION_TYPE_TTF) then
        fileType = EXTENSION_TYPE_TTF;
    elseif (type == EXTENSION_TYPE_OGG) then
        fileType = EXTENSION_TYPE_OGG;
    elseif(type == EXTENSION_TYPE_WAV) then
        fileType = EXTENSION_TYPE_WAV;
    elseif(type == EXTENSION_TYPE_DDS) then
        fileType = EXTENSION_TYPE_DDS;
    elseif(type == EXTENSION_TYPE_PNG) then
        fileType = EXTENSION_TYPE_PNG;
    elseif(type == EXTENSION_TYPE_JPG) then
        fileType = EXTENSION_TYPE_JPG;
    elseif(type == EXTENSION_TYPE_JPEG) then
        fileType = EXTENSION_TYPE_JPEG;
    elseif(type == EXTENSION_TYPE_TGA) then
        fileType = EXTENSION_TYPE_TGA;
    elseif(type == EXTENSION_TYPE_OBJ) then
        fileType = EXTENSION_TYPE_OBJ;
    elseif(type == EXTENSION_TYPE_FBX) then
        fileType = EXTENSION_TYPE_FBX;
    elseif(type == EXTENSION_TYPE_COLLADA) then
        fileType = EXTENSION_TYPE_COLLADA;
    elseif(type == EXTENSION_TYPE_BLEND) then
        fileType = EXTENSION_TYPE_BLEND;
    elseif(type == EXTENSION_TYPE_ANGELSCRIPT) then
        fileType = EXTENSION_TYPE_ANGELSCRIPT;
    elseif(type == EXTENSION_TYPE_LUASCRIPT) then
        fileType = EXTENSION_TYPE_LUASCRIPT;
    elseif(type == EXTENSION_TYPE_HLSL) then
        fileType = EXTENSION_TYPE_HLSL;
    elseif(type == EXTENSION_TYPE_GLSL) then
        fileType = EXTENSION_TYPE_GLSL;
    elseif(type == EXTENSION_TYPE_FRAGMENTSHADER) then
        fileType = EXTENSION_TYPE_FRAGMENTSHADER;
    elseif(type == EXTENSION_TYPE_VERTEXSHADER) then
        fileType = EXTENSION_TYPE_VERTEXSHADER;
    elseif(type == EXTENSION_TYPE_HTML) then
        fileType = EXTENSION_TYPE_HTML;
    else
        return false;
	end

    return true;
end

function GetBinaryType(path, fileType, useCache)
	if (useCache == nil) then
		useCache = false;
	end
    local type;
    if (useCache) then
        local file = cache.GetFile(path);
        if (file == nil) then
            return false;
		end

        if (file.size == 0) then
            return false;
		end

        type = StringHash(file.ReadFileID());
    else
        local file = File:new();
        if (not file.Open(path)) then
            return false;
		end

        if (file.size == 0) then
            return false;
		end

        type = StringHash(file.ReadFileID());
	end 

    if (type == BINARY_TYPE_SCENE) then
        fileType = BINARY_TYPE_SCENE;
    elseif (type == BINARY_TYPE_PACKAGE) then
        fileType = BINARY_TYPE_PACKAGE;
    elseif (type == BINARY_TYPE_COMPRESSED_PACKAGE) then
        fileType = BINARY_TYPE_COMPRESSED_PACKAGE;
    elseif (type == BINARY_TYPE_ANGLESCRIPT) then
        fileType = BINARY_TYPE_ANGLESCRIPT;
    elseif (type == BINARY_TYPE_MODEL) then
        fileType = BINARY_TYPE_MODEL;
    elseif (type == BINARY_TYPE_SHADER) then
        fileType = BINARY_TYPE_SHADER;
    elseif (type == BINARY_TYPE_ANIMATION) then
        fileType = BINARY_TYPE_ANIMATION;
    else
        return false;
	end

    return true;
end

function GetXmlType(path, fileType, useCache)
	if (useCache == nil) then
		useCache = false;
	end

    local extension = GetExtension(path);
    if (extension == ".txt" or extension == ".json" or extension == ".icns") then
        return false;
	end

    local name;
    if (useCache) then
        local xml = cache:GetResource("XMLFile", path);
        if (xml == nil) then
            return false;
		end

        name = xml.root.name;
    else
        local file = File:new();
        if (not file.Open(path)) then
            return false;
		end

        if (file.size == 0) then
            return false;
		end

        local xml = XMLFile:new();
        if (xml:Load(file)) then
            name = xml.root.name;
        else 
            return false;
		end
	end 

    local found = false;
    if (empty(name)) then
        found = true;
        local type = StringHash(name);
        if (type == XML_TYPE_SCENE) then
            fileType = XML_TYPE_SCENE;
        elseif (type == XML_TYPE_NODE) then
            fileType = XML_TYPE_NODE;
        elseif(type == XML_TYPE_MATERIAL) then
            fileType = XML_TYPE_MATERIAL;
        elseif(type == XML_TYPE_TECHNIQUE) then
            fileType = XML_TYPE_TECHNIQUE;
        elseif(type == XML_TYPE_PARTICLEEFFECT) then
            fileType = XML_TYPE_PARTICLEEFFECT;
        elseif(type == XML_TYPE_PARTICLEEMITTER) then
            fileType = XML_TYPE_PARTICLEEMITTER;
        elseif(type == XML_TYPE_TEXTURE) then
            fileType = XML_TYPE_TEXTURE;
        elseif(type == XML_TYPE_ELEMENT) then
            fileType = XML_TYPE_ELEMENT;
        elseif(type == XML_TYPE_ELEMENTS) then
            fileType = XML_TYPE_ELEMENTS;
        elseif (type == XML_TYPE_ANIMATION_SETTINGS) then
            fileType = XML_TYPE_ANIMATION_SETTINGS;
        elseif (type == XML_TYPE_RENDERPATH) then
            fileType = XML_TYPE_RENDERPATH;
        elseif (type == XML_TYPE_TEXTURE_ATLAS) then
            fileType = XML_TYPE_TEXTURE_ATLAS;
        elseif (type == XML_TYPE_2D_PARTICLE_EFFECT) then
            fileType = XML_TYPE_2D_PARTICLE_EFFECT;
        elseif (type == XML_TYPE_TEXTURE_3D) then
            fileType = XML_TYPE_TEXTURE_3D;
        elseif (type == XML_TYPE_CUBEMAP) then
            fileType = XML_TYPE_CUBEMAP;
        elseif (type == XML_TYPE_SPRITER_DATA) then
            fileType = XML_TYPE_SPRITER_DATA;
        else
            found = false;
		end
	end 
    return found;
end

function ResourceTypeName(resourceType)
    if (resourceType == RESOURCE_TYPE_UNUSABLE) then
        return "Unusable";
    elseif (resourceType == RESOURCE_TYPE_UNKNOWN) then
        return "Unknown";
    elseif (resourceType == RESOURCE_TYPE_NOTSET) then
        return "Uninitialized";
    elseif (resourceType == RESOURCE_TYPE_SCENE) then
        return "Scene";
    elseif (resourceType == RESOURCE_TYPE_SCRIPTFILE) then
        return "Script File";
    elseif (resourceType == RESOURCE_TYPE_MODEL) then
        return "Model";
    elseif (resourceType == RESOURCE_TYPE_MATERIAL) then
        return "Material";
    elseif (resourceType == RESOURCE_TYPE_ANIMATION) then
        return "Animation";
    elseif (resourceType == RESOURCE_TYPE_IMAGE) then
        return "Image";
    elseif (resourceType == RESOURCE_TYPE_SOUND) then
        return "Sound";
    elseif (resourceType == RESOURCE_TYPE_TEXTURE) then
        return "Texture";
    elseif (resourceType == RESOURCE_TYPE_FONT) then
        return "Font";
    elseif (resourceType == RESOURCE_TYPE_PREFAB) then
        return "Prefab";
    elseif (resourceType == RESOURCE_TYPE_TECHNIQUE) then
        return "Render Technique";
    elseif (resourceType == RESOURCE_TYPE_PARTICLEEFFECT) then
        return "Particle Effect";
    elseif (resourceType == RESOURCE_TYPE_PARTICLEEMITTER) then
        return "Particle Emitter";
    elseif (resourceType == RESOURCE_TYPE_UIELEMENT) then
        return "UI Element";
    elseif (resourceType == RESOURCE_TYPE_UIELEMENTS) then
        return "UI Elements";
    elseif (resourceType == RESOURCE_TYPE_ANIMATION_SETTINGS) then
        return "Animation Settings";
    elseif (resourceType == RESOURCE_TYPE_RENDERPATH) then
        return "Render Path";
    elseif (resourceType == RESOURCE_TYPE_TEXTURE_ATLAS) then
        return "Texture Atlas";
    elseif (resourceType == RESOURCE_TYPE_2D_PARTICLE_EFFECT) then
        return "2D Particle Effect";
    elseif (resourceType == RESOURCE_TYPE_TEXTURE_3D) then
        return "Texture 3D";
    elseif (resourceType == RESOURCE_TYPE_CUBEMAP) then
        return "Cubemap";
    elseif (resourceType == RESOURCE_TYPE_2D_ANIMATION_SET) then
        return "2D Animation Set";
    else
        return "";
	end
end

BrowserDir = {id=0,resourceKey='',name='',children={},files={}}
function BrowserDir:new(path_)
	self.resourceKey = path_;
	local parent = GetParentPath(path_);
	self.name = path_;
	Replace(self.name, parent, "");
	self.id = browserDirIndex;
	browserDirIndex = browserDirIndex + 1;
	return sampleclass(self);
end

function BrowserDir:opCmp(b)
	return name:opCmp(b.name);
end

function AddFile(name, resourceSourceIndex, sourceType)
	local path = resourceKey .. "/" .. name;
	local file = BrowserFile(path, resourceSourceIndex, sourceType);
	Push(files, file);
	return file;
end

BrowserFile = {id=0, resourceSourceIndex = 0, resourceKey='', name='', fullname='',extension='',fileType=0,
resourceType = 0, sourceType = 0, sortScore = 0, browserFileListRow = {}
}

function BrowserFile:BrowserFile(path_, resourceSourceIndex_, sourceType_)
	self.sourceType = sourceType_;
	self.resourceSourceIndex = resourceSourceIndex_;
	self.resourceKey = path_;
	self.name = GetFileName(path_);
	self.extension = GetExtension(path_);
	self.fullname = GetFileNameAndExtension(path_);
	self.id = browserFileIndex;
	browserFileIndex = browserFileIndex + 1;
end  

function BrowserFile:opCmp(b)
	if (browserSearchSortMode == 1) then
		return fullname.opCmp(b.fullname);
    else
		return sortScore - b.sortScore;
	end 
end

function BrowserFile:GetResourceSource()
	if (sourceType == BROWSER_FILE_SOURCE_RESOURCE_DIR) then
		return cache.resourceDirs[resourceSourceIndex];
    else
		return "Unknown";
	end
end

function BrowserFile:GetFullPath()
	return (cache.resourceDirs[resourceSourceIndex] .. resourceKey);
end

function BrowserFile:GetPath()
	return resourceKey;
end

function BrowserFile:DetermainResourceType()
	self.resourceType = GetResourceType(GetFullPath(), fileType, false);
	local browserFileListRow_ = browserFileListRow:Get();
	if (browserFileListRow_ ~= nil) then
		InitializeBrowserFileListRow(browserFileListRow_, this);
	end

end
    
function BrowserFile:ResourceTypeName()
	return self:ResourceTypeName(self.resourceType);
end

function BrowserFile:FileChanged()
	if (not fileSystem:FileExists(GetFullPath())) then
	else
	end
end

function CreateResourcePreview(path, previewNode)
    resourceBrowserPreview.autoUpdate = false;
    local resourceType = GetResourceType(path); 
    if (resourceType > 0) then
        local file = File:new();
		file:Open(path);

        if (resourceType == RESOURCE_TYPE_MODEL) then
            local model = Model();
            if (model:Load(file)) then
                local staticModel = previewNode:CreateComponent("StaticModel");
                staticModel.model = model;
                return;
			end
        elseif (resourceType == RESOURCE_TYPE_MATERIAL) then
            local material = Material();
            if (material:Load(file)) then
                local staticModel = previewNode:CreateComponent("StaticModel");
                staticModel.model = cache:GetResource("Model", "Models/Sphere.mdl");
                staticModel.material = material;
                return;
			end
        elseif (resourceType == RESOURCE_TYPE_IMAGE) then
            local image = Image();
            if (image:Load(file)) then
                local staticModel = previewNode:CreateComponent("StaticModel");
                staticModel.model = cache:GetResource("Model", "Models/Editor/ImagePlane.mdl");
                local material =  cache:GetResource("Material", "Materials/Editor/TexturedUnlit.xml");
                local texture = Texture2D:new();
                texture.SetData(image, true);
                material.textures[0] = texture;
                staticModel.material = material;
                return;
			end
        elseif (resourceType == RESOURCE_TYPE_PREFAB) then
            if (GetExtension(path) == ".xml") then
                local xmlFile = XMLFile:new();
                if(xmlFile:Load(file)) then
                    if(previewNode:LoadXML(xmlFile.root, true) and (previewNode:GetComponents("StaticModel", true).length > 0 or previewNode:GetComponents("AnimatedModel", true).length > 0)) then
                        return;
                    end
				end
            elseif(previewNode:Load(file, true) and (previewNode:GetComponents("StaticModel", true).length > 0 or previewNode:GetComponents("AnimatedModel", true).length > 0)) then
                return;
			end

			previewNode:RemoveAllChildren();
			previewNode:RemoveAllComponents();
        elseif (resourceType == RESOURCE_TYPE_PARTICLEEFFECT) then
            local particleEffect = ParticleEffect();
            if (particleEffect:Load(file)) then
                local particleEmitter = previewNode:CreateComponent("ParticleEmitter");
                particleEmitter.effect = particleEffect;
                particleEffect.activeTime = 0.0;
				particleEmitter:Reset();
                resourceBrowserPreview.autoUpdate = true;
                return;
			end
		end
	end

    local staticModel = previewNode:CreateComponent("StaticModel");
    staticModel.model = cache:GetResource("Model", "Models/Editor/ImagePlane.mdl");
    local material =  cache:GetResource("Material", "Materials/Editor/TexturedUnlit.xml");
    local texture = Texture2D();
    local noPreviewImage = cache:GetResource("Image", "Textures/Editor/NoPreviewAvailable.png");
    texture.SetData(noPreviewImage, false);
    material.textures[0] = texture;
    staticModel.material = material;
end


function RotateResourceBrowserPreview(eventType, eventData)
    local elemX = eventData["ElementX"]:GetInt();
    local elemY = eventData["ElementY"]:GetInt();
    
    if (resourceBrowserPreview.height > 0 and resourceBrowserPreview.width > 0) then
        local yaw = ((resourceBrowserPreview.height / 2) - elemY) * (90.0 / resourceBrowserPreview.height);
        local pitch = ((resourceBrowserPreview.width / 2) - elemX) * (90.0 / resourceBrowserPreview.width);

        resourcePreviewNode.rotation = resourcePreviewNode.rotation.Slerp(Quaternion(yaw, pitch, 0), 0.1);
        RefreshBrowserPreview();
	end
end

function RefreshBrowserPreview()
    resourceBrowserPreview:QueueUpdate();
end


ResourceType = {id=0, name=''}
function ResourceType:new(id_, name_)
	self.id = id_;
	self.name = name_;
end
    
function ResourceType:opCmp(b)
	return name:opCmp(b.name);
end

