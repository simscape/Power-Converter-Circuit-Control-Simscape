function deviceBlockPath = openLLCDeviceModel(llcPlantPath, options)
%OPENLLCDEVICEMODEL Open the dialog of the active primary or secondary device.
%   deviceBlockPath = OPENLLCDEVICEMODEL(llcPlantPath) opens the block dialog of
%   the primary-side switching device that is currently active inside the masked
%   LLC converter plant block, and returns its full block path.
%
%   deviceBlockPath = OPENLLCDEVICEMODEL(llcPlantPath, Device="secondary") does
%   the same for the secondary-side rectifier diode.
%
%   The masked LLC plant block selects its power stage through nested variant
%   subsystems (model option, primary bridge option, device fidelity, rectifier
%   option), so the device block path is not fixed. This function resolves the
%   active choice at every variant level from the label-mode variant control, so
%   it returns the device that will actually simulate, whatever the mask is set to.
%
%   Inputs:
%     llcPlantPath    String. Path to the masked LLC converter plant block,
%                     for example "LLCResonantConverterFullBridge/LLC Converter Power Circuit".
%     options         Structure with the following optional field:
%       .Device         Char. Which device to open. Must be one of:
%                        - 'primary'   (default) primary-side MOSFET / ideal switch
%                        - 'secondary'           secondary-side rectifier diode
%
%   Example:
%     plantPath = strcat(bdroot,"/LLC Converter Power Circuit");
%     openLLCDeviceModel(plantPath, Device="primary");

% Copyright 2026 The MathWorks, Inc.

arguments
    llcPlantPath (1,1) string
    options.Device (1,:) char {mustBeMember(options.Device, {'primary','secondary'})} = 'primary'
end

load_system(bdroot(llcPlantPath));

% Where to start searching, and what the device leaf blocks are called. The
% detailed inverter names its switches MOSFETA1..B2; the simplified (averaged)
% inverter names them Switch/Switch1. The rectifier always names its devices
% Diode1..Diode4, so the secondary search must start below the rectifier to
% avoid matching the simplified inverter's freewheeling diodes.
switch options.Device
    case 'primary'
        searchRoot      = llcPlantPath + "/LLC Primary Inverter and Resonant Tank";
        deviceLeafNames = ["MOSFETA1", "Switch"];
        deviceLabel     = "primary switching device";
    case 'secondary'
        searchRoot      = llcPlantPath + "/Rectifier";
        deviceLeafNames = "Diode1";
        deviceLabel     = "secondary rectifier diode";
end

deviceBlockPath = findActiveDeviceBlock(searchRoot, deviceLeafNames);

if strlength(deviceBlockPath) == 0
    error('openLLCDeviceModel:deviceNotFound', ...
        'Could not find an active %s (%s) under "%s".', ...
        deviceLabel, strjoin(deviceLeafNames, ', '), searchRoot);
end

open_system(deviceBlockPath);
end

% ======================================================================
function deviceBlockPath = findActiveDeviceBlock(searchRoot, deviceLeafNames)
% Depth-first search from searchRoot for the first block whose name is in
% deviceLeafNames, descending into a variant subsystem's ACTIVE choice only.
%
% This deliberately does not use find_system with @Simulink.match.activeVariants:
% that filter reports the last COMPILED active choice, which is stale straight
% after a mask popup change and would open a device that is no longer in circuit.

deviceBlockPath = "";

% The search root itself may be a variant subsystem (the plant's model-option
% level is one), so resolve it to its active choice before descending.
if strcmp(get_param(searchRoot, 'BlockType'), 'SubSystem') && ...
        strcmp(get_param(searchRoot, 'Variant'), 'on')
    searchRoot = activeVariantChoiceBlock(searchRoot);
    if strlength(searchRoot) == 0
        return
    end
end

childBlocks = find_system(searchRoot, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'MatchFilter', @Simulink.match.allVariants, 'Type', 'block');

for blockIndex = 1:numel(childBlocks)
    childBlock = string(childBlocks{blockIndex});
    if childBlock == searchRoot
        continue    % find_system returns the search root itself
    end

    if any(get_param(childBlock, 'Name') == deviceLeafNames)
        deviceBlockPath = childBlock;
        return
    end

    if ~strcmp(get_param(childBlock, 'BlockType'), 'SubSystem')
        continue
    end

    % Recurse. A variant subsystem is narrowed to its active choice on entry.
    deviceBlockPath = findActiveDeviceBlock(childBlock, deviceLeafNames);

    if strlength(deviceBlockPath) > 0
        return
    end
end
end

% ======================================================================
function activeChoice = activeVariantChoiceBlock(variantSubsystemPath)
% The choice block of a label-mode variant subsystem that is active right now.
% Reads LabelModeActiveChoice (updated immediately by the mask initialization)
% and matches it against each choice block's VariantControl label.

activeChoice = "";

activeLabel = string(get_param(variantSubsystemPath, 'LabelModeActiveChoice'));
if strlength(activeLabel) == 0
    return
end

choiceBlocks = find_system(variantSubsystemPath, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'SubSystem');

for choiceIndex = 1:numel(choiceBlocks)
    choiceBlock = string(choiceBlocks{choiceIndex});
    if choiceBlock == string(variantSubsystemPath)
        continue
    end
    if string(get_param(choiceBlock, 'VariantControl')) == activeLabel
        activeChoice = choiceBlock;
        return
    end
end
end
