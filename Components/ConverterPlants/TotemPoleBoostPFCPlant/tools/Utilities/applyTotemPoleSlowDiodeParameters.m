function applyTotemPoleSlowDiodeParameters(blockPath)
%APPLYTOTEMPOLESLOWDIODEPARAMS Apply Diode parameters from DiodeHigh to DiodeLow.
%   Applies to the tabulated diode, whose datasheet parameters the plant mask does not
%   expose. Its "Apply parameters to all slow leg Diode blocks" button is then the only
%   way to keep the two devices in step. The ideal diode is already driven from the mask
%   through VfSlow, RdSlow and GdSlow on both devices.
%
%   The block paths and the copy loop live in totemPoleDeviceBlocks and
%   applyTotemPoleDeviceParameters.

% Copyright 2025-2026 The MathWorks, Inc.

applyTotemPoleDeviceParameters(blockPath, 'slowTabulatedDiode');

end
