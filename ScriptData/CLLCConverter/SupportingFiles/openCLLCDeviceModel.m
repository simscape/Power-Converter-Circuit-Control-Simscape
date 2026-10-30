function deviceBlockPath = openCLLCDeviceModel(cllcPlantPath, options)
%OPENCLLCDEVICEMODEL Open the dialog of the active primary or secondary device.
%   deviceBlockPath = OPENCLLCDEVICEMODEL(cllcPlantPath) opens the block dialog of
%   the primary-side switching device that is currently active inside the masked
%   CLLC converter plant block, and returns its full block path.
%
%   deviceBlockPath = OPENCLLCDEVICEMODEL(cllcPlantPath, Device="secondary") does
%   the same for the secondary-side switching device.
%
%   The masked CLLC plant block selects its power stage through nested variant
%   subsystems (model option, then device fidelity on each bridge), so the device
%   block path is not fixed. This function resolves the active choice at every
%   variant level from the label-mode variant control, so it returns the device
%   that simulates, whatever the mask is set to.
%
%   Both bridges of the CLLC converter name their switches MOSFETA1..B2, so the
%   search starts below the requested side, or it always returns the
%   primary device.
%
%   Inputs:
%     cllcPlantPath   String. Path to the masked CLLC converter plant block,
%                     for example "CLLCResonantConverter/CLLC Converter Power Circuit".
%     options         Structure with the following optional field:
%       .Device         Char. Which device to open. Must be one of:
%                        - 'primary'   (default) primary-side bridge switch
%                        - 'secondary'           secondary-side bridge switch
%
%   Example:
%     plantPath = strcat(bdroot,"/CLLC Converter Power Circuit");
%     openCLLCDeviceModel(plantPath, Device="primary");
%
%   See also openLLCDeviceModel.

% Copyright 2026 The MathWorks, Inc.

arguments
    cllcPlantPath (1,1) string
    options.Device (1,:) char {mustBeMember(options.Device, {'primary','secondary'})} = 'primary'
end

load_system(bdroot(cllcPlantPath));

% The model-option variant (Simplified / Detailed) sits directly under the mask, and both of its
% choices carry a Primary Converter and a Secondary Converter, so it has to be resolved before the
% side can be appended to the search root.
modelOptionVariantPath = cllcPlantPath + "/CLLCConverterVariant";
activeModelOptionBlock = activeVariantChoiceBlock(modelOptionVariantPath);

if strlength(activeModelOptionBlock) == 0
    error('openCLLCDeviceModel:modelOptionNotResolved', ...
        'Could not resolve the active model option of "%s".', modelOptionVariantPath);
end

% Where to start searching, and what the device leaf blocks are called. Every bridge choice, on both
% sides and under both model options, names its switches MOSFETA1..B2, so one leaf name covers all of
% them; the enclosing bridge variant is what decides ideal switch versus thermal MOSFET.
switch options.Device
    case 'primary'
        searchRoot  = activeModelOptionBlock + "/Primary Converter";
        deviceLabel = "primary bridge switching device";
    case 'secondary'
        searchRoot  = activeModelOptionBlock + "/Secondary Converter";
        deviceLabel = "secondary bridge switching device";
end
deviceLeafNames = "MOSFETA1";

deviceBlockPath = findActiveDeviceBlock(searchRoot, deviceLeafNames);

if strlength(deviceBlockPath) == 0
    error('openCLLCDeviceModel:deviceNotFound', ...
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
% This does not use find_system with @Simulink.match.activeVariants:
% that filter reports the last COMPILED active choice, which is stale straight
% after a mask popup change and would open a device that is no longer in circuit.

deviceBlockPath = "";

% The search root itself may be a variant subsystem, so resolve it to its active
% choice before descending.
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
