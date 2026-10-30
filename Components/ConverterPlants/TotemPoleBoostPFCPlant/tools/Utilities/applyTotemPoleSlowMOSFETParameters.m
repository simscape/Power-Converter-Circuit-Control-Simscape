function applyTotemPoleSlowMOSFETParameters(blockPath)
%APPLYTOTEMPOLESLOWMOSFETPARAMS Apply MOSFET parameters to all slow leg MOSFETs.
%   Copies every dialog parameter from MOSFETHigh (representative) to MOSFETLow.
%   Kept as a named entry point for the plant mask's "Apply parameters to all slow leg
%   MOSFET blocks" button. Older copies of the block call it too. The block paths and
%   the copy loop live in totemPoleDeviceBlocks and applyTotemPoleDeviceParameters.

% Copyright 2025-2026 The MathWorks, Inc.

applyTotemPoleDeviceParameters(blockPath, 'slowThermalMOSFET');

end
