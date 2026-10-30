function issues = enforceSwitchingLossVoltageTables(deviceBlocks, options)
%ENFORCESWITCHINGLOSSVOLTAGETABLES Tabulate switching energy against off-state voltage.
%   ISSUES = enforceSwitchingLossVoltageTables(DEVICEBLOCKS) selects "Tabulate with
%   off-state voltage" (tabulateWithVds) on every device block in DEVICEBLOCKS whose 3-D
%   switching-energy tables carry data, so each switching energy is read from the table at
%   the actual off-state voltage.
%
%   ISSUES = enforceSwitchingLossVoltageTables(DEVICEBLOCKS, OnIssue="warn") reports them
%   and writes nothing.
%
%   With the option cleared, the device reads the 2-D tables and scales each energy by the
%   off-state voltage over "Off-state voltage for losses data" (Voff). A catalog part data
%   set writes the 2-D tables from one voltage slice of the part data, clears the option
%   and leaves Voff at the library default, so every switching energy is scaled by the
%   wrong ratio.
%
%   Inputs:
%     deviceBlocks  Block path, handle, or cell array of either, naming Simscape device
%                   blocks.
%
%   Name-value options:
%     OnIssue  "correct" to select the 3-D tables, "warn" to report and write nothing.
%              Default "correct".
%
%   Outputs:
%     issues  0x1 struct array when nothing is found, otherwise one element per device:
%               deviceBlock   Full path of the device block.
%               voltageAxis   Off-state voltages of the 3-D tables, in V.
%               message       One sentence naming the setting and the correction.
%               wasCorrected  true when this call selected the 3-D tables.
%
%   Example:
%     enforceSwitchingLossVoltageTables(mosfetBlock);
%
%   See also applyPartToDeviceRole, enforceIntegralDiodeSettings.

% Copyright 2026 The MathWorks, Inc.

arguments
    deviceBlocks
    options.OnIssue (1,1) string {mustBeMember(options.OnIssue, ["correct" "warn"])} = "correct"
end

deviceBlocks = normalizeBlockList(deviceBlocks);
issues = reshape(struct('deviceBlock', {}, 'voltageAxis', {}, 'message', {}, ...
    'wasCorrected', {}), 0, 1);

energyTables3D = {'Eon_data_3D', 'Eoff_data_3D'};
voltageAxisName = 'Vds_loss';

for blockIndex = 1:numel(deviceBlocks)
    deviceBlock = getfullname(get_param(deviceBlocks{blockIndex}, 'Handle'));
    dialogParameterNames = fieldnames(get_param(deviceBlock, 'DialogParameters'));
    if ~all(ismember([{'tabulateWithVds', voltageAxisName}, energyTables3D], dialogParameterNames))
        continue        % Not a device that tabulates switching energy against voltage.
    end
    if ~strcmpi(bareParameterValue(deviceBlock, 'tabulateWithVds'), 'false')
        continue        % Already reads the 3-D tables.
    end

    % The 3-D tables need data at a positive off-state voltage to be worth selecting
    voltageAxis = evaluateBareParameter(deviceBlock, voltageAxisName);
    hasVoltageData = ~isempty(voltageAxis);
    for tableIndex = 1:numel(energyTables3D)
        energy3D = evaluateBareParameter(deviceBlock, energyTables3D{tableIndex});
        hasVoltageData = hasVoltageData && size(energy3D, 3) == numel(voltageAxis) && ...
            any(energy3D(:, :, voltageAxis > 0), 'all');
    end
    if ~hasVoltageData
        continue        % Default or workspace-resolved tables; nothing to prove a switch with.
    end

    message = sprintf(['The switching energies are scaled from the 2-D tables by the ' ...
        'off-state voltage over "Off-state voltage for losses data" (%s V), while the part ' ...
        'data tabulates them at %s V. Select "Tabulate with off-state voltage".'], ...
        bareParameterValue(deviceBlock, 'Voff'), mat2str(voltageAxis(voltageAxis > 0)));

    wasCorrected = options.OnIssue == "correct";
    if wasCorrected
        set_param(deviceBlock, 'tabulateWithVds', 'true');
    else
        warning('enforceSwitchingLossVoltageTables:voltageTables', '%s\n         Device: %s', ...
            message, deviceBlock);
    end
    issues(end+1, 1) = struct('deviceBlock', deviceBlock, 'voltageAxis', voltageAxis, ...
        'message', string(message), 'wasCorrected', wasCorrected); %#ok<AGROW>
end
end

% ======================================================================
function bareText = bareParameterValue(deviceBlock, parameterName)
% A value written by a catalog part data set carries a provenance comment
% ("300 % Parameter not set"), so the comment comes off before any comparison.
bareText = strtrim(char(extractBefore(string(get_param(deviceBlock, parameterName)) + "%", "%")));
end

% ======================================================================
function values = evaluateBareParameter(deviceBlock, parameterName)
% Evaluate a numeric parameter. An applied value is a literal or a reshape() expression,
% so str2num covers both; a workspace variable gives empty, read as "cannot tell".
values = str2num(bareParameterValue(deviceBlock, parameterName)); %#ok<ST2NM>
end

% ======================================================================
function blockList = normalizeBlockList(deviceBlocks)
% Accept a single path or handle, a string array, or a cell array of either.
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
