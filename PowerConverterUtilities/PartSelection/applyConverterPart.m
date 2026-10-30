function appliedSummary = applyConverterPart(modelName, options)
%APPLYCONVERTERPART Apply catalog parts to the converter plant inside a model.
%   appliedSummary = applyConverterPart(modelName, PartTable=partTable)
%   appliedSummary = applyConverterPart(modelName, PartTable=partTable, DeviceRole=role, Rank=rank)
%   appliedSummary = applyConverterPart(modelName, PartNumber=partNumber)
%   appliedSummary = applyConverterPart(modelName, Manufacturer=maker, PartNumber=partNumber)
%
%   Inputs:
%     modelName  Model name or file name.
%
%   Name-value options:
%     PartTable             Table from selectConverterParts.
%     Rank                  Rank per role, or one rank for all roles. Default 1.
%     DeviceRole            Roles to apply. Default all roles.
%     Manufacturer          Catalog manufacturer.
%     PartNumber            Catalog part number.
%     ConverterKey          converterRegistry key. Default "" detects it.
%     PlantBlock            Plant block path or name. Default "" detects it.
%     DeriveIdealFromCurve  Fit missing ideal values from the part I-V table. Default true.
%     SaveModel             Save the model after applying. Default false.
%     Display               Print what was applied. Default true.
%
%   Outputs:
%     appliedSummary  Struct with fields:
%                       modelName, plantBlockPath, converterKey.
%                       modelSaved  True if the model was saved.
%                       roles       Struct array of applyPartToDeviceRole summaries.
%
%   See also selectDeviceRating, selectConverterParts, applyPartToDeviceRole,
%   catalogPartRatings, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    modelName (1,1) string {mustBeNonzeroLengthText}
    options.PartTable table = table.empty
    options.Rank (1,:) double {mustBeInteger, mustBePositive} = 1
    options.DeviceRole (1,:) string = string.empty(1,0)
    options.Manufacturer (1,1) string = ""
    options.PartNumber (1,1) string = ""
    options.ConverterKey (1,1) string = ""
    options.PlantBlock (1,1) string = ""
    options.DeriveIdealFromCurve (1,1) logical = true
    options.SaveModel (1,1) logical = false
    options.Display (1,1) logical = true
end

% Check how the part is named.
partTableGiven = width(options.PartTable) > 0;
catalogPartGiven = strlength(options.Manufacturer) > 0 || strlength(options.PartNumber) > 0;

if partTableGiven && catalogPartGiven
    error('applyConverterPart:conflictingPartRequest', ...
        ['Name the part either with PartTable (and Rank) or with Manufacturer and ' ...
         'PartNumber, not both.']);
elseif ~partTableGiven && ~catalogPartGiven
    error('applyConverterPart:noPartRequested', ...
        ['No part requested. Pass PartTable=... from selectConverterParts, or ' ...
         'PartNumber=... (optionally with Manufacturer=...) to name a catalog part.']);
elseif partTableGiven && height(options.PartTable) == 0
    error('applyConverterPart:emptyPartTable', ...
        ['PartTable has no rows, so no part qualified for the rating. Relax the ' ...
         'rating, lower the safety factor, or name a part directly with ' ...
         'PartNumber=...']);
elseif catalogPartGiven && strlength(options.PartNumber) == 0
    error('applyConverterPart:manufacturerWithoutPartNumber', ...
        'Manufacturer="%s" needs a PartNumber to go with it.', options.Manufacturer);
end

% Load the model.
modelBaseName = normalizeModelName(modelName);
modelWasAlreadyLoaded = bdIsLoaded(modelBaseName);
if ~modelWasAlreadyLoaded
    load_system(modelBaseName);
end

% Find the plant block.
[plantBlockPath, converterKey] = findPlantBlock(modelBaseName, options.PlantBlock, ...
    options.ConverterKey);
converterEntry = converterRegistry(converterKey);

% Get one part row per role.
if partTableGiven
    partRowsToApply = selectRowsByRank(options.PartTable, options.DeviceRole, options.Rank);
else
    partRowsToApply = lookupCatalogPart(converterEntry, converterKey, options.DeviceRole, ...
        options.Manufacturer, options.PartNumber);
end

% Apply each part.
roleSummaryCells = cell(height(partRowsToApply), 1);
for rowIndex = 1:height(partRowsToApply)
    roleSummaryCells{rowIndex} = applyPartToDeviceRole(plantBlockPath, partRowsToApply(rowIndex,:), ...
        ConverterKey = converterKey, ...
        DeriveIdealFromCurve = options.DeriveIdealFromCurve, ...
        Display = options.Display);
end
roleSummaries = vertcat(roleSummaryCells{:});

if options.SaveModel
    save_system(modelBaseName);
end

appliedSummary = struct( ...
    'modelName',      modelBaseName, ...
    'plantBlockPath', string(plantBlockPath), ...
    'converterKey',   converterKey, ...
    'modelSaved',     options.SaveModel, ...
    'roles',          roleSummaries);

if options.Display
    fprintf('\n%s: %d part(s) applied to %s\n', modelBaseName, height(partRowsToApply), ...
        erase(string(plantBlockPath), modelBaseName + "/"));
    for rowIndex = 1:height(partRowsToApply)
        fprintf('   %s <- %s %s\n', string(partRowsToApply.DeviceRole(rowIndex)), ...
            string(partRowsToApply.Manufacturer(rowIndex)), ...
            string(partRowsToApply.PartNumber(rowIndex)));
    end
    if options.SaveModel
        fprintf('Model saved.\n');
    else
        fprintf('Model "%s" is loaded and modified but NOT saved. Run save_system("%s") to keep\n', ...
            modelBaseName, modelBaseName);
        fprintf('the change, or open_system("%s") to review it first.\n', modelBaseName);
    end
end
end

% ======================================================================
function modelBaseName = normalizeModelName(modelName)
% Return the model name without folder or model file extension.
[~, baseName, extension] = fileparts(char(modelName));
if ~ismember(lower(extension), {'', '.slx', '.mdl', '.slxp', '.mdlp'})
    baseName = [baseName extension];
end
modelBaseName = string(baseName);
if strlength(modelBaseName) == 0
    error('applyConverterPart:badModelName', ...
        'Could not read a model name out of "%s".', modelName);
end
end

% ======================================================================
function [plantBlockPath, converterKey] = findPlantBlock(modelBaseName, requestedBlock, requestedKey)
% Find the plant block and registry key by MaskType, then by block name.
if strlength(requestedBlock) > 0
    % Use the named block, as a full path or relative to the model.
    candidateBlocks = {char(requestedBlock)};
    if ~startsWith(requestedBlock, modelBaseName + "/")
        candidateBlocks = {char(modelBaseName + "/" + requestedBlock)};
    end
    if getSimulinkBlockHandle(candidateBlocks{1}) <= 0
        error('applyConverterPart:plantBlockNotFound', ...
            'PlantBlock "%s" does not exist in model "%s".', requestedBlock, modelBaseName);
    end
else
    % Search the model top level.
    candidateBlocks = find_system(char(modelBaseName), 'SearchDepth', 1, 'Type', 'Block');
end

blockMaskTypes = string(get_param(candidateBlocks, 'MaskType'));
blockNames     = string(get_param(candidateBlocks, 'Name'));

registeredKeys = converterRegistry();
if strlength(requestedKey) > 0
    converterRegistry(requestedKey);    % errors on an unknown key
    registeredKeys = requestedKey;
end

maskTypeMatchKeys = strings(0,1); maskTypeMatchBlocks = strings(0,1);
nameMatchKeys     = strings(0,1); nameMatchBlocks     = strings(0,1);
for keyIndex = 1:numel(registeredKeys)
    candidateEntry = converterRegistry(registeredKeys(keyIndex));
    if isfield(candidateEntry, 'plantMaskType') && strlength(candidateEntry.plantMaskType) > 0
        isMaskTypeMatch = blockMaskTypes == candidateEntry.plantMaskType;
        maskTypeMatchKeys = [maskTypeMatchKeys; ...
            repmat(registeredKeys(keyIndex), sum(isMaskTypeMatch), 1)]; %#ok<AGROW>
        maskTypeMatchBlocks = [maskTypeMatchBlocks; ...
            string(candidateBlocks(isMaskTypeMatch))]; %#ok<AGROW>
    end
    isNameMatch = contains(blockNames, candidateEntry.plantSubsystem);
    nameMatchKeys   = [nameMatchKeys;   repmat(registeredKeys(keyIndex), sum(isNameMatch), 1)]; %#ok<AGROW>
    nameMatchBlocks = [nameMatchBlocks; string(candidateBlocks(isNameMatch))];                  %#ok<AGROW>
end

if isscalar(maskTypeMatchKeys)
    converterKey = maskTypeMatchKeys(1);
    plantBlockPath = char(maskTypeMatchBlocks(1));
elseif isscalar(nameMatchKeys)
    converterKey = nameMatchKeys(1);
    plantBlockPath = char(nameMatchBlocks(1));
else
    error('applyConverterPart:plantBlockNotResolved', ...
        ['Could not identify one converter plant in model "%s": %d block(s) match a ' ...
         'registered MaskType and %d match a plant subsystem name. Pass ' ...
         'PlantBlock="..." (and ConverterKey="..." if needed). Registered: %s.'], ...
        modelBaseName, numel(maskTypeMatchKeys), numel(nameMatchKeys), ...
        strjoin(registeredKeys, ', '));
end
end

% ======================================================================
function partRows = selectRowsByRank(partTable, requestedRoles, requestedRanks)
% Return one part row per requested role and rank.
requiredColumns = ["DeviceRole" "Manufacturer" "PartNumber" "CollectionId" "PartId"];
missingColumns = requiredColumns(~ismember(requiredColumns, string(partTable.Properties.VariableNames)));
if ~isempty(missingColumns)
    error('applyConverterPart:missingPartTableColumns', ...
        ['PartTable is missing required column(s): %s. Pass the table returned by ' ...
         'selectConverterParts.'], strjoin(missingColumns, ', '));
end

availableRoles = unique(string(partTable.DeviceRole), 'stable');
if isempty(requestedRoles)
    targetRoles = availableRoles;
else
    targetRoles = requestedRoles(:);
    unknownRoles = targetRoles(~ismember(targetRoles, availableRoles));
    if ~isempty(unknownRoles)
        error('applyConverterPart:roleNotInPartTable', ...
            'PartTable has no rows for device role(s) %s. It lists: %s.', ...
            strjoin("""" + unknownRoles(:)' + """", ', '), strjoin(availableRoles(:)', ', '));
    end
end

% Expand the ranks to one per role.
if isscalar(requestedRanks)
    roleRanks = repmat(requestedRanks, numel(targetRoles), 1);
elseif numel(requestedRanks) == numel(targetRoles)
    roleRanks = requestedRanks(:);
else
    error('applyConverterPart:rankRoleMismatch', ...
        ['Rank has %d entries but %d device role(s) were requested. Give one rank, ' ...
         'or one per role in the same order (%s).'], ...
        numel(requestedRanks), numel(targetRoles), strjoin(targetRoles(:)', ', '));
end

partRows = partTable([], :);
for roleIndex = 1:numel(targetRoles)
    roleRows = partTable(string(partTable.DeviceRole) == targetRoles(roleIndex), :);
    requestedRank = roleRanks(roleIndex);

    % Match against the Rank column when present.
    if ismember("Rank", string(roleRows.Properties.VariableNames))
        matchingRow = find(roleRows.Rank == requestedRank, 1);
        availableRanks = string(mat2str(roleRows.Rank'));
    else
        matchingRow = [];
        if requestedRank <= height(roleRows); matchingRow = requestedRank; end
        availableRanks = string(mat2str(1:height(roleRows)));
    end
    if isempty(matchingRow)
        error('applyConverterPart:rankNotListed', ...
            'Rank %d is not in the %s list, which offers rank(s) %s.', ...
            requestedRank, targetRoles(roleIndex), availableRanks);
    end
    partRows = [partRows; roleRows(matchingRow, :)]; %#ok<AGROW>
end
end

% ======================================================================
function partRows = lookupCatalogPart(converterEntry, converterKey, requestedRoles, ...
        manufacturer, partNumber)
% Find a catalog part by part number in the converter's device roles.
if ~isfield(converterEntry, 'parts') || isempty(converterEntry.parts)
    error('applyConverterPart:noPartsDescriptor', ...
        ['converterRegistry("%s") has no .parts descriptor, so part selection is not ' ...
         'set up for this converter yet.'], converterKey);
end

declaredRoles = string({converterEntry.parts.role});
if isempty(requestedRoles)
    searchRoles = declaredRoles;
else
    searchRoles = requestedRoles(:)';
    unknownRoles = searchRoles(~ismember(searchRoles, declaredRoles));
    if ~isempty(unknownRoles)
        error('applyConverterPart:unknownDeviceRole', ...
            'Device role(s) %s are not declared for converter "%s". Declared: %s.', ...
            strjoin("""" + unknownRoles(:)' + """", ', '), converterKey, ...
            strjoin(declaredRoles(:)', ', '));
    end
end

partRows = emptyCatalogPartTable();
nearMissPartNumbers = strings(0,1);
for roleIndex = 1:numel(searchRoles)
    roleDescriptor = converterEntry.parts(declaredRoles == searchRoles(roleIndex));
    catalog = catalogPartRatings(roleDescriptor.modelingEntityId, ...
        roleDescriptor.voltageField, 'V', roleDescriptor.currentField, 'A');

    isMatch = strcmpi(catalog.partNumber, partNumber);
    if strlength(manufacturer) > 0
        isMatch = isMatch & strcmpi(catalog.manufacturer, manufacturer);
    end

    % Collect similar part numbers for the error message.
    partNumberPrefix = extractBefore(partNumber + "    ", 5);
    isNearMiss = ~isMatch & ( ...
        contains(catalog.partNumber, partNumber, IgnoreCase = true) | ...
        startsWith(catalog.partNumber, partNumberPrefix, IgnoreCase = true));
    nearMissPartNumbers = [nearMissPartNumbers; ...
        catalog.manufacturer(isNearMiss) + " " + catalog.partNumber(isNearMiss)]; %#ok<AGROW>

    matchIndices = find(isMatch);
    for k = 1:numel(matchIndices)
        matchIndex = matchIndices(k);
        partRows = [partRows; table(searchRoles(roleIndex), ...
            catalog.manufacturer(matchIndex), catalog.partNumber(matchIndex), ...
            catalog.voltageRating(matchIndex), catalog.currentRating(matchIndex), ...
            catalog.collectionId(matchIndex), catalog.partId(matchIndex), ...
            'VariableNames', partRows.Properties.VariableNames)]; %#ok<AGROW>
    end
end

if height(partRows) == 0
    suggestion = "";
    if ~isempty(nearMissPartNumbers)
        similarParts = unique(nearMissPartNumbers)';
        suggestion = sprintf(' Catalog parts with a similar number: %s.', ...
            strjoin(similarParts(1:min(8,numel(similarParts))), ', '));
    end
    error('applyConverterPart:partNotInCatalog', ...
        'No installed catalog part matches %s"%s" for converter "%s" role(s) %s.%s', ...
        ternaryText(strlength(manufacturer) > 0, manufacturer + " ", ""), ...
        partNumber, converterKey, strjoin(searchRoles(:)', ', '), suggestion);
end
if height(partRows) > 1
    matchedRoles = unique(string(partRows.DeviceRole));
    if isscalar(matchedRoles)
        error('applyConverterPart:ambiguousManufacturer', ...
            ['Part number "%s" exists for %d manufacturers in the %s catalog (%s). ' ...
             'Add Manufacturer="..." to choose one.'], ...
            partNumber, height(partRows), matchedRoles, ...
            strjoin(string(partRows.Manufacturer(:))', ', '));
    end
    error('applyConverterPart:ambiguousDeviceRole', ...
        ['Part "%s" is in the catalog of more than one device role (%s). Add ' ...
         'DeviceRole="..." to choose one.'], partNumber, strjoin(matchedRoles(:)', ', '));
end
end

% ======================================================================
function emptyTable = emptyCatalogPartTable()
% Return an empty part table with the columns applyPartToDeviceRole reads.
emptyTable = table(strings(0,1), strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    strings(0,1), strings(0,1), ...
    'VariableNames', {'DeviceRole','Manufacturer','PartNumber', ...
    'VoltageRating','CurrentRating','CollectionId','PartId'});
end

% ======================================================================
function text = ternaryText(condition, textIfTrue, textIfFalse)
% Return one of two strings based on a condition.
if condition
    text = textIfTrue;
else
    text = textIfFalse;
end
end
