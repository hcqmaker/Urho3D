previewCamera = nil; -- WeakHandle
cameraNode = nil; -- Node
camera = nil; -- Camera

gridNode = nil; -- Node
grid = nil; -- CustomGeometry

viewportUI = nil; -- holds the viewport ui, convienent for clearing and hiding
setViewportCursor = 0; -- used to set cursor in post update
resizingBorder = 0; -- current border that is dragging
viewportMode = VIEWPORT_SINGLE;
viewportBorderOffset = 2; -- used to center borders over viewport seams,  should be half of width
viewportBorderWidth = 4; -- width of a viewport resize border
viewportArea = nil; -- the area where the editor viewport is. if we ever want to have the viewport not take up the whole screen this abstracts that
viewportUIClipBorder = IntRect(27, 60, 0, 0); -- used to clip viewport borders, the borders are ugly when going behind the transparent toolbars
renderPath = ''; -- Renderpath to use on all views
renderPathName = '';
mouseWheelCameraPosition = false;
contextMenuActionWaitFrame = false;


VIEWPORT_BORDER_H     = 0x00000001;
VIEWPORT_BORDER_H1    = 0x00000002;
VIEWPORT_BORDER_H2    = 0x00000004;
VIEWPORT_BORDER_V     = 0x00000010;
VIEWPORT_BORDER_V1    = 0x00000020;
VIEWPORT_BORDER_V2    = 0x00000040;

VIEWPORT_SINGLE       = 0x00000000;
VIEWPORT_TOP          = 0x00000100;
VIEWPORT_BOTTOM       = 0x00000200;
VIEWPORT_LEFT         = 0x00000400;
VIEWPORT_RIGHT        = 0x00000800;
VIEWPORT_TOP_LEFT     = 0x00001000;
VIEWPORT_TOP_RIGHT    = 0x00002000;
VIEWPORT_BOTTOM_LEFT  = 0x00004000;
VIEWPORT_BOTTOM_RIGHT = 0x00008000;

-- Combinations for easier testing
VIEWPORT_BORDER_H_ANY = 0x00000007;
VIEWPORT_BORDER_V_ANY = 0x00000070;
VIEWPORT_SPLIT_H      = 0x0000f300;
VIEWPORT_SPLIT_V      = 0x0000fc00;
VIEWPORT_SPLIT_HV     = 0x0000f000;
VIEWPORT_TOP_ANY      = 0x00003300;
VIEWPORT_BOTTOM_ANY   = 0x0000c200;
VIEWPORT_LEFT_ANY     = 0x00005400;
VIEWPORT_RIGHT_ANY    = 0x0000c800;
VIEWPORT_QUAD         = 0x0000f000;

EditMode = 
{
    EDIT_MOVE = 0,
    EDIT_ROTATE = 1,
    EDIT_SCALE = 2,
    EDIT_SELECT = 3,
    EDIT_SPAWN = 4
}

AxisMode = 
{
    AXIS_WORLD = 0,
    AXIS_LOCAL = 1
}

SnapScaleMode = 
{
    SNAP_SCALE_FULL = 0,
    SNAP_SCALE_HALF = 1,
    SNAP_SCALE_QUARTER = 2
}


ViewportContext = {}
function ViewportContext.new(viewRect, index_, viewportId_)
    local self = simpleclass(ViewportContext);
	self.cameraYaw = 0;
    self.cameraPitch = 0;
    self.cameraNode = Node();
    self.camera = self.cameraNode:CreateComponent("Camera");
    self.camera.fillMode = fillMode;
    
    self.soundListener = self.cameraNode:CreateComponent("SoundListener");
    self.viewport = Viewport(editorScene, self.camera, viewRect, renderPath);
    self.camera.viewMask = 0xffffffff; -- It's easier to only have 1 gizmo active this viewport is shared with the gizmo
    self.enabled = false;
    self.index = index_;
    self.viewportId = viewportId_;
    self.viewportContextUI = nil;
    self.statusBar = nil;
    self.cameraPosText = nil;

    self.settingsWindow = nil;
    self.cameraPosX = 0;
    self.cameraPosY = 0;
    self.cameraPosZ = 0;
    self.cameraRotX = 0;
    self.cameraRotY = 0;
    self.cameraRotZ = 0;
    self.cameraZoom = 0;
    self.cameraOrthoSize = nil;
    self.cameraOrthographic = nil;
	return self;
end

function ViewportContext:ResetCamera()
    self.cameraNode.position = Vector3(0, 5, -10);
    -- Look at the origin so user can see the scene.
    self.cameraNode.rotation = Quaternion(Vector3(0, 0, 1), -self.cameraNode.position);
    ReacquireCameraYawPitch();
    self:UpdateSettingsUI();
end

function ViewportContext:ReacquireCameraYawPitch()
    self.cameraYaw = self.cameraNode.rotation.yaw;
    self.cameraPitch = self.cameraNode.rotation.pitch;
end

function ViewportContext:CreateViewportContextUI()
    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf");

    self.viewportContextUI = UIElement();
    self.viewportUI:AddChild(self.viewportContextUI);
    self.viewportContextUI:SetPosition(self.viewport.rect.left, self.viewport.rect.top);
    self.viewportContextUI:SetFixedSize(self.viewport.rect.width, self.viewport.rect.height);
    self.viewportContextUI.clipChildren = true;

    self.statusBar = BorderImage("ToolBar");
    self.statusBar.style = "EditorToolBar";
    self.viewportContextUI:AddChild(self.statusBar);

    self.statusBar:SetLayout(LM_HORIZONTAL);
    self.statusBar:SetAlignment(HA_LEFT, VA_BOTTOM);
    self.statusBar.layoutSpacing = 4;
    self.statusBar.opacity = uiMaxOpacity;

    local settingsButton = CreateSmallToolBarButton("Settings");
    self.statusBar:AddChild(settingsButton);

    self.cameraPosText = Text();
    self.statusBar:AddChild(self.cameraPosText);

    self.cameraPosText:SetFont(font, 11);
    self.cameraPosText.color = Color(1, 1, 0);
    self.cameraPosText.textEffect = TE_SHADOW;
    self.cameraPosText.priority = -100;

    self.settingsWindow = LoadEditorUI("UI/EditorViewport.xml");
    self.settingsWindow.opacity = uiMaxOpacity;
    self.settingsWindow.visible = false;
    self.viewportContextUI:AddChild(self.settingsWindow);

    self.cameraPosX = self.settingsWindow:GetChild("PositionX", true);
    self.cameraPosY = self.settingsWindow:GetChild("PositionY", true);
    self.cameraPosZ = self.settingsWindow:GetChild("PositionZ", true);
    self.cameraRotX = self.settingsWindow:GetChild("RotationX", true);
    self.cameraRotY = self.settingsWindow:GetChild("RotationY", true);
    self.cameraRotZ = self.settingsWindow:GetChild("RotationZ", true);
    self.cameraOrthographic = self.settingsWindow:GetChild("Orthographic", true);
    self.cameraZoom = self.settingsWindow:GetChild("Zoom", true);
    self.cameraOrthoSize = self.settingsWindow:GetChild("OrthoSize", true);

    SubscribeToEvent(self.cameraPosX, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraPosY, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraPosZ, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraRotX, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraRotY, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraRotZ, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraZoom, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraOrthoSize, "TextChanged", "HandleSettingsLineEditTextChange");
    SubscribeToEvent(self.cameraOrthographic, "Toggled", "HandleOrthographicToggled");

    SubscribeToEvent(settingsButton, "Released", "ToggleViewportSettingsWindow");
    SubscribeToEvent(self.settingsWindow:GetChild("ResetCamera", true), "Released", "ResetCamera");
    SubscribeToEvent(self.settingsWindow:GetChild("CopyTransform", true), "Released", "HandleCopyTransformClicked");
    SubscribeToEvent(self.settingsWindow:GetChild("CloseButton", true), "Released", "CloseViewportSettingsWindow");
    SubscribeToEvent(self.settingsWindow:GetChild("Refresh", true), "Released", "UpdateSettingsUI");
    HandleResize();
end

function ViewportContext:HandleResize()
    self.viewportContextUI:SetPosition(self.viewport.rect.left, self.viewport.rect.top);
    self.viewportContextUI:SetFixedSize(self.viewport.rect.width, self.viewport.rect.height);
    if (self.viewport.rect.left < 34) then
        self.statusBar.layoutBorder = IntRect(34 - self.viewport.rect.left, 4, 4, 8);
        local pos = settingsWindow.position;
        pos.x = 32 - self.viewport.rect.left;
        self.settingsWindow.position = pos;
    else
        self.statusBar.layoutBorder = IntRect(8, 4, 4, 8);
        local pos = self.settingsWindow.position;
        pos.x = 5;
        self.settingsWindow.position = pos;
    end

    self.statusBar:SetFixedSize(self.viewport.rect.width, 22);
end

function ViewportContext:ToggleOrthographic()
    SetOrthographic(not self.camera.orthographic);
end

function ViewportContext:SetOrthographic(orthographic)
    self.camera.orthographic = orthographic;
    self:UpdateSettingsUI();
end

function ViewportContext:Update(timeStep)
    local cameraPos = self.cameraNode.position;
    local xText = "" .. cameraPos.x;
    local yText = "" .. cameraPos.y;
    local zText = "" .. cameraPos.z;
    Resize(xText, 8);
    Resize(yText, 8);
    Resize(zText, 8);

    self.cameraPosText.text = "Pos: " .. xText .. " " .. yText .. " " .. zText .. " Zoom: " .. camera.zoom;
    self.cameraPosText.size = self.cameraPosText.minSize;
end


function ViewportContext:ToggleViewportSettingsWindow()
    if (self.settingsWindow.visible) then
        CloseViewportSettingsWindow();
    else
        OpenViewportSettingsWindow();
    end
end

function ViewportContext:OpenViewportSettingsWindow()
    self:UpdateSettingsUI();
    -- settingsWindow.position =
    self.settingsWindow.visible = true;
    self.settingsWindow.BringToFront();
end

function ViewportContext:CloseViewportSettingsWindow()
    self.settingsWindow.visible = false;
end

function ViewportContext:UpdateSettingsUI()
    self.cameraPosX.text = "" .. math.floor(self.cameraNode.position.x * 1000) / 1000;
    self.cameraPosY.text = "" .. math.floor(self.cameraNode.position.y * 1000) / 1000;
    self.cameraPosZ.text = "" .. math.floor(self.cameraNode.position.z * 1000) / 1000;
    self.cameraRotX.text = "" .. math.floor(self.cameraNode.rotation.pitch * 1000) / 1000;
    self.cameraRotY.text = "" .. math.floor(self.cameraNode.rotation.yaw * 1000) / 1000;
    self.cameraRotZ.text = "" .. math.floor(self.cameraNode.rotation.roll * 1000) / 1000;
    self.cameraZoom.text = "" .. math.floor(self.camera.zoom * 1000) / 1000;
    self.cameraOrthoSize.text = "" .. math.floor(self.camera.orthoSize * 1000) / 1000;
    self.cameraOrthographic.checked = self.camera.orthographic;
end

function ViewportContext:HandleOrthographicToggled(eventType, eventData)
    SetOrthographic(cameraOrthographic.checked);
end

function ViewportContext:HandleSettingsLineEditTextChange(eventType, eventData)

    local element = eventData["Element"]:GetPtr();
    if (element.text == "") then
        return;
    end

    if (element == self.cameraRotX or  element == self.cameraRotY or element == self.cameraRotZ) then
    
        local euler = self.cameraNode.rotation.eulerAngles;
        if (element == self.cameraRotX) then
            euler.x = ToFloat(element.text);
        elseif (element == self.cameraRotY) then
            euler.y = ToFloat(element.text);
        elseif (element == self.cameraRotZ) then
            euler.z = ToFloat(element.text);
        end
        self.cameraNode.rotation = Quaternion(euler);
    elseif (element == cameraPosX or  element == cameraPosY or element == cameraPosZ) then
    
        local pos = self.cameraNode.position;
        if (element == self.cameraPosX) then
            pos.x = ToFloat(element.text);
        elseif (element == self.cameraPosY) then
            pos.y = ToFloat(element.text);
        elseif (element == self.cameraPosZ) then
            pos.z = ToFloat(element.text);
        end
        self.cameraNode.position = pos;
    elseif (element == self.cameraZoom) then
        self.camera.zoom = element.text.ToFloat();
    elseif (element == self.cameraOrthoSize) then
        self.camera.orthoSize = element.text.ToFloat();
    end
end
function ViewportContext:HandleCopyTransformClicked(eventType, eventData)

    if (self.editNode ~= nil) then
        self.editNode.position = self.cameraNode.position;
        self.editNode.rotation = self.cameraNode.rotation;
    end
end

viewports = {} -- Array<ViewportContext@> 
activeViewport = nil; -- ViewportContext


editorModeText = nil;
renderStatsText = nil;

editMode = EDIT_MOVE;
axisMode = AXIS_WORLD;
fillMode = FILL_SOLID;
snapScaleMode = SNAP_SCALE_FULL;

viewNearClip = 0.1;
viewFarClip = 1000.0;
viewFov = 45.0;

cameraBaseSpeed = 10;
cameraBaseRotationSpeed = 0.2;
cameraShiftSpeedMultiplier = 5;
newNodeDistance = 20;
moveStep = 0.5;
rotateStep = 5;
scaleStep = 0.1;
snapScale = 1.0;
limitRotation = false;
moveSnap = false;
rotateSnap = false;
scaleSnap = false;
renderingDebug = false;
physicsDebug = false;
octreeDebug = false;
pickMode = PICK_GEOMETRIES;
orbiting = false;

MouseOrbitMode = 
{
    ORBIT_RELATIVE = 0,
    ORBIT_WRAP = 1
}



toggledMouseLock = false;
mouseOrbitMode = ORBIT_RELATIVE;

showGrid = true;
grid2DMode = false;
gridSize = 16;
gridSubdivisions = 3;
gridScale = 8.0;
gridColor = Color(0.1, 0.1, 0.1);
gridSubdivisionColor = Color(0.05, 0.05, 0.05);
gridXColor = Color(0.5, 0.1, 0.1);
gridYColor = Color(0.1, 0.5, 0.1);
gridZColor = Color(0.1, 0.1, 0.5);

pickModeDrawableFlags = {
    DRAWABLE_GEOMETRY,
    DRAWABLE_LIGHT,
    DRAWABLE_ZONE
};

editModeText = {
    "Move",
    "Rotate",
    "Scale",
    "Select",
    "Spawn"
};

axisModeText = {
    "World",
    "Local"
};

pickModeText = {
    "Geometries",
    "Lights",
    "Zones",
    "Rigidbodies",
    "UI-elements"
};

fillModeText = {
    "Solid",
    "Wire",
    "Point"
};


function SetRenderPath(newRenderPathName)
    renderPath = nil;
    renderPathName = Trimmed(newRenderPathName);

    if (string.len(renderPathName) > 0) then
        local file = cache:GetFile(renderPathName);
        if (file ~= nil) then
            local xml = XMLFile:new();
            if (xml:Load(file)) then
                renderPath = RenderPath();
                if (not renderPath:Load(xml)) then
                    renderPath = nil;
                end
            end
        end
    end
    
    -- If renderPath == nil, the engine default will be used
    for i = 0, renderer.numViewports - 1 do
        renderer.viewports[i].renderPath = renderPath;
    end

    if (materialPreview ~= nil and materialPreview.viewport ~= nil) then
        materialPreview.viewport.renderPath = renderPath;
    end
end

function CreateCamera()

    -- Set the initial viewport rect
    viewportArea = IntRect:new(0, 0, graphics.width, graphics.height);
    print("-------------CreateCamera----->---->",viewportMode);
    SetViewportMode(viewportMode);
    print("-------------CreateCamera----->---->1xxx");
    SetActiveViewport(viewports[0]);
print("-------------CreateCamera----->---->1");
    -- Note: the camera is not inside the scene, so that it is not listed, and does not get deleted
    ResetCamera();
print("-------------CreateCamera----->---->2");
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate");
    SubscribeToEvent("UIMouseClick", "ViewMouseClick");
    SubscribeToEvent("MouseMove", "ViewMouseMove");
    SubscribeToEvent("UIMouseClickEnd", "ViewMouseClickEnd");
    SubscribeToEvent("BeginViewUpdate", "HandleBeginViewUpdate");
    SubscribeToEvent("EndViewUpdate", "HandleEndViewUpdate");
    SubscribeToEvent("BeginViewRender", "HandleBeginViewRender");
    SubscribeToEvent("EndViewRender", "HandleEndViewRender");
print("-------------CreateCamera----->---->3");
    -- Set initial renderpath if defined
    SetRenderPath(renderPathName);
end


--  Create any UI associated with changing the editor viewports
function CreateViewportUI()
    if (viewportUI ~= nil) then
        viewportUI = UIElement:new();
        ui.root:AddChild(viewportUI);
    end

    viewportUI:SetFixedSize(viewportArea.width, viewportArea.height);
    viewportUI.position = IntVector2(viewportArea.top, viewportArea.left);
    viewportUI.clipChildren = true;
    viewportUI.clipBorder = viewportUIClipBorder;
    viewportUI:RemoveAllChildren();
    viewportUI.priority = -2000;

    local borders = {};
    --Array<BorderImage@> borders;

    local top;
    local bottom;
    local left;
    local right;
    local topLeft;
    local topRight;
    local bottomLeft;
    local bottomRight;

    for i = 1, #viewports do
        local vc = viewports[i];
        vc:CreateViewportContextUI();

        if (bitand2(vc.viewportId, VIEWPORT_TOP) > 0) then
            top = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM) > 0) then
            bottom = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_LEFT) > 0) then
            left = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_RIGHT) > 0) then
            right = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_TOP_LEFT) > 0) then
            topLeft = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_TOP_RIGHT) > 0) then
            topRight = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_LEFT) > 0) then
            bottomLeft = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_RIGHT) > 0) then
            bottomRight = vc.viewport.rect;
        end
    end

    --  Creates resize borders based on the mode set
    if (viewportMode == VIEWPORT_QUAD) then --  independent borders for quad isn't easy
        Push(borders, CreateViewportDragBorder(VIEWPORT_BORDER_V, topLeft.right - viewportBorderOffset, topLeft.top, viewportBorderWidth, viewportArea.height));
        Push(borders, CreateViewportDragBorder(VIEWPORT_BORDER_H, topLeft.left, topLeft.bottom-viewportBorderOffset, viewportArea.width, viewportBorderWidth));
    else
        --  Figures what borders to create based on mode
        if (bitor2(viewportMode, bitor2(VIEWPORT_LEFT,VIEWPORT_RIGHT)) > 0) then
            Push(borders,
                ifor(bitand2(viewportMode, VIEWPORT_LEFT) > 0,
                    CreateViewportDragBorder(VIEWPORT_BORDER_V, left.right-viewportBorderOffset, left.top, viewportBorderWidth, left.height),
                    CreateViewportDragBorder(VIEWPORT_BORDER_V, right.left-viewportBorderOffset, right.top, viewportBorderWidth, right.height))
                );
        else
            if (bitand2(viewportMode, bitor2(VIEWPORT_TOP_LEFT,VIEWPORT_TOP_RIGHT)) > 0) then
                Push(borders, CreateViewportDragBorder(VIEWPORT_BORDER_V1, topLeft.right-viewportBorderOffset, topLeft.top, viewportBorderWidth, topLeft.height));
            end
            if (bitand2(viewportMode, bitor2(VIEWPORT_BOTTOM_LEFT,VIEWPORT_BOTTOM_RIGHT)) > 0) then
                Push(borders, CreateViewportDragBorder(VIEWPORT_BORDER_V2, bottomLeft.right-viewportBorderOffset, bottomLeft.top, viewportBorderWidth, bottomLeft.height));
            end
        end

        if (bitand2(viewportMode, bitor2(VIEWPORT_TOP,VIEWPORT_BOTTOM)) > 0) then
            Push(borders,
                ifor(bitand2(viewportMode, VIEWPORT_TOP) > 0,
                    CreateViewportDragBorder(VIEWPORT_BORDER_H, top.left, top.bottom-viewportBorderOffset, top.width, viewportBorderWidth),
                    CreateViewportDragBorder(VIEWPORT_BORDER_H, bottom.left, bottom.top-viewportBorderOffset, bottom.width, viewportBorderWidth)
                ));
        else
            if (bitand2(viewportMode, bitor2(VIEWPORT_TOP_LEFT,VIEWPORT_BOTTOM_LEFT)) > 0) then
                Push(borders,CreateViewportDragBorder(VIEWPORT_BORDER_H1, topLeft.left, topLeft.bottom-viewportBorderOffset, topLeft.width, viewportBorderWidth));
            end
            if (bitand2(viewportMode, bitor2(VIEWPORT_TOP_RIGHT,VIEWPORT_BOTTOM_RIGHT)) > 0) then
                Push(borders,CreateViewportDragBorder(VIEWPORT_BORDER_H2, topRight.left, topRight.bottom-viewportBorderOffset, topRight.width, viewportBorderWidth));
            end
        end
    end
end



function CreateViewportDragBorder(value, posX, posY, sizeX, sizeY)
    local border = BorderImage:new();
    viewportUI:AddChild(border);
    border.name = "border";
    border.style = "ViewportBorder";
    border:SetVar("VIEWMODE", Variant(value));
    border:SetFixedSize(sizeX, sizeY); -- relevant size gets set by viewport later
    border.position = IntVector2(posX, posY);
    border.opacity = uiMaxOpacity;
    SubscribeToEvent(border, "DragMove", "HandleViewportBorderDragMove");
    SubscribeToEvent(border, "DragEnd", "HandleViewportBorderDragEnd");
    return border;
end

function SetFillMode(fillMode_)
    fillMode = fillMode_;
    for i = 1,#viewports do
        viewports[i].camera.fillMode = fillMode_;
    end
end


-- Sets the viewport mode
function SetViewportMode(mode)
	if (mode == nil) then
		mode = VIEWPORT_SINGLE;
	end
    -- Remember old viewport positions
    local cameraPositions = {};
    local cameraRotations = {};
    for i = 1, #viewports do
        Push(cameraPositions, viewports[i].cameraNode.position);
        Push(cameraRotations, viewports[i].cameraNode.rotation);
    end

    viewports = {};
    viewportMode = mode;

    -- Always have quad a
    
        local viewport = 0;
        local vc = ViewportContext.new(
            IntRect(
                0,
                0,
                ifor(bitand2(mode, bitor2(VIEWPORT_LEFT,VIEWPORT_TOP_LEFT)) > 0, viewportArea.width / 2 , viewportArea.width),
                ifor(bitand2(mode, bitor2(VIEWPORT_TOP,VIEWPORT_TOP_LEFT)) > 0 , viewportArea.height / 2 , viewportArea.height)),
            #viewports + 1,
            bitand2(viewportMode, bitor3(VIEWPORT_TOP,VIEWPORT_LEFT, VIEWPORT_TOP_LEFT))
        );
        Push(viewports,vc);
    

    local topRight = bitand2(viewportMode, bitor2(VIEWPORT_RIGHT,VIEWPORT_TOP_RIGHT));
    if (topRight > 0) then
        local vc = ViewportContext.new(
            IntRect(
                viewportArea.width/2,
                0,
                viewportArea.width,
                ifor(bitand2(mode, VIEWPORT_TOP_RIGHT) > 0, viewportArea.height / 2, viewportArea.height)),
            #viewports + 1,
            topRight
        );
        Push(viewports,vc);
    end

    local bottomLeft = bitand2(viewportMode, bitor2(VIEWPORT_BOTTOM,VIEWPORT_BOTTOM_LEFT));
    if (bottomLeft > 0) then
        local vc = ViewportContext.new(
            IntRect(
                0,
                viewportArea.height / 2,
                ifor(bitand2(mode, (VIEWPORT_BOTTOM_LEFT)) > 0, viewportArea.width / 2, viewportArea.width),
                viewportArea.height),
            viewports.length + 1,
            bottomLeft
        );
        Push(viewports,vc);
    end

    local bottomRight = bitand2(viewportMode, (VIEWPORT_BOTTOM_RIGHT));
    if (bottomRight > 0) then
        local vc = ViewportContext.new(
            IntRect(
                viewportArea.width / 2,
                viewportArea.height / 2,
                viewportArea.width,
                viewportArea.height),
            #viewports + 1,
            bottomRight
        );
        Push(viewports,vc);
    end

    renderer:SetNumViewports(#viewports);
    for i = 1, #viewports do
        renderer:SetViewport(i - 1, viewports[i].viewport);
    end

    -- Restore camera positions as applicable. Default new viewports to the last camera position
    if (#cameraPositions > 0) then
    	for i = 1, #viewports do
            local src = i;
            if (src >= #cameraPositions) then
                src = #cameraPositions - 1;
            end
            viewports[i].cameraNode.position = cameraPositions[src];
            viewports[i].cameraNode.rotation = cameraRotations[src];
        end
    end

    ReacquireCameraYawPitch();
    UpdateViewParameters();
    UpdateCameraPreview();
    CreateViewportUI();
end


-- Create a preview viewport if a camera component is selected
function UpdateCameraPreview()
    previewCamera = nil;
    local cameraType = StringHash("Camera");
    for i = 1, #selectedComponents do
        print("====>type:", selectedComponents[i].type)
        if (selectedComponents[i].type == cameraType) then
            -- Take the first encountered camera
            previewCamera = selectedComponents[i];
            break;
        end
    end
    -- Also try nodes if not found from components
    if (previewCamera:Get() == nil) then
    	for i = 1, #selectedNodes do
            previewCamera = selectedNodes[i]:GetComponent("Camera");
            if (previewCamera:Get() ~= nil) then
                break;
            end
        end
    end

    -- Remove extra viewport if it exists and no camera is selected
    if (previewCamera.Get() == nil) then
        if (renderer.numViewports > #viewports) then
            renderer.numViewports = #viewports;
       	end
    else
        if (renderer.numViewports < #viewports + 1) then
            renderer.numViewports = #viewports + 1;
        end

        local previewWidth = graphics.width / 4;
        local previewHeight = previewWidth * 9 / 16;
        local previewX = graphics.width - 10 - previewWidth;
        local previewY = graphics.height - 30 - previewHeight;

        local previewView = Viewport:new();
        previewView.scene = editorScene;
        previewView.camera = previewCamera:Get();
        previewView.rect = IntRect(previewX, previewY, previewX + previewWidth, previewY + previewHeight);
        previewView.renderPath = renderPath;
        renderer.viewports[viewports.length] = previewView;
    end
end


function HandleViewportBorderDragMove(eventType, eventData)
    local dragBorder = eventData["Element"]:GetPtr();
    if (dragBorder == nil) then
        return;
    end

    local hPos;
    local vPos;

    -- Moves border to new cursor position, restricts motion to 1 axis, and keeps borders within view area
    if (bitand2(resizingBorder, VIEWPORT_BORDER_V_ANY) > 0) then
        hPos = Clamp(ui.cursorPosition.x, 150, viewportArea.width-150);
        vPos = dragBorder.position.y;
        dragBorder.position = IntVector2(hPos, vPos);
    end
    if (bitand2(resizingBorder, VIEWPORT_BORDER_H_ANY) > 0) then
        vPos = Clamp(ui.cursorPosition.y, 150, viewportArea.height-150);
        hPos = dragBorder.position.x;
        dragBorder.position = IntVector2(hPos, vPos);
    end

    -- Move all dependent borders
    local borders = viewportUI:GetChildren();
    for i = 1, #borders do
        local border = borders[i];
        if (border ~= nil or border == dragBorder or border.name ~= "border") then
        else
	        local borderViewMode = border.vars:GetUInt("VIEWMODE");
	        if (resizingBorder == VIEWPORT_BORDER_H) then
	            if (borderViewMode == VIEWPORT_BORDER_V1) then
	                border:SetFixedHeight(vPos);
	            elseif (borderViewMode == VIEWPORT_BORDER_V2) then
	                border.position = IntVector2(border.position.x, vPos);
	                border:SetFixedHeight(viewportArea.height - vPos);
	            end
	        elseif (resizingBorder == VIEWPORT_BORDER_V) then
	            if (borderViewMode == VIEWPORT_BORDER_H1) then
	                border:SetFixedWidth(hPos);
	            elseif (borderViewMode == VIEWPORT_BORDER_H2) then
	                border.position = IntVector2(hPos, border.position.y);
	                border:SetFixedWidth(viewportArea.width - hPos);
	            end
	        end
	    end
    end
end

function HandleViewportBorderDragEnd(eventType, eventData)
    -- Sets the new viewports by checking all the dependencies
    local children = viewportUI:GetChildren();
    local borders = {};

    local borderV;
    local borderV1;
    local borderV2;
    local borderH;
    local borderH1;
    local borderH2;

    for i = 1, #children do
        if (children[i].name == "border") then
            local border = children[i];
            local mode = border.vars:GetUInt("VIEWMODE");
            if (mode == VIEWPORT_BORDER_V) then
                borderV = border;
            elseif (mode == VIEWPORT_BORDER_V1) then
                borderV1 = border;
            elseif (mode == VIEWPORT_BORDER_V2) then
                borderV2 = border;
            elseif (mode == VIEWPORT_BORDER_H) then
                borderH = border;
            elseif (mode == VIEWPORT_BORDER_H1) then
                borderH1 = border;
            elseif (mode == VIEWPORT_BORDER_H2) then
                borderH2 = border;
            end
        end
    end

    local top;
    local bottom;
    local left;
    local right;
    local topLeft;
    local topRight;
    local bottomLeft;
    local bottomRight;

    for i = 1, #viewports do
        local vc = viewports[i];
        if (bitand2(vc.viewportId, VIEWPORT_TOP) > 0) then
            top = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM) > 0) then
            bottom = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_LEFT) > 0) then
            left = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_RIGHT) > 0) then
            right = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_TOP_LEFT) > 0) then
            topLeft = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_TOP_RIGHT) > 0) then
            topRight = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_LEFT) > 0) then
            bottomLeft = vc.viewport.rect;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_RIGHT) > 0) then
            bottomRight = vc.viewport.rect;
        end
    end

    if (borderV ~= nil) then
        if (bitand2(viewportMode, VIEWPORT_LEFT) > 0) then
            left.right = borderV.position.x + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_TOP_LEFT) > 0) then
            topLeft.right = borderV.position.x + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_TOP_RIGHT) > 0) then
            topRight.left = borderV.position.x + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_RIGHT) > 0) then
            right.left = borderV.position.x + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_BOTTOM_LEFT) > 0) then
            bottomLeft.right = borderV.position.x + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_BOTTOM_RIGHT) > 0) then
            bottomRight.left = borderV.position.x + viewportBorderOffset;
        end
    else
        if (borderV1 ~= nil) then
            if (bitand2(viewportMode, VIEWPORT_TOP_LEFT) > 0) then
                topLeft.right = borderV1.position.x + viewportBorderOffset;
            end
            if (bitand2(viewportMode, VIEWPORT_TOP_RIGHT) > 0) then
                topRight.left = borderV1.position.x + viewportBorderOffset;
            end
        end
        if (borderV2 ~= nil) then
            if (bitand2(viewportMode, VIEWPORT_BOTTOM_LEFT) > 0) then
                bottomLeft.right = borderV2.position.x + viewportBorderOffset;
            end
            if (bitand2(viewportMode, VIEWPORT_BOTTOM_RIGHT) > 0) then
                bottomRight.left = borderV2.position.x + viewportBorderOffset;
            end
        end
    end

    if (borderH ~= nil) then
        if (bitand2(viewportMode, VIEWPORT_TOP) > 0) then
            top.bottom = borderH.position.y + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_TOP_LEFT) > 0) then
            topLeft.bottom = borderH.position.y + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_BOTTOM_LEFT) > 0) then
            bottomLeft.top = borderH.position.y + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_BOTTOM) > 0) then
            bottom.top = borderH.position.y + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_TOP_RIGHT) > 0) then
            topRight.bottom = borderH.position.y + viewportBorderOffset;
        end
        if (bitand2(viewportMode, VIEWPORT_BOTTOM_RIGHT) > 0) then
            bottomRight.top = borderH.position.y + viewportBorderOffset;
        end
    else
        if (borderH1 ~= nil) then
            if (bitand2(viewportMode, VIEWPORT_TOP_LEFT) > 0) then
                topLeft.bottom = borderH1.position.y+viewportBorderOffset;
            end
            if (bitand2(viewportMode, VIEWPORT_BOTTOM_LEFT) > 0) then
                bottomLeft.top = borderH1.position.y+viewportBorderOffset;
            end
        end
        if (borderH2 ~= nil) then
            if (bitand2(viewportMode, VIEWPORT_TOP_RIGHT) > 0) then
                topRight.bottom = borderH2.position.y+viewportBorderOffset;
            end
            if (bitand2(viewportMode, VIEWPORT_BOTTOM_RIGHT) > 0) then
                bottomRight.top = borderH2.position.y+viewportBorderOffset;
            end
        end
    end

    -- Applies the calculated changes
    for i = 1, #viewports do
        local vc = viewports[i];
        if (bitand2(vc.viewportId, VIEWPORT_TOP) > 0) then
            vc.viewport.rect = top;
        elseif (bitand2(vc.viewportId , VIEWPORT_BOTTOM) > 0) then
            vc.viewport.rect = bottom;
        elseif (bitand2(vc.viewportId , VIEWPORT_LEFT) > 0) then
            vc.viewport.rect = left;
        elseif (bitand2(vc.viewportId , VIEWPORT_RIGHT) > 0) then
            vc.viewport.rect = right;
        elseif (bitand2(vc.viewportId , VIEWPORT_TOP_LEFT) > 0) then
            vc.viewport.rect = topLeft;
        elseif (bitand2(vc.viewportId, VIEWPORT_TOP_RIGHT) > 0) then
            vc.viewport.rect = topRight;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_LEFT) > 0) then
            vc.viewport.rect = bottomLeft;
        elseif (bitand2(vc.viewportId, VIEWPORT_BOTTOM_RIGHT) > 0) then
            vc.viewport.rect = bottomRight;
        end
        vc:HandleResize();
    end

    -- End drag state
    resizingBorder = 0;
    setViewportCursor = 0;
end

function SetViewportCursor()
    if (bitand2(setViewportCursor , VIEWPORT_BORDER_V_ANY) > 0) then
        ui.cursor.shape = CS_RESIZEHORIZONTAL;
    elseif (bitand2(setViewportCursor , VIEWPORT_BORDER_H_ANY) > 0) then
        ui.cursor.shape = CS_RESIZEVERTICAL;
    end
end

function SetActiveViewport(context)

    -- Sets the global variables to the current context
    cameraNode = context.cameraNode;
    camera = context.camera;
    audio.listener = context.soundListener;

    -- Camera is created before gizmo, this gets called again after UI is created
    if (gizmo ~= nil) then
        gizmo.viewMask = camera.viewMask;
    end
    activeViewport = context;

    -- If a mode is changed while in a drag or hovering over a border these can get out of sync
    resizingBorder = 0;
    setViewportCursor = 0;
end

function ResetCamera()
	for i = 1, #viewports do
        viewports[i]:ResetCamera();
    end
end

function ReacquireCameraYawPitch()
	for i = 1, #viewports do
        viewports[i]:ReacquireCameraYawPitch();
    end
end

function UpdateViewParameters()
    for i = 1, #viewports do
        viewports[i].camera.nearClip = viewNearClip;
        viewports[i].camera.farClip = viewFarClip;
        viewports[i].camera.fov = viewFov;
	end    
end

function CreateGrid()
    if (gridNode ~= nil) then
        gridNode.Remove();
    end

    gridNode = Node:new();
    grid = gridNodeLCreateComponent("CustomGeometry");
    grid.numGeometries = 1;
    grid.material = cache:GetResource("Material", "Materials/VColUnlit.xml");
    grid.viewMask = 0x80000000; -- Editor raycasts use viewmask 0x7fffffff
    grid.occludee = false;

    UpdateGrid();
end

function HideGrid()
    if (grid ~= nil) then
        grid.enabled = false;
    end
end

function ShowGrid()
    if (grid ~= nil) then
        grid.enabled = true;

        if (editorScene.octree ~= nil) then
            editorScene.octree:AddManualDrawable(grid);
        end
    end
end

function UpdateGrid(updateGridGeometry)
	if (updateGridGeometry == nil) then
		updateGridGeometry = true;
	end
	if (showGrid) then
		showGrid();
	else
		HideGrid();
	end

    gridNode.scale = Vector3(gridScale, gridScale, gridScale);

    if (not updateGridGeometry) then
        return;
    end

    local size = math.floor(gridSize / 2) * 2;
    local halfSizeScaled = size / 2;
    local scale = 1.0;
    local subdivisionSize = math.pow(2.0, tonumber(gridSubdivisions));

    if (subdivisionSize > 0) then
        size = size * subdivisionSize;
        scale = scale / subdivisionSize;
    end

    local halfSize = math.floor(size / 2);

    grid:BeginGeometry(0, LINE_LIST);
    local lineOffset = -halfSizeScaled;
    for i = 1, size do
        local lineCenter = i == halfSize;
        local lineSubdiv = not Equals(Mod(i, subdivisionSize), 0.0);

        if (not grid2DMode) then
            grid:DefineVertex(Vector3(lineOffset, 0.0, halfSizeScaled));
            grid:DefineColor(ifor(lineCenter, gridZColor, ifor(lineSubdiv, gridSubdivisionColor , gridColor)));
            grid:DefineVertex(Vector3(lineOffset, 0.0, -halfSizeScaled));
            grid:DefineColor(ifor(lineCenter, gridZColor, ifor(lineSubdiv, gridSubdivisionColor, gridColor)));

            grid:DefineVertex(Vector3(-halfSizeScaled, 0.0, lineOffset));
            grid:DefineColor(ifor(lineCenter, gridXColor, ifor(lineSubdiv, gridSubdivisionColor, gridColor)));
            grid:DefineVertex(Vector3(halfSizeScaled, 0.0, lineOffset));
            grid:DefineColor(ifor(lineCenter , gridXColor, ifor(lineSubdiv , gridSubdivisionColor , gridColor)));
        else
            grid:DefineVertex(Vector3(lineOffset, halfSizeScaled, 0.0));
            grid:DefineColor(ifor(lineCenter , gridYColor , ifor(lineSubdiv , gridSubdivisionColor , ridColor)));
            grid:DefineVertex(Vector3(lineOffset, -halfSizeScaled, 0.0));
            grid:DefineColor(ifor(lineCenter , gridYColor , ifor(lineSubdiv , gridSubdivisionColor , gridColor)));

            grid:DefineVertex(Vector3(-halfSizeScaled, lineOffset, 0.0));
            grid:DefineColor(ifor(lineCenter , gridXColor , ifor(lineSubdiv , gridSubdivisionColor , gridColor)));
            grid:DefineVertex(Vector3(halfSizeScaled, lineOffset, 0.0));
            grid:DefineColor(ifor(lineCenter , gridXColor , ifor(lineSubdiv , gridSubdivisionColor , gridColor)));
        end

        lineOffset = lineOffset + scale;
	end
    grid:Commit();
end


function CreateStatsBar()

    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf");

    editorModeText = Text:new();
    ui.root:AddChild(editorModeText);
    renderStatsText = Text:new();
    ui.root:AddChild(renderStatsText);

    if (ui.root.width >= 1200) then
        SetupStatsBarText(editorModeText, font, 35, 64, HA_LEFT, VA_TOP);
        SetupStatsBarText(renderStatsText, font, -4, 64, HA_RIGHT, VA_TOP);
    else
        SetupStatsBarText(editorModeText, font, 35, 64, HA_LEFT, VA_TOP);
        SetupStatsBarText(renderStatsText, font, 35, 78, HA_LEFT, VA_TOP);
	end
end

function SetupStatsBarText(text, font, x, y, hAlign, vAlign)
    text.position = IntVector2(x, y);
    text.horizontalAlignment = hAlign;
    text.verticalAlignment = vAlign;
    text.SetFont(font, 11);
    text.color = Color(1, 1, 0);
    text.textEffect = TE_SHADOW;
    text.priority = -100;
end

function UpdateStats(timeStep)
    editorModeText.text = 
        "Mode: " .. editModeText[editMode] .. 
        "  Axis: " .. axisModeText[axisMode].. 
        "  Pick: " .. pickModeText[pickMode].. 
        "  Fill: " .. fillModeText[fillMode].. 
        "  Updates: " .. ifor(runUpdate, "Running" , "Paused");

    renderStatsText.text = 
        "Tris: " .. renderer.numPrimitives ..
        "  Batches: " .. renderer.numBatches ..
        "  Lights: " .. renderer.numLights[true] .. 
        "  Shadowmaps: " .. renderer.numShadowMaps[true] ..
        "  Occluders: " .. renderer.numOccluders[true];

    editorModeText.size = editorModeText.minSize;
    renderStatsText.size = renderStatsText.minSize;
end

function UpdateViewports(timeStep)
	for i = 1, #viewports do
        local viewportContext = viewports[i];
		viewportContext:Update(timeStep);
	end
end

function SetMouseMode(enable)
    if (enable) then
        if (mouseOrbitMode == ORBIT_RELATIVE) then
            input.mouseMode = MM_RELATIVE;
            ui.cursor.visible = false;
        elseif (mouseOrbitMode == ORBIT_WRAP) then
            input.mouseMode = MM_WRAP;
		end
    else
        input.mouseMode = MM_ABSOLUTE;
        ui.cursor.visible = true;
	end
end

function SetMouseLock()
    toggledMouseLock = true;
    SetMouseMode(true);
    FadeUI();
end

function ReleaseMouseLock()
    if (toggledMouseLock) then
        toggledMouseLock = false;
        SetMouseMode(false);
	end
end

function UpdateView(timeStep)
    if (ui.HasModalElement() or ui.focusElement ~= nil) then
        ReleaseMouseLock();
        return;
	end

    -- Move camera
    if (not input.keyDown[KEY_LCTRL]) then
        local speedMultiplier = 1.0;
        if (input.keyDown[KEY_LSHIFT]) then
            speedMultiplier = cameraShiftSpeedMultiplier;
		end

        if (input.keyDown['W'] or input.keyDown[KEY_UP]) then
            cameraNode:Translate(Vector3(0, 0, cameraBaseSpeed) * timeStep * speedMultiplier);
            FadeUI();
		end
        if (input.keyDown['S'] or input.keyDown[KEY_DOWN]) then
            cameraNode:Translate(Vector3(0, 0, -cameraBaseSpeed) * timeStep * speedMultiplier);
            FadeUI();
		end
        if (input.keyDown['A'] or input.keyDown[KEY_LEFT]) then
            cameraNode:Translate(Vector3(-cameraBaseSpeed, 0, 0) * timeStep * speedMultiplier);
            FadeUI();
		end
        if (input.keyDown['D'] or input.keyDown[KEY_RIGHT]) then
            cameraNode:Translate(Vector3(cameraBaseSpeed, 0, 0) * timeStep * speedMultiplier);
            FadeUI();
		end
        if (input.keyDown['E'] or input.keyDown[KEY_PAGEUP]) then
            cameraNode:Translate(Vector3(0, cameraBaseSpeed, 0) * timeStep * speedMultiplier, TS_WORLD);
            FadeUI();
		end
        if (input.keyDown['Q'] or input.keyDown[KEY_PAGEDOWN]) then
            cameraNode:Translate(Vector3(0, -cameraBaseSpeed, 0) * timeStep * speedMultiplier, TS_WORLD);
            FadeUI();
		end
        if (input.mouseMoveWheel ~= 0 and ui.GetElementAt(ui.cursor.position) == nil) then
            if (mouseWheelCameraPosition) then
                cameraNode:Translate(Vector3(0, 0, -cameraBaseSpeed) * -input.mouseMoveWheel*20 * timeStep * speedMultiplier);
            else
                local zoom = camera.zoom + -input.mouseMoveWheel *.1 * speedMultiplier;
                camera.zoom = Clamp(zoom, .1, 30);
			end
		end
	end

    -- Rotate/orbit/pan camera
    if (input.mouseButtonDown[MOUSEB_RIGHT] or input.mouseButtonDown[MOUSEB_MIDDLE]) then
        SetMouseLock();
        local mouseMove = input.mouseMove;
        if (mouseMove.x ~= 0 or mouseMove.y ~= 0) then
            if (input.keyDown[KEY_LSHIFT] and input.mouseButtonDown[MOUSEB_MIDDLE]) then
                cameraNode:Translate(Vector3(-mouseMove.x, mouseMove.y, 0) * timeStep * cameraBaseSpeed * 0.5);
            else
                activeViewport.cameraYaw = activeViewport.cameraYaw + mouseMove.x * cameraBaseRotationSpeed;
                activeViewport.cameraPitch =  activeViewport.cameraPitch + mouseMove.y * cameraBaseRotationSpeed;

                if (limitRotation) then
                    activeViewport.cameraPitch = Clamp(activeViewport.cameraPitch, -90.0, 90.0);
				end

                local q = Quaternion(activeViewport.cameraPitch, activeViewport.cameraYaw, 0);
                cameraNode.rotation = q;
                if (input.mouseButtonDown[MOUSEB_MIDDLE] and (selectedNodes.length > 0 or selectedComponents.length > 0)) then
                    local centerPoint = SelectedNodesCenterPoint();
                    local d = cameraNode.worldPosition - centerPoint;
                    cameraNode.worldPosition = centerPoint - q * Vector3(0.0, 0.0, d.length);
                    orbiting = true;
				end
			end
		end
    else
        ReleaseMouseLock();
	end

    if (orbiting and not input.mouseButtonDown[MOUSEB_MIDDLE]) then
        orbiting = false;
	end

    -- Move/rotate/scale object
    if (#editNodes ~= 0 and editMode ~= EDIT_SELECT and input.keyDown[KEY_LCTRL]) then
        local adjust = Vector3(0, 0, 0);
        if (input.keyDown[KEY_UP]) then
            adjust.z = 1;
		end
        if (input.keyDown[KEY_DOWN]) then
            adjust.z = -1;
		end
        if (input.keyDown[KEY_LEFT]) then
            adjust.x = -1;
		end
        if (input.keyDown[KEY_RIGHT]) then
            adjust.x = 1;
		end
        if (input.keyDown[KEY_PAGEUP]) then
            adjust.y = 1;
		end
        if (input.keyDown[KEY_PAGEDOWN]) then
            adjust.y = -1;
		end
        if (editMode == EDIT_SCALE) then
            if (input.keyDown[KEY_KP_PLUS]) then
                adjust = Vector3(1, 1, 1);
			end
            if (input.keyDown[KEY_KP_MINUS]) then
                adjust = Vector3(-1, -1, -1);
			end
		end

        if (adjust == Vector3(0, 0, 0)) then
            return;
		end

        local moved = false;
        adjust = adjust * timeStep * 10;
		if (editMode == EDIT_MOVE) then
            if (not moveSnap) then
                moved = MoveNodes(adjust * moveStep);
			end
		elseif (editMode == EDIT_ROTATE) then
            if (not rotateSnap) then
                moved = RotateNodes(adjust * rotateStep);
			end
		elseif (editMode == EDIT_SCALE) then
            if (not scaleSnap) then
                moved = ScaleNodes(adjust * scaleStep);
			end
		end

        if (moved) then
            UpdateNodeAttributes();
		end
	end

    -- If not dragging
    if (resizingBorder == 0) then
        local uiElement = ui.GetElementAt(ui.cursorPosition);
        if (uiElement ~= nil and uiElement:GetVars():Contains("VIEWMODE")) then
            setViewportCursor = uiElement:GetVars():GetUInt("VIEWMODE");
            if (input.mouseButtonDown[MOUSEB_LEFT]) then
                resizingBorder = setViewportCursor;
			end
		end
	end
end

function SteppedObjectManipulation(key)
    if (#editNodes == nil or editMode == EDIT_SELECT) then
        return;
	end

    -- Do not react in non-snapped mode, because that is handled in frame update
    if (editMode == EDIT_MOVE and not moveSnap) then
        return;
	end
    if (editMode == EDIT_ROTATE and not rotateSnap) then
        return;
	end
    if (editMode == EDIT_SCALE and not scaleSnap) then
        return;
	end

    local adjust = Vector3(0, 0, 0);
    if (key == KEY_UP) then
        adjust.z = 1;
	end
    if (key == KEY_DOWN) then
        adjust.z = -1;
	end
    if (key == KEY_LEFT) then
        adjust.x = -1;
	end
    if (key == KEY_RIGHT) then
        adjust.x = 1;
	end
    if (key == KEY_PAGEUP) then
        adjust.y = 1;
	end
    if (key == KEY_PAGEDOWN) then
        adjust.y = -1;
	end
    if (editMode == EDIT_SCALE) then
        if (key == KEY_KP_PLUS) then
            adjust = Vector3(1, 1, 1);
		end
        if (key == KEY_KP_MINUS) then
            adjust = Vector3(-1, -1, -1);
		end
	end

    if (adjust == Vector3(0, 0, 0)) then
        return;
	end

    local moved = false;
	if (editMode == EDIT_MOVE) then
        moved = MoveNodes(adjust);
	elseif (editMode == EDIT_MOVE) then
		local rotateStepScaled = rotateStep * snapScale;
		moved = RotateNodes(adjust * rotateStepScaled);
	elseif (editMode == EDIT_MOVE) then
		local scaleStepScaled = scaleStep * snapScale;
		moved = ScaleNodes(adjust * scaleStepScaled);
	end
		
    if (moved) then
        UpdateNodeAttributes();
	end
end

function HandlePostRenderUpdate()
    local debug = editorScene.debugRenderer;
    if (debug == nil or orbiting) then
        return;
	end

    -- Visualize the currently selected nodes
	for i = 1, #selectedNodes do
        DrawNodeDebug(selectedNodes[i], debug);
	end

    -- Visualize the currently selected components
	for i = 1, #selectedComponents do
        selectedComponents[i]:DrawDebugGeometry(debug, false);
	end

    -- Visualize the currently selected UI-elements
	for i = 1, #selectedUIElements do
        ui.DebugDraw(selectedUIElements[i]);
	end

    if (renderingDebug) then
        renderer.DrawDebugGeometry(false);
	end
    if (physicsDebug and editorScene.physicsWorld ~= nil) then
        editorScene.physicsWorld.DrawDebugGeometry(true);
	end
    if (octreeDebug and editorScene.octree ~= nil) then
        editorScene.octree.DrawDebugGeometry(true);
	end

    if (bitor2(setViewportCursor , resizingBorder) > 0) then
        SetViewportCursor();
        if (resizingBorder == 0) then
            setViewportCursor = 0;
		end
	end

    ViewRaycast(false);
end

function DrawNodeDebug(node, debug, drawNode)
	if (drawNode == nil) then
		drawNode = true;
	end
    if (drawNode) then
        debug:AddNode(node, 1.0, false);
	end

    -- Exception for the scene to avoid bringing the editor to its knees: drawing either the whole hierarchy or the subsystem-
    -- components can have a large performance hit. Also do not draw terrain child nodes due to their large amount
    -- (TerrainPatch component itself draws nothing as debug geometry)
    if (node ~= editorScene and node:GetComponent("Terrain") == nil) then
		for j = 0,node.numComponents - 1 do
            node.components[j].DrawDebugGeometry(debug, false);
		end

        -- To avoid cluttering the view, do not draw the node axes for child nodes
		for k = 0, node.numChildren-1 do
            DrawNodeDebug(node.children[k], debug, false);
		end
	end
end

function ViewMouseMove()
    -- setting mouse position based on mouse position
    if (ui.IsDragging()) then
    elseif (ui.focusElement ~= nil or input.mouseButtonDown[bitor3(MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT)]) then
        return;
	end

    local pos = ui.cursor.position;
	for i = 1, #viewports do
        local vc = viewports[i];
        if (vc ~= activeViewport and vc.viewport.rect.IsInside(pos) == INSIDE) then
            SetActiveViewport(vc);
		end
	end
end

function ViewMouseClick()
    ViewRaycast(true);
end

function GetActiveViewportCameraRay()
    local view = activeViewport.viewport.rect;
    return camera:GetScreenRay(
        tonumber(ui.cursorPosition.x - view.left) / view.width,
        tonumber(ui.cursorPosition.y - view.top) / view.height
    );
end

function ViewMouseClickEnd()
    -- checks to close open popup windows
    local pos = ui.cursorPosition;
    if (contextMenu ~= nil and contextMenu.enabled) then
        if (contextMenuActionWaitFrame) then
            contextMenuActionWaitFrame = false;
        else
            if (not contextMenu:IsInside(pos, true)) then
                CloseContextMenu();
			end
		end
	end
    if (quickMenu ~= nil and quickMenu.enabled) then
        local enabled = quickMenu:IsInside(pos, true);
        quickMenu.enabled = enabled;
        quickMenu.visible = enabled;
	end
end

function ViewRaycast(mouseClick)
    -- Ignore if UI has modal element
    if (ui.HasModalElement()) then
        return;
	end

    -- Ignore if mouse is grabbed by other operation
    if (input.mouseGrabbed) then
        return;
	end

    local pos = ui.cursorPosition;
    local elementAtPos = ui:GetElementAt(pos, pickMode ~= PICK_UI_ELEMENTS);
    if (editMode == EDIT_SPAWN) then
        if(mouseClick and input.mouseButtonPress[MOUSEB_LEFT] and elementAtPos == nil) then
            SpawnObject();
		end
        return;
	end

    -- Do not raycast / change selection if hovering over the gizmo
    if (IsGizmoSelected()) then
        return;
	end

    local debug = editorScene.debugRenderer;

    if (pickMode == PICK_UI_ELEMENTS) then
        local leftClick = mouseClick and input.mouseButtonPress[MOUSEB_LEFT];
        local multiselect = input.qualifierDown[QUAL_CTRL];

        -- Only interested in user-created UI elements
        if (elementAtPos ~= nil and elementAtPos ~= editorUIElement and elementAtPos:GetElementEventSender() == editorUIElement) then
            ui:DebugDraw(elementAtPos);

            if (leftClick) then
                SelectUIElement(elementAtPos, multiselect);
			end
        -- If clicked on emptiness in non-multiselect mode, clear the selection
        elseif (leftClick and not multiselect and ui.GetElementAt(pos) == nil) then
            hierarchyList.ClearSelection();
		end

        return;
	end

    -- Do not raycast / change selection if hovering over a UI element when not in PICK_UI_ELEMENTS Mode
    if (elementAtPos ~= nil) then
        return;
	end

    local cameraRay = GetActiveViewportCameraRay();
    local selectedComponent;

    if (pickMode < PICK_RIGIDBODIES) then
        if (editorScene.octree == nil) then
            return;
		end

        local result = editorScene.octree:RaycastSingle(cameraRay, RAY_TRIANGLE, camera.farClip,
            pickModeDrawableFlags[pickMode], 0x7fffffff);
        if (result.drawable ~= nil) then
            local drawable = result.drawable;
            -- If selecting a terrain patch, select the parent terrain instead
            if (drawable.typeName ~= "TerrainPatch") then
                selectedComponent = drawable;
                if (debug ~= nil) then
                    debug:AddNode(drawable.node, 1.0, false);
					drawable:DrawDebugGeometry(debug, false);
				end
            elseif (drawable.node.parent ~= nil) then
                selectedComponent = drawable.node.parent.GetComponent("Terrain");
			end
		end
    else
        if (editorScene.physicsWorld == nil) then
            return;
		end

        -- If we are not running the actual physics update, refresh collisions before raycasting
        if (not runUpdate) then
            editorScene.physicsWorld:UpdateCollisions();
		end

        local result = editorScene.physicsWorld:RaycastSingle(cameraRay, camera.farClip);
        if (result.body ~= nil) then
            local body = result.body;
            if (debug ~= nil) then
                debug:AddNode(body.node, 1.0, false);
				body:DrawDebugGeometry(debug, false);
			end
            selectedComponent = body;
		end
	end

    if (mouseClick and input.mouseButtonPress[MOUSEB_LEFT]) then
        local multiselect = input.qualifierDown[QUAL_CTRL];
        if (selectedComponent ~= nil) then
            if (input.qualifierDown[QUAL_SHIFT]) then
                -- If we are selecting components, but have nodes in existing selection, do not multiselect to prevent confusion
                if (not selectedNodes.empty) then
                    multiselect = false;
				end
                SelectComponent(selectedComponent, multiselect);
            else
                -- If we are selecting nodes, but have components in existing selection, do not multiselect to prevent confusion
                if (not selectedComponents.empty) then
                    multiselect = false;
				end
                SelectNode(selectedComponent.node, multiselect);
			end
        else
            -- If clicked on emptiness in non-multiselect mode, clear the selection
            if (not multiselect) then
               SelectComponent(null, false);
			end
		end
	end
end

function GetNewNodePosition()
    return cameraNode.position + cameraNode.worldRotation * Vector3(0, 0, newNodeDistance);
end

function GetShadowResolution()
    if (not renderer.drawShadows) then
        return 0;
	end
    local level = 1;
    local res = renderer.shadowMapSize;
    while (res > 512) do
        res = bitrshift(res , 1);
		level = level + 1;
	end

    if (level > 3) then
        level = 3;
	end

    return level;
end

function SetShadowResolution(level)
    if (level <= 0) then
        renderer.drawShadows = false;
        return;
    else
        renderer.drawShadows = true;
        renderer.shadowMapSize = bitlshift(256 , level);
	end
end

function ToggleRenderingDebug()
    renderingDebug = not renderingDebug;
end

function TogglePhysicsDebug()
    physicsDebug = not physicsDebug;
end

function ToggleOctreeDebug()
    octreeDebug = not octreeDebug;
end

function StopTestAnimation()
    testAnimState = nil;
    return true;
end

function LocateNode(node)
    if (node == nil or node == editorScene) then
        return;
	end

    local center = node.worldPosition;
    local distance = newNodeDistance;

	for i = 0, node.numComponents - 1 do
        -- Determine view distance from drawable component's bounding box. Skip skybox, as its box is very large, as well as lights
        local drawable = tolua.cast(node.components[i], "Drawable");
        if (drawable ~= nil and tolua.cast(drawable,"Skybox") == nil and tolua.cast(drawable, "Light") == nil) then
            local box = drawable.worldBoundingBox;
            center = box.center;
            -- Ensure the object fits on the screen
            distance = Max(distance, newNodeDistance + box.size.length);
            break;
		end
	end

    if (distance > viewFarClip) then
        distance = viewFarClip;
	end

    cameraNode.worldPosition = center - cameraNode.worldDirection * distance;
end

function SelectedNodesCenterPoint()
    local centerPoint;
    local count = #selectedNodes;
	for i = 0,count - 1 do
        centerPoint = centerPoint + selectedNodes[i].worldPosition;
	end

	for i = 0, #selectedComponents - 1 do
        local drawable = tolua.cast(selectedComponents[i], "Drawable");
		count = count + 1;
        if (drawable ~= nil) then
            centerPoint = centerPoint + drawable.node:LocalToWorld(drawable.boundingBox.center);
        else
            centerPoint = centerPoint + selectedComponents[i].node.worldPosition;
		end
	end

    if (count > 0) then
        return centerPoint / count;
    else
        return centerPoint;
	end
end

function GetScreenCollision(pos)
    local cameraRay = camera:GetScreenRay(float(pos.x) / activeViewport.viewport.rect.width, float(pos.y) / activeViewport.viewport.rect.height);
    local res = cameraNode.position + cameraRay.direction * Vector3(0, 0, newNodeDistance);

    local physicsFound = false;
    if (editorScene.physicsWorld ~= nil) then
        if (not runUpdate) then
            editorScene.physicsWorld:UpdateCollisions();
		end

        local result = editorScene.physicsWorld:RaycastSingle(cameraRay, camera.farClip);

        if (result.body ~= nil) then
            physicsFound = true;
            --result.position;
		end
	end

    if (editorScene.octree == nil) then
        return res;
	end

    local result = editorScene.octree:RaycastSingle(cameraRay, RAY_TRIANGLE, camera.farClip,
        DRAWABLE_GEOMETRY, 0x7fffffff);

    if (result.drawable ~= nil) then
        -- take the closer of the results
        if (physicsFound and (cameraNode.position - res).length < (cameraNode.position - result.position).length) then
            return res;
        else
            return result.position;
		end
	end

    return res;
end

function GetDrawableAtMousePostion()
    local pos = ui.cursorPosition;
    local cameraRay = camera:GetScreenRay(float(pos.x) / activeViewport.viewport.rect.width, float(pos.y) / activeViewport.viewport.rect.height);

    if (editorScene.octree == nil) then
        return nil;
	end

    local result = editorScene.octree:RaycastSingle(cameraRay, RAY_TRIANGLE, camera.farClip, DRAWABLE_GEOMETRY, 0x7fffffff);

    return result.drawable;
end

function HandleBeginViewUpdate(eventType, eventData)
    -- Hide gizmo and grid from any camera other then active viewport
    if (eventData["Camera"]:GetPtr() ~= camera) then
        if (gizmo ~= nil) then
            gizmo.viewMask = 0;
		end
	end
    if (eventData["Camera"]:GetPtr() == previewCamera:Get()) then
        if (grid ~= nil) then
            grid.viewMask = 0;
		end
	end
end

function HandleEndViewUpdate(eventType, eventData)
    -- Restore gizmo and grid after camera view update
    if (eventData["Camera"]:GetPtr() ~= camera) then
        if (gizmo ~= nil) then
            gizmo.viewMask = 0x80000000;
		end
	end
    if (eventData["Camera"]:GetPtr() == previewCamera:Get()) then
        if (grid ~= nil) then
            grid.viewMask = 0x80000000;
		end
	end
end

local debugWasEnabled = true;

function HandleBeginViewRender(eventType, eventData)
    -- Hide debug geometry from preview camera
    if (eventData["Camera"]:GetPtr() == previewCamera:Get()) then
        local debug = editorScene:GetComponent("DebugRenderer");
        if (debug ~= nil) then
            suppressSceneChanges = true; -- Do not want UI update now
            debugWasEnabled = debug.enabled;
            debug.enabled = false;
            suppressSceneChanges = false;
		end
	end
end

function HandleEndViewRender(eventType, eventData)
    -- Restore debug geometry after preview camera render
    if (eventData["Camera"]:GetPtr() == previewCamera:Get()) then
        local debug = editorScene:GetComponent("DebugRenderer");
        if (debug ~= nil) then
            suppressSceneChanges = true; -- Do not want UI update now
            debug.enabled = debugWasEnabled;
            suppressSceneChanges = false;
		end
	end
end
