function deviceInfo = getCLLCDeviceBlocks(blockPath, deviceKey)
%GETCLLCDEVICEBLOCKS Paths of the semiconductor blocks inside one CLLC device variant.
%   DEVICEINFO = getCLLCDeviceBlocks(BLOCKPATH, DEVICEKEY) returns, for the masked CLLC
%   plant block BLOCKPATH, a struct describing one device variant branch:
%
%     .bridgePath   the full-bridge variant subsystem holding the branch
%     .branchPath   the variant branch subsystem
%     .sourcePath   the representative device, that is, the one the "Open the MOSFET
%                   block mask" button opens and the one the "Apply parameters ..."
%                   button copies FROM
%     .targetPaths  the sibling devices the "Apply parameters ..." button copies TO
%
%   Valid DEVICEKEY values:
%     'primaryThermalMOSFET'      'secondaryThermalMOSFET'
%
%   The plant mask's four device pushbutton callbacks resolve their paths here. Spelled
%   out in the mask itself they drift: all four named the bridge as a direct child of the
%   plant block and went dead when the top-level Simplified/Detailed variant layer was
%   added above it.
%
%   The bridge comes from getCLLCBridgePath, which searches for it rather than assuming a
%   variant child name, so the same drift cannot happen again. Only the thermal MOSFET
%   branches are listed, because only they have buttons: the mask exposes every parameter
%   of the Ideal Switch branch, while the thermal MOSFET carries datasheet parameters it
%   does not. Adding a branch is one more case below.
%
%   The branch NAME here and the variant CHOICE label in selectCLLCPrimaryMOSFET /
%   selectCLLCSecondaryMOSFET are two spellings of the same branch - 'Ideal MOSFET with
%   Thermal' against 'IdealMOSFETwithThermal'. To rename the branch, change both.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    deviceKey (1,:) char
end

% Both bridges are full bridges of four MOSFETs with the same block names, so only the
% bridge and the branch differ between the keys.
switch deviceKey
    case 'primaryThermalMOSFET'
        bridgeName = 'Primary Converter Full Bridge';
        branchName = 'Ideal MOSFET with Thermal';

    case 'secondaryThermalMOSFET'
        bridgeName = 'Secondary Converter Full Bridge';
        branchName = 'Ideal MOSFET with Thermal';

    otherwise
        error('getCLLCDeviceBlocks:unknownDeviceKey', ...
            'Unknown device key ''%s''.', deviceKey);
end

deviceInfo.bridgePath  = getCLLCBridgePath(blockPath, bridgeName);
deviceInfo.branchPath  = [deviceInfo.bridgePath '/' branchName];
deviceInfo.sourceName  = 'MOSFETA1';
deviceInfo.targetNames = {'MOSFETA2', 'MOSFETB1', 'MOSFETB2'};

deviceInfo.sourcePath  = [deviceInfo.branchPath '/' deviceInfo.sourceName];
deviceInfo.targetPaths = cellfun(@(name) [deviceInfo.branchPath '/' name], ...
    deviceInfo.targetNames, 'UniformOutput', false);

end
