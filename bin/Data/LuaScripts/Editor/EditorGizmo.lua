

gizmoNode = nil; -- Node
gizmo = nil; -- StaticModel


axisMaxD = 0.1;
axisMaxT = 1.0;
rotSensitivity = 50.0;

lastGizmoMode = nil; -- EditMode 

-- For undo
previousGizmoDrag = false;
needGizmoUndo = false;
oldGizmoTransforms = nil; -- Transform



GizmoAxis = {} 
function GizmoAxis:new()
	self.axisRay = nil;
	self.selected = false;
	self.lastSelected = false;
	self.t = 0.0;
	self.d = 0.0;
	self.lastT = 0.0;
	self.lastD = 0.0;

	return simpleclass(GizmoAxis);
end


function GizmoAxis:Update(cameraRay, scale, drag)

    -- Do not select when UI has modal element
    if (ui.HasModalElement()) then
        self.selected = false;
        return;
    end
    
    local closest = cameraRay:ClosestPoint(axisRay);
    local projected = axisRay:Project(closest);
    self.d = axisRay:Distance(closest);
    self.t = (projected - axisRay.origin):DotProduct(axisRay.direction);

    -- Determine the sign of d from a plane that goes through the camera position to the axis
    local axisPlane = Plane(cameraNode.position, axisRay.origin, axisRay.origin + axisRay.direction);
    if (axisPlane:Distance(closest) < 0.0) then
        self.d = -self.d;
    end

    -- Update selected status only when not dragging
    if (not drag) then
        self.selected = Abs(d) < axisMaxD * scale and t >= -axisMaxD * scale and t <= axisMaxT * scale;
        self.lastT = self.t;
        self.lastD = self.d;
    end
end

function GizmoAxis:Moved()
    self.lastT = self.t;
    self.lastD = self.d;
end


gizmoAxisX = GizmoAxis:new();
gizmoAxisY = GizmoAxis:new();
gizmoAxisZ = GizmoAxis:new();


function CreateGizmo()

    gizmoNode = Node:new();
    gizmo = gizmoNode:CreateComponent("StaticModel");
    gizmo.model = cache:GetResource("Model", "Models/Editor/Axes.mdl");
    gizmo.materials[0] = cache:GetResource("Material", "Materials/Editor/RedUnlit.xml");
    gizmo.materials[1] = cache:GetResource("Material", "Materials/Editor/GreenUnlit.xml");
    gizmo.materials[2] = cache:GetResource("Material", "Materials/Editor/BlueUnlit.xml");
    gizmo.enabled = false;
    gizmo.viewMask = 0x80000000; -- Editor raycasts use viewmask 0x7fffffff
    gizmo.occludee = false;

    gizmoAxisX.lastSelected = false;
    gizmoAxisY.lastSelected = false;
    gizmoAxisZ.lastSelected = false;
    lastGizmoMode = EDIT_MOVE;
end

function HideGizmo()
    if (gizmo ~= nil) then
        gizmo.enabled = false;
    end
end

function ShowGizmo()
    if (gizmo ~= nil) then
        gizmo.enabled = true;
        -- Because setting enabled = false detaches the gizmo from octree,
        -- and it is a manually added drawable, must readd to octree when showing
        if (editorScene.octree ~= nil) then
            editorScene.octree:AddManualDrawable(gizmo);
        end
   	end
end

function UpdateGizmo()
    UseGizmo();
    PositionGizmo();
    ResizeGizmo();
end


function PositionGizmo()

    if (gizmo == nil) then
        return;
    end

    local center = Vector3:new(0, 0, 0);
    local containsScene = false;

    for i = 1, #editNodes do
        -- Scene's transform should not be edited, so hide gizmo if it is included
        if (editNodes[i] == editorScene) then
            containsScene = true;
            break;
        end
        center = center + editNodes[i].worldPosition;
    end

    if (editNodes.empty or containsScene) then
        HideGizmo();
        return;
    end

    center = center / editNodes.length;
    gizmoNode.position = center;

    if (axisMode == AXIS_WORLD or editNodes.length > 1) then
        gizmoNode.rotation = Quaternion:new();
    else
        gizmoNode.rotation = editNodes[0].worldRotation;
    end
    if (editMode ~= lastGizmoMode) then
    	if (editMode == EDIT_MOVE) then
            gizmo.model = cache:GetResource("Model", "Models/Editor/Axes.mdl");
        elseif (editMode == EDIT_ROTATE) then
            gizmo.model = cache:GetResource("Model", "Models/Editor/RotateAxes.mdl");
        elseif (editMode ==  EDIT_SCALE) then
            gizmo.model = cache:GetResource("Model", "Models/Editor/ScaleAxes.mdl");
        end

        lastGizmoMode = editMode;
    end

    if ((editMode ~= EDIT_SELECT and not orbiting) and not gizmo.enabled) then
        ShowGizmo();
    elseif ((editMode == EDIT_SELECT or orbiting) and gizmo.enabled) then
        HideGizmo();
    end
end


function ResizeGizmo()

    if (gizmo == nil or not gizmo.enabled) then
        return;
    end

    local scale = 0.1 / camera.zoom;

    if (camera.orthographic) then
        scale = scale * camera.orthoSize;
    else
        scale = scale * (camera.view * gizmoNode.position).z;
	end

    gizmoNode.scale = Vector3(scale, scale, scale);
end

function CalculateGizmoAxes()
    gizmoAxisX.axisRay = Ray(gizmoNode.position, gizmoNode.rotation * Vector3(1, 0, 0));
    gizmoAxisY.axisRay = Ray(gizmoNode.position, gizmoNode.rotation * Vector3(0, 1, 0));
    gizmoAxisZ.axisRay = Ray(gizmoNode.position, gizmoNode.rotation * Vector3(0, 0, 1));
end

function GizmoMoved()
    gizmoAxisX:Moved();
    gizmoAxisY:Moved();
    gizmoAxisZ:Moved();
end


function UseGizmo()
    if (gizmo == nil or not gizmo.enabled or editMode == EDIT_SELECT) then
        StoreGizmoEditActions();
        previousGizmoDrag = false;
        return;
    end

    local pos = ui.cursorPosition;
    if (ui.GetElementAt(pos) ~= nil) then
        return;
    end
    local cameraRay = GetActiveViewportCameraRay();
    local scale = gizmoNode.scale.x;

    -- Recalculate axes only when not left-dragging
    local drag = input.mouseButtonDown[MOUSEB_LEFT];
    if (not drag) then
        CalculateGizmoAxes();
    end
    gizmoAxisX:Update(cameraRay, scale, drag);
    gizmoAxisY:Update(cameraRay, scale, drag);
    gizmoAxisZ:Update(cameraRay, scale, drag);

    if (gizmoAxisX.selected ~= gizmoAxisX.lastSelected) then
        gizmo.materials[0] = cache:GetResource("Material", returnor(gizmoAxisX.selected, "Materials/Editor/BrightRedUnlit.xml",
            "Materials/Editor/RedUnlit.xml"));
        gizmoAxisX.lastSelected = gizmoAxisX.selected;
    end
    if (gizmoAxisY.selected ~= gizmoAxisY.lastSelected) then
        gizmo.materials[1] = cache:GetResource("Material", returnor(gizmoAxisY.selected, "Materials/Editor/BrightGreenUnlit.xml",
            "Materials/Editor/GreenUnlit.xml"));
        gizmoAxisY.lastSelected = gizmoAxisY.selected;
    end
    if (gizmoAxisZ.selected ~= gizmoAxisZ.lastSelected) then
        gizmo.materials[2] = cache:GetResource("Material", returnor(gizmoAxisZ.selected, "Materials/Editor/BrightBlueUnlit.xml",
            "Materials/Editor/BlueUnlit.xml"));
        gizmoAxisZ.lastSelected = gizmoAxisZ.selected;
    end;

    if (drag) then
        -- Store initial transforms for undo when gizmo drag started
        if (not previousGizmoDrag) then
            oldGizmoTransforms:Resize(editNodes.length);
            for i = 0, #editNodes do
                oldGizmoTransforms[i]:Define(editNodes[i]);
           	end
        end

        local moved = false;
        if (editMode == EDIT_MOVE) then
        
            local adjust = Vector3:new(0, 0, 0);
            if (gizmoAxisX.selected) then
                adjust = adjust + Vector3(1, 0, 0) * (gizmoAxisX.t - gizmoAxisX.lastT);
            end
            if (gizmoAxisY.selected) then
                adjust = adjust + Vector3(0, 1, 0) * (gizmoAxisY.t - gizmoAxisY.lastT);
            end
            if (gizmoAxisZ.selected) then
                adjust = adjust + Vector3(0, 0, 1) * (gizmoAxisZ.t - gizmoAxisZ.lastT);
            end
            moved = MoveNodes(adjust);
        elseif (editMode == EDIT_ROTATE) then
            local adjust = Vector3(0, 0, 0);
            if (gizmoAxisX.selected) then
                adjust.x = (gizmoAxisX.d - gizmoAxisX.lastD) * rotSensitivity / scale;
            end
            if (gizmoAxisY.selected) then
                adjust.y = -(gizmoAxisY.d - gizmoAxisY.lastD) * rotSensitivity / scale;
            end
            if (gizmoAxisZ.selected) then
                adjust.z = (gizmoAxisZ.d - gizmoAxisZ.lastD) * rotSensitivity / scale;
            end
            moved = RotateNodes(adjust);
        elseif (editMode == EDIT_SCALE) then
            local adjust = Vector3:new(0, 0, 0);
            if (gizmoAxisX.selected) then
                adjust = adjust + Vector3(1, 0, 0) * (gizmoAxisX.t - gizmoAxisX.lastT);
            end
            if (gizmoAxisY.selected) then
                adjust = adjust + Vector3(0, 1, 0) * (gizmoAxisY.t - gizmoAxisY.lastT);
            end
            if (gizmoAxisZ.selected) then
                adjust = adjust + Vector3(0, 0, 1) * (gizmoAxisZ.t - gizmoAxisZ.lastT);
            end

            -- Special handling for uniform scale: use the unmodified X-axis movement only
            if (editMode == EDIT_SCALE and gizmoAxisX.selected and gizmoAxisY.selected and gizmoAxisZ.selected) then
                local x = gizmoAxisX.t - gizmoAxisX.lastT;
                adjust = Vector3(x, x, x);
            end
            moved = ScaleNodes(adjust);
        end
        if (moved) then
            GizmoMoved();
            UpdateNodeAttributes();
            needGizmoUndo = true;
        end
    else
    
        if (previousGizmoDrag) then
            StoreGizmoEditActions();
        end
    end

    previousGizmoDrag = drag;
end

function IsGizmoSelected()
    return gizmo ~= nil and gizmo.enabled and (gizmoAxisX.selected or gizmoAxisY.selected or gizmoAxisZ.selected);
end

function MoveNodes(adjust)

    local moved = false;

    if (adjust.length > M_EPSILON) then
    	for i = 0, #editNodes do
        
            if (moveSnap) then
            
                local moveStepScaled = moveStep * snapScale;
                adjust.x = math.floor(adjust.x / moveStepScaled + 0.5) * moveStepScaled;
                adjust.y = math.floor(adjust.y / moveStepScaled + 0.5) * moveStepScaled;
                adjust.z = math.floor(adjust.z / moveStepScaled + 0.5) * moveStepScaled;
            end

            local node = editNodes[i];
            local nodeAdjust = adjust;
            if (axisMode == AXIS_LOCAL and editNodes.length == 1) then
                nodeAdjust = node.worldRotation * nodeAdjust;
            end

            local worldPos = node.worldPosition;
            local oldPos = node.position;

            worldPos = worldPos + nodeAdjust;

            if (node.parent == nil) then
                node.position = worldPos;
            else
                node.position = node.parent:WorldToLocal(worldPos);
            end

            if (node.position ~= oldPos) then
                moved = true;
            end
        end
    end

    return moved;
end

function RotateNodes(adjust)

    local moved = false;

    if (rotateSnap) then
    
        local rotateStepScaled = rotateStep * snapScale;
        adjust.x = math.floor(adjust.x / rotateStepScaled + 0.5) * rotateStepScaled;
        adjust.y = math.floor(adjust.y / rotateStepScaled + 0.5) * rotateStepScaled;
        adjust.z = math.floor(adjust.z / rotateStepScaled + 0.5) * rotateStepScaled;
    end

    if (adjust.length > M_EPSILON) then
    
        moved = true;
        for i = 1, #editNodes do
            local node = editNodes[i];
            local rotQuat = Quaternion(adjust);
            if (axisMode == AXIS_LOCAL and editNodes.length == 1) then
                node.rotation = node.rotation * rotQuat;
            else
            
                local offset = node.worldPosition - gizmoAxisX.axisRay.origin;
                if (node.parent ~= nil and node.parent.worldRotation ~= Quaternion(1, 0, 0, 0)) then
                    rotQuat = node.parent.worldRotation.Inverse() * rotQuat * node.parent.worldRotation;
                end
                node.rotation = rotQuat * node.rotation;
                local newPosition = gizmoAxisX.axisRay.origin + rotQuat * offset;
                if (node.parent ~= nil) then
                    newPosition = node.parent.WorldToLocal(newPosition);
                end
                node.position = newPosition;
            end
        end
    end

    return moved;
end

function ScaleNodes(adjust)

    local moved = false;

    if (adjust.length > M_EPSILON) then
    	for i = 1, #editNodes do
            local node = editNodes[i];
            local scale = node.scale;
            local oldScale = scale;

            if (not scaleSnap) then
                scale = scale + adjust;
            else
                local scaleStepScaled = scaleStep * snapScale;
                if (adjust.x ~= 0) then
                    scale.x =  scale.x + adjust.x * scaleStepScaled;
                    scale.x = math.floor(scale.x / scaleStepScaled + 0.5) * scaleStepScaled;
                end
                if (adjust.y ~= 0) then
                    scale.y = scale.y + adjust.y * scaleStepScaled;
                    scale.y = math.floor(scale.y / scaleStepScaled + 0.5) * scaleStepScaled;
                end
                if (adjust.z ~= 0) then
                    scale.z = scale.z + adjust.z * scaleStepScaled;
                    scale.z = math.floor(scale.z / scaleStepScaled + 0.5) * scaleStepScaled;
                end
            end

            if (scale ~= oldScale) then
                moved = true;
            end
            node.scale = scale;
        end
    end

    return moved;
end

function StoreGizmoEditActions()
    if (needGizmoUndo and #editNodes > 0 and oldGizmoTransforms.length == #editNodes) then
    
        local group = EditActionGroup:new();
        
        for i = 1, #editNodes do
        
            local action = EditNodeTransformAction:new();
            action:Define(editNodes[i], oldGizmoTransforms[i]);
            table.insert(group.actions, action);
        end
        
        SaveEditActionGroup(group);
        SetSceneModified();
    end

    needGizmoUndo = false;
end

