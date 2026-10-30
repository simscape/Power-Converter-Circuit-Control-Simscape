function openCLLCDeviceMask(blockPath, deviceKey)
%OPENCLLCDEVICEMASK Open the dialog of one CLLC semiconductor device.
%   openCLLCDeviceMask(BLOCKPATH, DEVICEKEY) opens the block dialog of the representative
%   device of variant branch DEVICEKEY, so you can set the datasheet parameters the plant
%   mask does not expose. See getCLLCDeviceBlocks for the valid keys.
%
%   This is the target of the plant mask's "Open the MOSFET block mask" buttons. It
%   reports a readable error instead of Simulink's raw "invalid block path". It also loads
%   the device's parent first, so the dialog opens on an inactive variant branch too. The
%   branch you want to configure is usually the one you are about to switch to.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    deviceKey (1,:) char
end

deviceInfo = getCLLCDeviceBlocks(blockPath, deviceKey);

if getSimulinkBlockHandle(deviceInfo.sourcePath) <= 0
    % Force the containing hierarchy to load: a block inside an inactive variant of an
    % unopened subsystem is not resolvable by path until its parent is loaded.
    load_system(bdroot(blockPath));
end

if getSimulinkBlockHandle(deviceInfo.sourcePath) <= 0
    error('openCLLCDeviceMask:missingDevice', ...
        ['Cannot find the %s device block.\n' ...
         'Expected it at:\n  %s\n' ...
         'The plant subsystem has probably been restructured. Update the paths in ' ...
         'getCLLCDeviceBlocks.m, which is the single place they are defined.'], ...
        deviceKey, deviceInfo.sourcePath);
end

open_system(deviceInfo.sourcePath, 'mask');

end
