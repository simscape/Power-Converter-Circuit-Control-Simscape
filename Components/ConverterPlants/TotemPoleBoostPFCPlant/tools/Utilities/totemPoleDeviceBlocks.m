function deviceInfo = totemPoleDeviceBlocks(blockPath, deviceKey)
%TOTEMPOLEDEVICEBLOCKS Paths of the semiconductor blocks inside one device variant.
%   DEVICEINFO = totemPoleDeviceBlocks(BLOCKPATH, DEVICEKEY) returns, for the masked
%   totem-pole plant block BLOCKPATH, a struct describing one device variant branch:
%
%     .branchPath   the variant branch subsystem
%     .sourcePath   the representative device, that is, the one the "Open ... block mask"
%                   button opens and the one the "Apply ..." button copies FROM
%     .targetPaths  the sibling devices the "Apply ..." button copies TO
%
%   Valid DEVICEKEY values:
%     'fastIdealSwitch'      'fastThermalMOSFET'
%     'slowIdealSwitch'      'slowThermalMOSFET'
%     'slowIdealDiode'       'slowTabulatedDiode'      'slowThyristor'
%     'simplified'
%
%   The six mask button callbacks and the three apply functions all resolve their paths
%   here. Spelled out separately they drift, and the slow-leg copies had gone stale.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    deviceKey (1,:) char
end

% Everything hangs off the Detailed branch of the top-level model-option variant. Note
% the slow leg has one more level than the fast leg: SlowLeg/MOSFET and SlowLeg/Diode
% are themselves label-mode variant subsystems.
detailedPath   = [blockPath '/TotemPoleBoostPFCVariant/DetailedModel'];
simplifiedPath = [blockPath '/TotemPoleBoostPFCVariant/SimplifiedModel'];

switch deviceKey
    case 'fastIdealSwitch'
        deviceInfo.branchPath  = [detailedPath '/FastLeg/IdealSwitch'];
        deviceInfo.sourceName  = 'SwitchHigh';
        deviceInfo.targetNames = {'SwitchLow'};

    case 'fastThermalMOSFET'
        deviceInfo.branchPath  = [detailedPath '/FastLeg/SwitchingMOSFETwithThermal'];
        deviceInfo.sourceName  = 'MOSFETHigh';
        deviceInfo.targetNames = {'MOSFETLow'};

    case 'slowIdealSwitch'
        deviceInfo.branchPath  = [detailedPath '/SlowLeg/MOSFET/IdealSwitch'];
        deviceInfo.sourceName  = 'SwitchHigh';
        deviceInfo.targetNames = {'SwitchLow'};

    case 'slowThermalMOSFET'
        deviceInfo.branchPath  = [detailedPath '/SlowLeg/MOSFET/SwitchingMOSFETwithThermal'];
        deviceInfo.sourceName  = 'MOSFETHigh';
        deviceInfo.targetNames = {'MOSFETLow'};

    case 'slowIdealDiode'
        deviceInfo.branchPath  = [detailedPath '/SlowLeg/Diode/IdealDiode'];
        deviceInfo.sourceName  = 'DiodeHigh';
        deviceInfo.targetNames = {'DiodeLow'};

    case 'slowTabulatedDiode'
        deviceInfo.branchPath  = [detailedPath '/SlowLeg/Diode/TabulatedDiode'];
        deviceInfo.sourceName  = 'DiodeHigh';
        deviceInfo.targetNames = {'DiodeLow'};

    case 'slowThyristor'
        deviceInfo.branchPath  = [detailedPath '/SlowLeg/Thyristor'];
        deviceInfo.sourceName  = 'Thyristor1';
        deviceInfo.targetNames = {'Thyristor2'};

    case 'simplified'
        % The Simplified branch holds its four ideal switches side by side, with no
        % device variant of its own. Note the model's own spelling 'IdealSwitchSlowt'.
        deviceInfo.branchPath  = simplifiedPath;
        deviceInfo.sourceName  = 'IdealSwitchFastH';
        deviceInfo.targetNames = {'IdealSwitchFastL', 'IdealSwitchSlowtH', 'IdealSwitchSlowtL'};

    otherwise
        error('totemPoleDeviceBlocks:unknownDeviceKey', ...
            'Unknown device key ''%s''.', deviceKey);
end

deviceInfo.sourcePath  = [deviceInfo.branchPath '/' deviceInfo.sourceName];
deviceInfo.targetPaths = cellfun(@(name) [deviceInfo.branchPath '/' name], ...
    deviceInfo.targetNames, 'UniformOutput', false);

end
