function dcdcControllerMaskInit(blockPath)
%DCDCCONTROLLERMASKINIT Mask initialization for the Non-Isolated DC-DC Controller.

% Copyright 2025-2026 The MathWorks, Inc.

% Activate the loop structure (single/double) first so the controller-type
% callback can decide how to treat the outer voltage loop, then resolve the
% output (duty/PWM) mode.
selectDCDCLoopStructure(blockPath);
selectDCDCControllerType(blockPath);
selectDCDCOutputMode(blockPath);

end
