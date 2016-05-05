-- Urho3D editor import functions

importOptions = "-t";

ParentAssignment = {};
function ParentAssignment:new()
    self.childID = 0;
    self.parentName = nil;
    return simpleclass(ParentAssignment);
end

AssetMapping = {};
function AssetMapping:new()
    self.assetName = '';
    self.fullAssetName = '';
    return simpleclass(AssetMapping);
end

assetMappings = {};

assetImporterPath = '';

function ExecuteAssetImporter(args)
    if (assetImporterPath == '') then
        local exeSuffix = "";
        if (GetPlatform() == "Windows") then
            exeSuffix = ".exe";
        end
        -- Try both with and without the tool directory; a packaged build may not have the tool directory
        assetImporterPath = fileSystem.programDir .. "tool/AssetImporter" .. exeSuffix;
        if (not fileSystem:FileExists(assetImporterPath)) then
            assetImporterPath = fileSystem.programDir .. "AssetImporter" .. exeSuffix;
        end
    end

    return fileSystem:SystemRun(assetImporterPath, args);
end

function ImportModel(fileName)
    if (fileName == nil or fileName == '') then
        return;
    end

    ui.cursor.shape = CS_BUSY;

    local modelName = "Models/" .. GetFileName(fileName) .. ".mdl";
    local outFileName = sceneResourcePath .. modelName;
    fileSystem:CreateDir(sceneResourcePath .. "Models");

    local args = {
        "model",
        "\"" .. fileName .. "\"",
        "\"" .. outFileName .. "\"",
        "-p \"" .. sceneResourcePath .. "\"",
    };

    local options = Split(Trimmed(importOptions), ' ');
    for i = 1, #options do
        table.insert(args, options[i]);
    end
    -- If material lists are to be applied, make sure the option to create them exists
    if (applyMaterialList) then
        table.insert("-l")
    end

    if (ExecuteAssetImporter(args) == 0) then
    
        local newNode = editorScene:CreateChild(GetFileName(fileName));
        local newModel = newNode:CreateComponent("StaticModel");
        newNode.position = GetNewNodePosition();
        newModel.model = cache:GetResource("Model", modelName);
        newModel:ApplyMaterialList(); -- Setup default materials if possible

        -- Create an undo action for the create
        local action = CreateNodeAction:new();
        action:Define(newNode);
        SaveEditAction(action);
        SetSceneModified();

        FocusNode(newNode);
    else
        log:Error("Failed to execute AssetImporter to import model");
    end
end

function ImportScene(fileName)
    if (Empty(fileName)) then
        return;
    end

    ui.cursor.shape = CS_BUSY;

    -- Handle Tundra scene files here in code, otherwise via AssetImporter
    if (GetExtension(fileName) == ".txml") then
        ImportTundraScene(fileName);
    else
    
        -- Export scene to a temp file, then load and delete it if successful
        local tempSceneName = sceneResourcePath .. TEMP_SCENE_NAME;
        local args = {
            "scene",
            "\"" .. fileName .. "\"",
            "\"" .. tempSceneName .. "\"",
            "-p \"" .. sceneResourcePath .. "\"",
        };

        local options = Split(Trimmed(importOptions),' ');
        for i = 1, #options do
            table.insert(args, options[i]);
        end
        if (applyMaterialList) then
            table.insert(args, '-l')
        end
        if (ExecuteAssetImporter(args) == 0) then
            skipMruScene = true; -- set to avoid adding tempscene to mru
            LoadScene(tempSceneName);
            fileSystem:Delete(tempSceneName);
            UpdateWindowTitle();
        else
            log:Error("Failed to execute AssetImporter to import scene");
        end
    end
end

function ImportTundraScene(fileName)
    fileSystem:CreateDir(sceneResourcePath .. "Materials");
    fileSystem:CreateDir(sceneResourcePath .. "Models");
    fileSystem:CreateDir(sceneResourcePath .. "Textures");

    local source = XMLFile:new();
    source:Load(File(fileName, FILE_READ));
    local filePath = GetPath(fileName);

    local sceneElem = source.root;
    local entityElem = sceneElem:GetChild("entity");

    local convertedMaterials = {};
    local convertedMeshes = {};
    local parentAssignments = {};

    -- Read the scene directory structure recursively to get assetname to full assetname mappings
    local fileNames = fileSystem:ScanDir(filePath, "*.*", SCAN_FILES, true);
    for i = 1, #fileNames do
        local mapping = AssetMapping:new();
        mapping.assetName = GetFileNameAndExtension(fileNames[i]);
        mapping.fullAssetName = fileNames[i];
        Push(assetMappings, mapping)
    end

    -- Clear old scene, then create a zone and a directional light first
    ResetScene();

    -- Set standard gravity
    editorScene:CreateComponent("PhysicsWorld");
    editorScene.physicsWorld.gravity = Vector3(0, -9.81, 0);

    -- Create zone & global light
    local zoneNode = editorScene:CreateChild("Zone");
    local zone = zoneNode:CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000, 1000);
    zone.ambientColor = Color(0.364, 0.364, 0.364);
    zone.fogColor = Color(0.707792, 0.770537, 0.831373);
    zone.fogStart = 100.0;
    zone.fogEnd = 500.0;

    local lightNode = editorScene:CreateChild("GlobalLight");
    local light = lightNode:CreateComponent("Light");
    lightNode.rotation = Quaternion(60, 30, 0);
    light.lightType = LIGHT_DIRECTIONAL;
    light.color = Color(0.639, 0.639, 0.639);
    light.castShadows = true;
    light.shadowCascade = CascadeParameters(5, 15.0, 50.0, 0.0, 0.9);

    -- Loop through scene entities
    while (not entityElem.isNull) do
        local nodeName;
        local meshName;
        local parentName;
        local meshPos;
        local meshRot;
        local meshScale = Vector3:new(1, 1, 1);
        local pos;
        local rot;
        local scale = Vector3:new(1, 1, 1);
        local castShadows = false;
        local drawDistance = 0;
        local materialNames;

        local shapeType = -1;
        local mass = 0.0;
        local bodySize;
        local trigger = false;
        local kinematic = false;
        local collisionLayer;
        local collisionMask;
        local collisionMeshName;

        local compElem = entityElem:GetChild("component");
        while (not compElem.isNull) do
            local compType = compElem.GetAttribute("type");

            if (compType == "EC_Mesh" or compType == "Mesh") then
                local coords = Split(GetComponentAttribute(compElem, "Transform"), ',');
                meshPos = GetVector3FromStrings(coords, 0);
                meshPos.z = -meshPos.z; -- Convert to lefthanded
                meshRot = GetVector3FromStrings(coords, 3);
                meshScale = GetVector3FromStrings(coords, 6);
                meshName = GetComponentAttribute(compElem, "Mesh ref");
                castShadows = ToBool(GetComponentAttribute(compElem, "Cast shadows"));
                drawDistance = ToFloat(GetComponentAttribute(compElem, "Draw distance"));
                materialNames = Split(GetComponentAttribute(compElem, "Mesh materials"), ';');
                ProcessRef(meshName);
                for i = 1, #materialNames do
                    ProcessRef(materialNames[i]);
                end
            end
            if (compType == "EC_Name" or compType == "Name") then
                nodeName = GetComponentAttribute(compElem, "name");
            end
            if (compType == "EC_Placeable" or compType == "Placeable") then
            
                local coords = Split(GetComponentAttribute(compElem, "Transform"),',');
                pos = GetVector3FromStrings(coords, 0);
                pos.z = -pos.z; -- Convert to lefthanded
                rot = GetVector3FromStrings(coords, 3);
                scale = GetVector3FromStrings(coords, 6);
                parentName = GetComponentAttribute(compElem, "Parent entity ref");
            end
            if (compType == "EC_RigidBody" or compType == "RigidBody") then
                shapeType = ToInt(GetComponentAttribute(compElem, "Shape type"));
                mass = ToFloat(GetComponentAttribute(compElem, "Mass"));
                bodySize = ToVector3(GetComponentAttribute(compElem, "Size"));
                collisionMeshName = GetComponentAttribute(compElem, "Collision mesh ref");
                trigger = ToBool(GetComponentAttribute(compElem, "Phantom"));
                kinematic = ToBool(GetComponentAttribute(compElem, "Kinematic"));
                collisionLayer = ToInt(GetComponentAttribute(compElem, "Collision Layer"));
                collisionMask = ToInt(GetComponentAttribute(compElem, "Collision Mask"));
                ProcessRef(collisionMeshName);
            end

            compElem = compElem.GetNext("component");
        end

        -- If collision mesh not specified for the rigid body, assume same as the visible mesh
        if ((shapeType == 4 or shapeType == 6) and Empty(Trimmed(collisionMeshName))) then
            collisionMeshName = meshName;
        end

        if (Empty(meshName) or shapeType >= 0) then
            for i = 1, #materialNames do
                ConvertMaterial(materialNames[i], filePath, convertedMaterials);
            end

            ConvertModel(meshName, filePath, convertedMeshes);
            ConvertModel(collisionMeshName, filePath, convertedMeshes);

            local newNode = editorScene:CreateChild(nodeName);

            -- Calculate final transform in an Ogre-like fashion
            local quat = GetTransformQuaternion(rot);
            local meshQuat = GetTransformQuaternion(meshRot);
            local finalQuat = quat * meshQuat;
            local finalScale = scale * meshScale;
            local finalPos = pos + quat * (scale * meshPos);

            newNode:SetTransform(finalPos, finalQuat, finalScale);

            -- Create model
            if (empty(meshName)) then
                local model = newNode:CreateComponent("StaticModel");
                model.model = cache:GetResource("Model", GetOutModelName(meshName));
                model.drawDistance = drawDistance;
                model.castShadows = castShadows;
                -- Set default grey material to match Tundra defaults
                model.material = cache:GetResource("Material", "Materials/DefaultGrey.xml");
                -- Then try to assign the actual materials
                for i = 1, #materialNames do
                    local mat = cache:GetResource("Material", GetOutMaterialName(materialNames[i]));
                    if (mat ~= nil) then
                        model.materials[i] = mat;
                    end
                end
            end

            -- Create rigidbody & collision shape
            if (shapeType >= 0) then
                local body = newNode:CreateComponent("RigidBody");

                -- If mesh has scaling, undo it for the collision shape
                bodySize.x = bodySize.x / meshScale.x;
                bodySize.y = bodySize.y / meshScale.y;
                bodySize.z = bodySize.z / meshScale.z;

                local shape = newNode:CreateComponent("CollisionShape");
                if (shapeType == 0) then
                    shape:SetBox(bodySize);
                elseif (bodySize == 1) then
                    shape:SetSphere(bodySize.x);
                elseif (bodySize == 2) then
                    shape:SetCylinder(bodySize.x, bodySize.y);
                elseif (bodySize == 3) then
                    shape:SetCapsule(bodySize.x, bodySize.y);
                elseif (bodySize == 4) then
                    shape:SetTriangleMesh(cache:GetResource("Model", GetOutModelName(collisionMeshName)), 0, bodySize);
                elseif (bodySize == 5) then
                elseif (bodySize == 6) then
                    shape:SetConvexHull(cache:GetResource("Model", GetOutModelName(collisionMeshName)), 0, bodySize);
                end

                body.collisionLayer = collisionLayer;
                body.collisionMask = collisionMask;
                body.trigger = trigger;
                body.mass = mass;
            end

            -- Store pending parent assignment if necessary
            if (not empty(parentName)) then
                local assignment = ParentAssignment:new();
                assignment.childID = newNode.ID;
                assignment.parentName = parentName;
                table.insert(parentAssignments, assignment);
            end
        end

        entityElem = entityElem:GetNext("entity");
    end

    -- Process any parent assignments now
    for i = 1, #parentAssignments do
        local childNode = editorScene:GetNode(parentAssignments[i].childID);
        local parentNode = editorScene:GetChild(parentAssignments[i].parentName, true);
        if (childNode ~= nil and parentNode ~= nil) then
            childNode.parent = parentNode;
        end
    end

    UpdateHierarchyItem(editorScene, true);
    UpdateWindowTitle();
    Clear(assetMappings);
end

function GetFullAssetName(assetName)
    for i = 1, #assetMappings do
        if (assetMappings[i].assetName == assetName) then
            return assetMappings[i].fullAssetName;
        end
    end

    return assetName;
end

function GetTransformQuaternion(rotEuler)

    -- Convert rotation to lefthanded
    local rotateX = Quaternion(-rotEuler.x, Vector3(1, 0, 0));
    local rotateY = Quaternion(-rotEuler.y, Vector3(0, 1, 0));
    local rotateZ = Quaternion(-rotEuler.z, Vector3(0, 0, -1));
    return rotateZ * rotateY * rotateX;
end

function GetComponentAttribute(compElem, name)
    local attrElem = compElem:GetChild("attribute");
    while (not attrElem.isNull) do
        if (attrElem:GetAttribute("name") == name) then
            return attrElem:GetAttribute("value");
        end

        attrElem = attrElem:GetNext("attribute");
    end

    return "";
end

function GetVector3FromStrings(coords, startIndex)
    return Vector3(ToFloat(coords[startIndex]), ToFloat(coords[startIndex + 1]), ToFloat(coords[startIndex + 2]));
end

function ProcessRef(ref)
    if (ref:StartsWith("local:--")) then
        ref = ref:Substring(8);
    end
    if (ref:StartsWith("file:--")) then
        ref = ref:Substring(7);
    end
end

function GetOutModelName(ref)
    return "Models/" .. Replaced(Replaced(GetFullAssetName(ref),"/", "_"), ".mesh", ".mdl");
end

function GetOutMaterialName(ref)
    return "Materials/" .. Replaced(Replaced(GetFullAssetName(ref),'/', '_'), ".material", ".xml");
end

function GetOutTextureName(ref)
    return "Textures/" .. Replaced(GetFullAssetName(ref),'/', '_');
end

function ConvertModel(modelName, filePath, convertedModels)
    if (empty(Trimmed(modelName))) then
        return;
    end

    for i = 1, #convertedModels do
        if (convertedModels[i] == modelName) then
            return;
        end
    end

    local meshFileName = filePath .. GetFullAssetName(modelName);
    local xmlFileName = filePath .. GetFullAssetName(modelName) .. ".xml";
    local outFileName = sceneResourcePath .. GetOutModelName(modelName);

    -- Convert .mesh to .mesh.xml
    local cmdLine = "ogrexmlconverter \"" .. meshFileName .. "\" \"" .. xmlFileName .. "\"";
    if (not fileSystem:FileExists(xmlFileName)) then
        fileSystem:SystemCommand(Replaced(cmdLine, '/', '\\'));
    end

    if (not fileSystem:FileExists(outFileName)) then
        -- Convert .mesh.xml to .mdl
        local args = {
            "\"" .. xmlFileName .. "\"",
            "\"" .. outFileName .. "\"",
            "-a"
        };
        fileSystem:SystemRun(fileSystem.programDir .. "tool/OgreImporter", args);
    end

    Push(convertedModels, modelName)
end

function ConvertMaterial(materialName, filePath, convertedMaterials)
    if (empty(Trimmed(materialName))) then
        return;
    end

    for i = 1, #convertedMaterials do
        if (convertedMaterials[i] == materialName) then
            return;
        end
    end

    local fileName = filePath .. GetFullAssetName(materialName);
    local outFileName = sceneResourcePath .. GetOutMaterialName(materialName);

    if (not fileSystem:FileExists(fileName)) then
        return;
    end

    local mask = false;
    local twoSided = false;
    local uvScaleSet = false;
    local textureName;
    local uvScale = Vector2(1, 1);
    local diffuse = Color(1, 1, 1, 1);

    local file = File:new(fileName, FILE_READ);
    while (not file.eof) do
        local line = Trimmed(file:ReadLine());
        if (StartsWith(line,"alpha_rejection") or StartsWith(line,"scene_blend alpha_blend")) then
            mask = true;
        end
        if (StartsWith(line, "cull_hardware none")) then
            twoSided = true;
        end
        -- Todo: handle multiple textures per material
        if (empty(textureName) and StartsWith(line, "texture ")) then
            textureName = Substring(line, 8);
            ProcessRef(textureName);
        end
        if (not uvScaleSet and StartsWith(line, "scale ")) then
            uvScale = ToVector2(Substring(line, 6));
            uvScaleSet = true;
        end
        if (StartsWith(line, "diffuse ")) then
            diffuse = ToColor(Substring(line, 8));
        end
    end

    local outMat = XMLFile:new();
    local rootElem = outMat:CreateRoot("material");
    local techniqueElem = rootElem:CreateChild("technique");

    if (twoSided) then
        local cullElem = rootElem:CreateChild("cull");
        cullElem:SetAttribute("value", "none");
        local shadowCullElem = rootElem:CreateChild("shadowcull");
        shadowCullElem:SetAttribute("value", "none");
    end

    if (not empty(textureName)) then
        techniqueElem:SetAttribute("name", ifor(mask, "Techniques/DiffAlphaMask.xml", "Techniques/Diff.xml"));

        local outTextureName = GetOutTextureName(textureName);
        local textureElem = rootElem:CreateChild("texture");
        textureElem:SetAttribute("unit", "diffuse");
        textureElem:SetAttribute("name", outTextureName);

        fileSystem.Copy(filePath .. GetFullAssetName(textureName), sceneResourcePath .. outTextureName);
    else
        techniqueElem:SetAttribute("name", "NoTexture.xml");
    end

    if (uvScale ~= Vector2(1, 1)) then
        local uScaleElem = rootElem:CreateChild("parameter");
        uScaleElem:SetAttribute("name", "UOffset");
        uScaleElem:SetVector3("value", Vector3(1 / uvScale.x, 0, 0));

        local vScaleElem = rootElem:CreateChild("parameter");
        vScaleElem:SetAttribute("name", "VOffset");
        vScaleElem:SetVector3("value", Vector3(0, 1 / uvScale.y, 0));
    end

    if (diffuse ~= Color(1, 1, 1, 1)) then
        local diffuseElem = rootElem:CreateChild("parameter");
        diffuseElem:SetAttribute("name", "MatDiffColor");
        diffuseElem:SetColor("value", diffuse);
    end

    local outFile = File:new(outFileName, FILE_WRITE);
    outMat:Save(outFile);
    outFile:Close();

    Push(convertedMaterials, materialName);
end
