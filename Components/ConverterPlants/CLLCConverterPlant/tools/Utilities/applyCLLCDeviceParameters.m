function numberApplied = applyCLLCDeviceParameters(blockPath, deviceKey)
%APPLYCLLCDEVICEPARAMS Copy one CLLC device's dialog parameters to its siblings.
%   NUMBERAPPLIED = applyCLLCDeviceParameters(BLOCKPATH, DEVICEKEY) copies every dialog
%   parameter of the representative device of variant branch DEVICEKEY onto its sibling
%   devices. Datasheet values typed into one MOSFET need not be repeated on the other
%   three of the bridge. See getCLLCDeviceBlocks for the valid keys.
%
%   Parameters the plant mask drives are copied as their expression, not their value.
%   get_param returns 'PrimarySimTemp_K', not '298.15'. The sibling therefore stays wired
%   to the mask instead of a fixed value.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    deviceKey (1,:) char
end

deviceInfo = getCLLCDeviceBlocks(blockPath, deviceKey);

if getSimulinkBlockHandle(deviceInfo.sourcePath) <= 0
    load_system(bdroot(blockPath));
end
if getSimulinkBlockHandle(deviceInfo.sourcePath) <= 0
    error('applyCLLCDeviceParameters:missingDevice', ...
        ['Cannot find the %s source device block.\n' ...
         'Expected it at:\n  %s\n' ...
         'Update the paths in getCLLCDeviceBlocks.m, which is the single place they are ' ...
         'defined.'], deviceKey, deviceInfo.sourcePath);
end

sourceParameterNames = fieldnames(get_param(deviceInfo.sourcePath, 'DialogParameters'));

numberApplied = 0;
for targetIndex = 1:numel(deviceInfo.targetPaths)
    targetPath = deviceInfo.targetPaths{targetIndex};
    try
        for parameterIndex = 1:numel(sourceParameterNames)
            parameterName = sourceParameterNames{parameterIndex};
            set_param(targetPath, parameterName, ...
                get_param(deviceInfo.sourcePath, parameterName));
        end
        numberApplied = numberApplied + 1;
    catch applyError
        warning('applyCLLCDeviceParameters:applyFailed', ...
            'Failed to apply parameters to %s: %s', targetPath, applyError.message);
    end
end

fprintf('Applied %s parameters from %s to %d other device block(s).\n', ...
    deviceKey, deviceInfo.sourceName, numberApplied);

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source device, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(deviceInfo.sourcePath, OnIssue="warn");

end
