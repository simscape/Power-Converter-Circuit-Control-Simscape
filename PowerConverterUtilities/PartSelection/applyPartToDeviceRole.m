function appliedSummary = applyPartToDeviceRole(plantBlockPath, partRow, options)
%APPLYPARTTODEVICEROLE Apply a catalog part to every device of one converter plant role.
%   appliedSummary = applyPartToDeviceRole(plantBlockPath, partRow)
%   appliedSummary = applyPartToDeviceRole(___, Name=Value)
%
%   Inputs:
%     plantBlockPath  Path or handle of the masked converter plant block.
%     partRow         One row of the selectConverterParts table.
%
%   Name-value options:
%     ConverterKey          converterRegistry key. Default "" detects it from the block.
%     DeriveIdealFromCurve  Fit missing ideal values from the part I-V table. Default true.
%     Display               Print what was written. Default true.
%
%   Outputs:
%     appliedSummary  Struct with fields:
%                       converterKey, deviceRole, partId, collectionId.
%                       deviceBlocks              Paths of the devices set.
%                       maskParameters            Table of the plant mask writes.
%                       deviceSettingCorrections  Struct array of corrected device settings.
%
%   See also applyConverterPart, selectDeviceRating, selectConverterParts,
%   converterRegistry, partrepo.collection.applyDataSet.

% Copyright 2026 The MathWorks, Inc.

arguments
    plantBlockPath
    partRow table
    options.ConverterKey (1,1) string = ""
    options.DeriveIdealFromCurve (1,1) logical = true
    options.Display (1,1) logical = true
end

if height(partRow) ~= 1
    error('applyPartToDeviceRole:onePartRow', ...
        'partRow must be a single row of the selectConverterParts table; got %d rows.', ...
        height(partRow));
end
plantBlockPath = getfullname(get_param(plantBlockPath, 'Handle'));

% Resolve the converter and the device role.
[converterKey, converterEntry] = resolveConverter(plantBlockPath, options.ConverterKey);
deviceRole = string(partRow.DeviceRole);
roleDescriptor = resolveRole(converterEntry, converterKey, deviceRole);

collectionId = char(string(partRow.CollectionId));
partId       = char(string(partRow.PartId));

% Find every device block of this role in all variant choices.
[deviceBlocks, isOlderReleaseBlock] = findRoleDeviceBlocks(plantBlockPath, roleDescriptor, partId);
if isempty(deviceBlocks)
    error('applyPartToDeviceRole:noDeviceBlock', ...
        ['Found no "%s" device block under "%s". Check the .parts searchRoot and ' ...
         'modelingEntityId for role "%s" in converterRegistry("%s").'], ...
        roleDescriptor.modelingEntityId, ...
        strjoin(fullfile(string(plantBlockPath), string(roleDescriptor.searchRoot)), '", "'), ...
        deviceRole, converterKey);
end

% Apply the part and correct the device settings.
correctedIssues = struct('deviceBlock', {}, 'issueKind', {}, 'parameterName', {}, ...
    'currentValue', {}, 'writes', {}, 'message', {}, 'wasCorrected', {});
for blockIndex = 1:numel(deviceBlocks)
    deviceBlock = deviceBlocks{blockIndex};
    if isOlderReleaseBlock(blockIndex)
        applyToOlderReleaseBlock(deviceBlock, collectionId, partId);
    else
        applyPartDataSet(deviceBlock, collectionId, partId);
    end
    enforceDeviceGuardRails(deviceBlock);
    % The data set clears the 3-D switching-energy tables and leaves their 2-D reference
    % voltage at the library default, so the 3-D tables are selected here
    enforceSwitchingLossVoltageTables(deviceBlock, OnIssue="correct");
    correctedIssues = [correctedIssues; ...
        enforceIntegralDiodeSettings(deviceBlock, OnIssue="correct")]; %#ok<AGROW>
end

if any(isOlderReleaseBlock)
    warning('applyPartToDeviceRole:olderReleaseDeviceBlock', ...
        '%d %s device blocks were created in an earlier release. The part parameters were applied to them one by one.', ...
        nnz(isOlderReleaseBlock), deviceRole);
end

% Copy the ideal-fidelity values to the plant mask.
representativeBlock = deviceBlocks{1};
maskParameterSummary = writeIdealMaskParameters(plantBlockPath, representativeBlock, ...
    roleDescriptor, partRow, options.DeriveIdealFromCurve);

appliedSummary = struct( ...
    'converterKey',   converterKey, ...
    'deviceRole',     deviceRole, ...
    'partId',         string(partId), ...
    'collectionId',   string(collectionId), ...
    'deviceBlocks',   {deviceBlocks}, ...
    'maskParameters', maskParameterSummary, ...
    'deviceSettingCorrections', {correctedIssues});

if options.Display
    fprintf('\n%s / %s: applied part %s\n', converterKey, roleDescriptor.displayName, partId);
    fprintf('   %d device block(s) parameterized (all variant choices):\n', numel(deviceBlocks));
    fprintf('      %s\n', string(erase(deviceBlocks, [plantBlockPath '/'])));
    fprintf(['   Thermal network topology forced to external; previous-cycle switching-loss options off; ' ...
        'switching energy tabulated with off-state voltage.\n']);
    reportSettingCorrections(correctedIssues);
    fprintf('   Ideal-fidelity mask parameters:\n');
    disp(maskParameterSummary);
end
end

% ======================================================================
function reportSettingCorrections(correctedIssues)
% Print the number of devices corrected per rule.
if isempty(correctedIssues)
    return
end
ruleText = struct( ...
    'separateThermalPort',   'Integral diode separate thermal port cleared', ...
    'zeroRecoveryLossTable', 'Reverse recovery loss model set to fixed (its table held only zeros)', ...
    'scaledZeroRecoveryLoss', 'Reverse recovery loss scaling cleared (fixed loss of zero)');
issueKinds = [correctedIssues.issueKind];
for ruleName = string(fieldnames(ruleText))'
    correctedCount = sum(issueKinds == ruleName & [correctedIssues.wasCorrected]);
    reportedCount = sum(issueKinds == ruleName & ~[correctedIssues.wasCorrected]);
    if correctedCount > 0
        fprintf('   %s on %d device(s).\n', ruleText.(ruleName), correctedCount);
    end
    if reportedCount > 0
        fprintf('   %s: %d device(s) reported, not corrected.\n', ruleText.(ruleName), reportedCount);
    end
end
end

% ======================================================================
function [converterKey, converterEntry] = resolveConverter(plantBlockPath, requestedKey)
% Find the converterRegistry entry by key, MaskType, or block name.
if strlength(requestedKey) > 0
    converterKey = requestedKey;
    converterEntry = converterRegistry(converterKey);
    return
end

blockMaskType = get_param(plantBlockPath, 'MaskType');
blockName = get_param(plantBlockPath, 'Name');
registeredKeys = converterRegistry();

maskTypeMatches = strings(0,1);
nameMatches = strings(0,1);
for k = 1:numel(registeredKeys)
    candidateEntry = converterRegistry(registeredKeys(k));
    if isfield(candidateEntry, 'plantMaskType') && ...
            strlength(candidateEntry.plantMaskType) > 0 && ...
            strcmp(blockMaskType, candidateEntry.plantMaskType)
        maskTypeMatches(end+1) = registeredKeys(k); %#ok<AGROW>
    end
    if contains(blockName, candidateEntry.plantSubsystem)
        nameMatches(end+1) = registeredKeys(k); %#ok<AGROW>
    end
end

if isscalar(maskTypeMatches)
    converterKey = maskTypeMatches(1);
elseif isscalar(nameMatches)
    converterKey = nameMatches(1);
else
    error('applyPartToDeviceRole:converterNotResolved', ...
        ['Could not identify the converter from plant block "%s" (MaskType "%s"): ' ...
         '%d MaskType and %d name match(es). Pass ConverterKey="..." explicitly. ' ...
         'Registered: %s.'], ...
        blockName, blockMaskType, numel(maskTypeMatches), numel(nameMatches), ...
        strjoin(registeredKeys, ', '));
end
converterEntry = converterRegistry(converterKey);
end

% ======================================================================
function roleDescriptor = resolveRole(converterEntry, converterKey, deviceRole)
% Return the .parts entry for the device role.
if ~isfield(converterEntry, 'parts') || isempty(converterEntry.parts)
    error('applyPartToDeviceRole:noPartsDescriptor', ...
        ['converterRegistry("%s") has no .parts descriptor, so part selection is ' ...
         'not set up for this converter yet. Add a partRole() entry to its ' ...
         'registry case.'], converterKey);
end
availableRoles = string({converterEntry.parts.role});
roleIndex = find(availableRoles == deviceRole, 1);
if isempty(roleIndex)
    error('applyPartToDeviceRole:unknownDeviceRole', ...
        'Device role "%s" is not declared for converter "%s". Declared roles: %s.', ...
        deviceRole, converterKey, strjoin(availableRoles, ', '));
end
roleDescriptor = converterEntry.parts(roleIndex);
end

% ======================================================================
function [deviceBlocks, isOlderReleaseBlock] = findRoleDeviceBlocks(plantBlockPath, roleDescriptor, partId)
% Find the role's Simscape device blocks under its search roots, in all variants.
searchRoots = string(roleDescriptor.searchRoot);
searchRoots = searchRoots(strlength(searchRoots) > 0);
if isempty(searchRoots)
    searchRoots = "";        % the whole plant
end

candidateBlocks = {};
for rootIndex = 1:numel(searchRoots)
    if strlength(searchRoots(rootIndex)) > 0
        thisRoot = [plantBlockPath '/' char(searchRoots(rootIndex))];
    else
        thisRoot = plantBlockPath;
    end
    candidateBlocks = [candidateBlocks; find_system(thisRoot, ...
        'MatchFilter', @Simulink.match.allVariants, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', 'SimscapeBlock')]; %#ok<AGROW>
end

% A device of this role is a block that lists the part among the parts it takes. A block
% created in an earlier release lists no part while its library block lists this one.
deviceBlocks = {};
isOlderReleaseBlock = false(0, 1);
libraryListsPart = dictionary(string.empty, false(0));
appliesWorkaround = isOlderReleaseWorkaroundCase();
for k = 1:numel(candidateBlocks)
    blockParts = partrepo.collection.listDataSetsForBlock(candidateBlocks{k});
    if any(string(blockParts.PartId) == string(partId))
        deviceBlocks{end+1} = candidateBlocks{k}; %#ok<AGROW>
        isOlderReleaseBlock(end+1, 1) = false; %#ok<AGROW>
        continue
    end
    referenceBlock = string(get_param(candidateBlocks{k}, 'ReferenceBlock'));
    if height(blockParts) > 0 || referenceBlock == "" || ~appliesWorkaround
        continue
    end
    if ~isKey(libraryListsPart, referenceBlock)
        load_system(extractBefore(referenceBlock, "/"));
        libraryParts = partrepo.collection.listDataSetsForBlock(referenceBlock);
        libraryListsPart(referenceBlock) = any(string(libraryParts.PartId) == string(partId));
    end
    if libraryListsPart(referenceBlock)
        deviceBlocks{end+1} = candidateBlocks{k}; %#ok<AGROW>
        isOlderReleaseBlock(end+1, 1) = true; %#ok<AGROW>
    end
end
end

% ======================================================================
function applyPartDataSet(block, collectionId, partId)
% Apply a catalog part to a block. partrepo.collection.applyDataSet is available in R2026a,
% R2026b and R2027a. R2027a marks it for removal, so that one warning is turned off here.
warningState = warning('off', 'physmod:common:parts:mli:deprecation:WillBeRemoved');
restoreWarning = onCleanup(@() warning(warningState));
partrepo.collection.applyDataSet(block, collectionId, partId);
end

% ======================================================================
function appliesWorkaround = isOlderReleaseWorkaroundCase()
% True from R2026b, where the diode block changed. A diode block created in R2026a or
% earlier keeps its earlier definition when the model is saved in a later release, so it
% lists no catalog part and a part does not apply to it directly.
appliesWorkaround = ~isMATLABReleaseOlderThan("R2026b");
end

% ======================================================================
function applyToOlderReleaseBlock(deviceBlock, collectionId, partId)
% Apply the part to a block saved in an earlier release. The direct apply is tried first.
% When it fails, the part is applied to a new copy of the library block with the same
% component, and its parameter set, without the parameters this block does not have (for
% example Tvec_initial_Foster), is applied to the block.
try
    applyPartDataSet(deviceBlock, collectionId, partId);
    return
catch
    % Fall through to the parameter set.
end
scratchModel = "partParameterSet" + string(matlabProcessID);
new_system(scratchModel);
closeScratch = onCleanup(@() bdclose(scratchModel));
scratchBlock = scratchModel + "/Device";
add_block(get_param(deviceBlock, 'ReferenceBlock'), scratchBlock);
set_param(scratchBlock, 'SourceFile', get_param(deviceBlock, 'SourceFile'));
% The scratch block only carries the part's parameters, so its own warnings are not shown.
warningState = warning('off', 'physmod:simscape:parts:sli:blockDataSet:VisibleParamsNotSetModelingOption');
restoreWarning = onCleanup(@() warning(warningState));
applyPartDataSet(scratchBlock, collectionId, partId);
partDataSet = partrepo.simscape.dataSetFromBlock(scratchBlock);
blockParameterNames = string(fieldnames(get_param(deviceBlock, 'DialogParameters')));
for parameterName = string(partDataSet.Parameters.fieldNames)'
    if ~any(blockParameterNames == parameterName)
        partDataSet.Parameters = partDataSet.Parameters.removeField(parameterName);
    end
end
partDataSet.applyParams(deviceBlock);
end

% ======================================================================
function enforceDeviceGuardRails(deviceBlock)
% Set the thermal network and switching-loss options the plant needs.
dialogParameterNames = fieldnames(get_param(deviceBlock, 'DialogParameters'));

% Set the thermal network topology to external.
if any(strcmp(dialogParameterNames, 'thermal_network_parameterization'))
    set_param(deviceBlock, 'thermal_network_parameterization', ...
        'ee.enum.thermalNetworkTopology.external');
end

% Turn off the previous-cycle switching-loss options.
previousCycleParameters = {'useCurrentFromPreviousCycle', 'useVoltageFromPreviousCycle'};
for k = 1:numel(previousCycleParameters)
    if any(strcmp(dialogParameterNames, previousCycleParameters{k}))
        set_param(deviceBlock, previousCycleParameters{k}, 'false');
    end
end
end

% ======================================================================
function maskParameterSummary = writeIdealMaskParameters(plantBlockPath, ...
        representativeBlock, roleDescriptor, partRow, deriveFromCurve)
% Copy the ideal-fidelity values from the applied device to the plant mask.
maskHandle = Simulink.Mask.get(plantBlockPath);
maskParameterNames = fieldnames(roleDescriptor.idealParamMap);
deviceDialogNames = fieldnames(get_param(representativeBlock, 'DialogParameters'));

% Values fitted from the I-V table, computed on first need.
derivedValues = struct();

maskParameterName = strings(0,1); deviceParameterName = strings(0,1);
writtenValue = zeros(0,1); writtenUnit = strings(0,1); valueSource = strings(0,1);

for k = 1:numel(maskParameterNames)
    maskParameter = maskParameterNames{k};
    deviceParameter = roleDescriptor.idealParamMap.(maskParameter);

    maskParameterHandle = maskHandle.getParameter(maskParameter);
    if isempty(maskParameterHandle) || ~any(strcmp(deviceDialogNames, deviceParameter))
        maskParameterName(end+1,1) = maskParameter;            %#ok<AGROW>
        deviceParameterName(end+1,1) = string(deviceParameter);%#ok<AGROW>
        writtenValue(end+1,1) = NaN;                           %#ok<AGROW>
        writtenUnit(end+1,1) = "";                             %#ok<AGROW>
        valueSource(end+1,1) = "not written (parameter absent)"; %#ok<AGROW>
        continue
    end

    [numericValue, isSuppliedByPart] = readDeviceParameter(representativeBlock, deviceParameter);
    deviceUnit = get_param(representativeBlock, [deviceParameter '_unit']);
    source = "part data";

    if ~isSuppliedByPart
        % The part leaves this parameter unset, so fit it from the I-V table.
        if deriveFromCurve
            if isempty(fieldnames(derivedValues))
                derivedValues = deriveIdealFromForwardCurve(representativeBlock, partRow);
            end
            if isfield(derivedValues, deviceParameter)
                numericValue = derivedValues.(deviceParameter).value;
                deviceUnit = derivedValues.(deviceParameter).unit;
                source = "derived from part I-V table";
            else
                source = "not written (part supplies no value, none derivable)";
            end
        else
            source = "not written (part supplies no value)";
        end
    end

    if startsWith(source, "not written")
        maskParameterName(end+1,1) = maskParameter;             %#ok<AGROW>
        deviceParameterName(end+1,1) = string(deviceParameter); %#ok<AGROW>
        writtenValue(end+1,1) = NaN;                            %#ok<AGROW>
        writtenUnit(end+1,1) = "";                              %#ok<AGROW>
        valueSource(end+1,1) = source;                          %#ok<AGROW>
        continue
    end

    [maskValue, maskUnit] = matchMaskUnit(maskHandle, maskParameter, numericValue, deviceUnit);
    set_param(plantBlockPath, maskParameter, num2str(maskValue, '%.10g'));
    unitParameter = [maskParameter '_unit'];
    if ~isempty(maskHandle.getParameter(unitParameter))
        set_param(plantBlockPath, unitParameter, maskUnit);
    end

    maskParameterName(end+1,1) = maskParameter;             %#ok<AGROW>
    deviceParameterName(end+1,1) = string(deviceParameter); %#ok<AGROW>
    writtenValue(end+1,1) = maskValue;                      %#ok<AGROW>
    writtenUnit(end+1,1) = string(maskUnit);                %#ok<AGROW>
    valueSource(end+1,1) = source;                          %#ok<AGROW>
end

maskParameterSummary = table(maskParameterName, deviceParameterName, ...
    writtenValue, writtenUnit, valueSource, ...
    'VariableNames', {'MaskParameter','DeviceParameter','Value','Unit','Source'});
end

% ======================================================================
function [numericValue, isSuppliedByPart] = readDeviceParameter(deviceBlock, deviceParameter)
% Read a numeric device parameter and whether the part supplies it.
rawText = get_param(deviceBlock, deviceParameter);
isSuppliedByPart = ~contains(rawText, 'Parameter not set');
numericValue = str2double(strtrim(extractBefore([rawText '%'], '%')));
end

% ======================================================================
function derivedValues = deriveIdealFromForwardCurve(deviceBlock, partRow)
% Fit Vf and Ron to the part's forward I-V table with a least-squares line.
derivedValues = struct();
dialogParameterNames = fieldnames(get_param(deviceBlock, 'DialogParameters'));
if ~all(ismember({'VfVec','IfMat','TjVec'}, dialogParameterNames))
    return
end

forwardVoltage = evaluateAppliedVector(deviceBlock, 'VfVec');
forwardCurrent = evaluateAppliedVector(deviceBlock, 'IfMat');
junctionTemperature = evaluateAppliedVector(deviceBlock, 'TjVec');
if isempty(forwardVoltage) || isempty(forwardCurrent)
    return
end

% Orient IfMat along VfVec and take the column closest to 25 degC.
if ~isvector(forwardCurrent)
    if size(forwardCurrent,1) ~= numel(forwardVoltage) && size(forwardCurrent,2) == numel(forwardVoltage)
        forwardCurrent = forwardCurrent.';
    end
    if size(forwardCurrent,1) ~= numel(forwardVoltage)
        return
    end
    if numel(junctionTemperature) == size(forwardCurrent,2)
        [~, temperatureColumn] = min(abs(junctionTemperature - 25));
    else
        temperatureColumn = 1;
    end
    forwardCurrent = forwardCurrent(:, temperatureColumn);
end
forwardVoltage = forwardVoltage(:);
forwardCurrent = forwardCurrent(:);
if numel(forwardVoltage) ~= numel(forwardCurrent) || numel(forwardVoltage) < 2
    return
end

% Fit only up to the rated current, when known.
fitMask = true(size(forwardCurrent));
if ismember('CurrentRating', partRow.Properties.VariableNames)
    ratedCurrent = double(partRow.CurrentRating);
    if isfinite(ratedCurrent) && ratedCurrent > 0 && sum(forwardCurrent <= ratedCurrent) >= 2
        fitMask = forwardCurrent <= ratedCurrent;
    end
end
lineCoefficients = [ones(sum(fitMask),1), forwardCurrent(fitMask)] \ forwardVoltage(fitMask);

% Clip a negative intercept or slope to zero.
derivedValues.Vf  = struct('value', max(lineCoefficients(1), 0), ...
    'unit', get_param(deviceBlock, 'VfVec_unit'));
derivedValues.Ron = struct('value', max(lineCoefficients(2), 0), ...
    'unit', [get_param(deviceBlock, 'VfVec_unit') '/' get_param(deviceBlock, 'IfMat_unit')]);
end

% ======================================================================
function values = evaluateAppliedVector(deviceBlock, deviceParameter)
% Read a numeric vector or matrix device parameter.
rawText = get_param(deviceBlock, deviceParameter);
values = str2num(strtrim(extractBefore([rawText '%'], '%'))); %#ok<ST2NM>
end

% ======================================================================
function [maskValue, maskUnit] = matchMaskUnit(maskHandle, maskParameter, ...
        numericValue, deviceUnit)
% Use the device unit if the mask offers it, else convert to the mask unit.
maskValue = numericValue;
maskUnit = deviceUnit;

unitParameterHandle = maskHandle.getParameter([maskParameter '_unit']);
if isempty(unitParameterHandle)
    return
end
offeredUnits = string(unitParameterHandle.TypeOptions);
if any(offeredUnits == string(deviceUnit))
    return
end

maskUnit = unitParameterHandle.Value;
maskValue = simscape.Value(numericValue, deviceUnit).convert(maskUnit).value;
end
