function issues = getIntegralDiodeSettingIssues(deviceBlocks)
%GETINTEGRALDIODESETTINGISSUES Find device diode settings a converter plant cannot honor.
%   ISSUES = getIntegralDiodeSettingIssues(DEVICEBLOCKS) inspects each Simscape device
%   block in DEVICEBLOCKS and returns one struct element per setting that the plant cannot
%   honor. DEVICEBLOCKS is a block path, a block handle, or a cell array of either.
%   Nothing is written; this is the single place both rules are defined, and
%   enforceIntegralDiodeSettings turns each issue into either a correction or a warning.
%
%   Three rules are checked. Each is skipped on a device whose dialog does not offer the
%   parameter, so the same routine serves MOSFETs, diodes and thyristors.
%
%   Separate thermal port for the integral diode. A converter plant wires one thermal
%   port per device and drives junction temperature from its own simulation temperature.
%   A MOSFET asked for a second thermal port therefore grows a conserving port with
%   nothing connected to it, and the integral diode no longer shares the device
%   temperature. The port count changes silently and the model still compiles, so the
%   setting is checked rather than discovered later.
%
%   Reverse recovery loss model against the table behind it. A tabulated loss model whose
%   table holds only zeros returns zero loss at every operating point, which is what the
%   fixed model already expresses without the lookup. Catalog part data sets select the
%   tabulated model whenever the manufacturer file carries a recovery-loss table at all,
%   including an all-zero one. Both the MOSFET integral diode (diode_ prefixed
%   parameters) and the standalone diode (unprefixed) are checked, because the parameters
%   have the same shape and the same rule applies to both.
%
%   Reverse recovery loss scaling on a fixed zero loss. A fixed loss model with a zero loss
%   keeps "Scale reverse recovery loss with current and voltage" cleared. Catalog part
%   data sets select the check box with the fixed model.
%
%   Inputs:
%     deviceBlocks  Block path, handle, or cell array of either, naming Simscape device
%                   blocks.
%
%   Outputs:
%     issues  0x1 struct array when nothing is found, otherwise one element per issue:
%               deviceBlock     Full path of the device block.
%               issueKind       "separateThermalPort", "zeroRecoveryLossTable" or
%                               "scaledZeroRecoveryLoss".
%               parameterName   Dialog parameter that holds the setting.
%               currentValue    Its present value, provenance comment removed.
%               writes          Struct array of Name and Value pairs that correct it.
%                               Empty when the correction would delete a connected port.
%               message         One sentence naming the setting and the correction.
%
%   Example:
%     issues = getIntegralDiodeSettingIssues('MyModel/Plant/Bridge/MOSFETA1');
%     fprintf('%s\n', issues.message);
%
%   See also enforceIntegralDiodeSettings, applyPartToDeviceRole, applyConverterPart.

% Copyright 2026 The MathWorks, Inc.

arguments
    deviceBlocks
end

deviceBlocks = normalizeBlockList(deviceBlocks);
issues = emptyIssueStruct();

for blockIndex = 1:numel(deviceBlocks)
    deviceBlock = deviceBlocks{blockIndex};
    dialogParameterNames = fieldnames(get_param(deviceBlock, 'DialogParameters'));

    issues = [issues; checkSeparateThermalPort(deviceBlock, dialogParameterNames)]; %#ok<AGROW>
    issues = [issues; checkRecoveryLossTable(deviceBlock, dialogParameterNames)];   %#ok<AGROW>
end

end

% ======================================================================
function issues = checkSeparateThermalPort(deviceBlock, dialogParameterNames)
% The integral diode must share the device's single thermal port.
issues = emptyIssueStruct();
parameterName = 'separateThermalPortForDiode';
if ~any(strcmp(dialogParameterNames, parameterName))
    return
end

currentValue = bareParameterValue(deviceBlock, parameterName);
if ~strcmpi(currentValue, 'true')
    return
end

% Clearing the option deletes the extra conserving port. Refuse to write when something
% is connected to it, so a plant that does wire a second thermal port keeps its line and
% you are told instead.
if isExtraThermalPortConnected(deviceBlock)
    writes = emptyWriteStruct();
    message = ['The integral diode has its own thermal port and something is connected ' ...
        'to it. A converter plant drives one thermal port per device, so clear ' ...
        '"Separate thermal port for integral diode" and remove that connection.'];
else
    writes = struct('Name', {parameterName}, 'Value', {'false'});
    message = ['The integral diode has its own thermal port, which is left unconnected ' ...
        'because a converter plant wires one thermal port per device. Clear ' ...
        '"Separate thermal port for integral diode".'];
end

issues = makeIssue(deviceBlock, "separateThermalPort", parameterName, currentValue, ...
    writes, message);
end

% ======================================================================
function issues = checkRecoveryLossTable(deviceBlock, dialogParameterNames)
% A tabulated reverse recovery loss model has to have a table with something in it.
issues = emptyIssueStruct();

% The MOSFET names its integral diode's parameters with a diode_ prefix; a standalone
% diode has no prefix. The 3-D table is the one name that does not take the
% underscore on the MOSFET: diodeErecMat3D, not diode_ErecMat3D.
parameterSets = { ...
    struct('model', 'diode_rec_loss_model', 'table2D', 'diode_ErecMat', ...
           'table3D', 'diodeErecMat3D', 'scale', 'diode_scaleWithIandV', ...
           'fixedLoss', 'diode_ErecVal'), ...
    struct('model', 'rec_loss_model', 'table2D', 'ErecMat', ...
           'table3D', 'ErecMat3D', 'scale', 'scaleWithIandV', ...
           'fixedLoss', 'ErecVal')};

for setIndex = 1:numel(parameterSets)
    parameterSet = parameterSets{setIndex};
    if ~any(strcmp(dialogParameterNames, parameterSet.model))
        continue
    end

    currentValue = bareParameterValue(deviceBlock, parameterSet.model);
    selectedModel = enumMemberName(currentValue);
    switch selectedModel
        case "tabulated2d"
            tableParameter = parameterSet.table2D;
        case "tabulated3d"
            tableParameter = parameterSet.table3D;
        case "fixed"
            issues = [issues; checkScaledZeroRecoveryLoss(deviceBlock, ...
                dialogParameterNames, parameterSet)]; %#ok<AGROW>
            continue
        otherwise
            continue
    end
    if ~any(strcmp(dialogParameterNames, tableParameter))
        continue
    end

    tableValues = evaluateBareParameter(deviceBlock, tableParameter);
    if isempty(tableValues) || ~all(tableValues(:) == 0)
        continue            % A table with data in it, or one this cannot read.
    end

    % The enum class differs between devices that tabulate up to 2-D and up to 3-D, so
    % the member is swapped inside whatever class the block already names.
    writes = struct('Name', {parameterSet.model}, 'Value', {fixedModelValue(currentValue)});
    if any(strcmp(dialogParameterNames, parameterSet.scale))
        writes(end+1) = struct('Name', parameterSet.scale, 'Value', 'false'); %#ok<AGROW>
    end

    message = sprintf(['"Reverse recovery loss model" is %s but "%s" holds only zeros, ' ...
        'so the lookup returns zero loss at every operating point. Set the loss model ' ...
        'to fixed and clear "Scale reverse recovery loss with current and voltage", or ' ...
        'enter the datasheet recovery loss.'], selectedModel, tableParameter);

    issues = [issues; makeIssue(deviceBlock, "zeroRecoveryLossTable", ...
        parameterSet.model, currentValue, writes, message)]; %#ok<AGROW>
end
end

% ======================================================================
function issues = checkScaledZeroRecoveryLoss(deviceBlock, dialogParameterNames, parameterSet)
% A fixed reverse recovery loss of zero keeps the scale check box cleared.
issues = emptyIssueStruct();
if ~all(ismember({parameterSet.scale, parameterSet.fixedLoss}, dialogParameterNames))
    return
end
scaleValue = bareParameterValue(deviceBlock, parameterSet.scale);
if ~any(strcmpi(scaleValue, {'true', 'on', '1'}))
    return
end
fixedLoss = evaluateBareParameter(deviceBlock, parameterSet.fixedLoss);
if isempty(fixedLoss) || ~all(fixedLoss(:) == 0)
    return
end
writes = struct('Name', parameterSet.scale, 'Value', 'false');
message = ['"Reverse recovery loss model" is fixed at zero loss. Clear ' ...
    '"Scale reverse recovery loss with current and voltage".'];
issues = makeIssue(deviceBlock, "scaledZeroRecoveryLoss", parameterSet.scale, ...
    scaleValue, writes, message);
end

% ======================================================================
function isConnected = isExtraThermalPortConnected(deviceBlock)
% The integral diode's separate thermal port is the highest-numbered RConn port: the
% MOSFET carries LConn1, LConn2, RConn1 and RConn2 with the option cleared, and gains
% RConn3 with it set. When the ports cannot be read, report connected, so the caller
% warns instead of deleting something.
isConnected = true;
try
    portConnectivity = get_param(deviceBlock, 'PortConnectivity');
catch
    return
end

highestPortNumber = -1;
highestPortIndex = 0;
for portIndex = 1:numel(portConnectivity)
    portType = string(portConnectivity(portIndex).Type);
    if ~startsWith(portType, "RConn")
        continue
    end
    portNumber = str2double(extractAfter(portType, "RConn"));
    if isnan(portNumber)
        return
    end
    if portNumber > highestPortNumber
        highestPortNumber = portNumber;
        highestPortIndex = portIndex;
    end
end
if highestPortIndex == 0
    return
end

isConnected = ~isempty(portConnectivity(highestPortIndex).SrcBlock) || ...
    ~isempty(portConnectivity(highestPortIndex).DstBlock);
end

% ======================================================================
function fixedValue = fixedModelValue(currentValue)
% Keep the enum class the block already names and swap the member to fixed. Both
% ee.enum.diode.reverseRecoveryModel and
% ee.enum.diode.reverseRecoveryModelTabulateUpTo3D declare a fixed member, and which of
% the two a device uses depends on whether it tabulates up to 3-D.
dotPositions = strfind(currentValue, '.');
if isempty(dotPositions)
    fixedValue = 'ee.enum.diode.reverseRecoveryModel.fixed';
else
    fixedValue = [currentValue(1:dotPositions(end)) 'fixed'];
end
end

% ======================================================================
function memberName = enumMemberName(enumValueText)
% Last dotted token of an enum value, so ...reverseRecoveryModel.fixed gives "fixed".
parts = split(string(enumValueText), ".");
memberName = parts(end);
end

% ======================================================================
function bareText = bareParameterValue(deviceBlock, parameterName)
% A value written by a catalog part data set carries a provenance comment -
% "true % Datasheet derived", "zeros(2, 3) % Parameter not set" - so the comment comes
% off before any comparison.
bareText = strtrim(char(extractBefore(string(get_param(deviceBlock, parameterName)) + "%", "%")));
end

% ======================================================================
function values = evaluateBareParameter(deviceBlock, parameterName)
% Evaluate a table parameter. A library default is an expression ("zeros(2, 3)") and an
% applied value is a numeric literal, so str2num covers both. A value that resolves
% through a workspace variable gives empty, which the caller reads as "cannot tell".
values = str2num(bareParameterValue(deviceBlock, parameterName)); %#ok<ST2NM>
end

% ======================================================================
function issue = makeIssue(deviceBlock, issueKind, parameterName, currentValue, writes, message)
% writes is wrapped in a cell on purpose: struct() given a bare struct array would size
% the result by that array instead of storing it in one field.
issue = struct( ...
    'deviceBlock',   getfullname(get_param(deviceBlock, 'Handle')), ...
    'issueKind',     issueKind, ...
    'parameterName', parameterName, ...
    'currentValue',  string(currentValue), ...
    'writes',        {writes}, ...
    'message',       string(message));
end

% ======================================================================
function issues = emptyIssueStruct()
issues = struct('deviceBlock', {}, 'issueKind', {}, 'parameterName', {}, ...
    'currentValue', {}, 'writes', {}, 'message', {});
issues = reshape(issues, 0, 1);
end

% ======================================================================
function writes = emptyWriteStruct()
writes = struct('Name', {}, 'Value', {});
end

% ======================================================================
function blockList = normalizeBlockList(deviceBlocks)
% Accept a single path or handle, a string array, or a cell array of either. A char row
% vector is one path: indexing it as a column would give one entry per character.
if iscell(deviceBlocks)
    blockList = deviceBlocks(:);
elseif ischar(deviceBlocks)
    blockList = {deviceBlocks};
elseif isstring(deviceBlocks)
    blockList = cellstr(deviceBlocks(:));
else
    blockList = num2cell(deviceBlocks(:));
end
end
