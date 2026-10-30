function interleavedPFCControllerMaskInit(blockPath)
%INTERLEAVEDPFCCONTROLLERMASKINIT Apply the interleaved boost PFC controller dropdowns.
%   interleavedPFCControllerMaskInit(blockPath) runs every selector callback, so the
%   block contents match the dialog box.
%
%   Order matters. The output mode is applied before the carrier is derived, because
%   the carrier exists only inside the PWM output. Its callback needs the output mode
%   settled to decide whether the sample time is reachable.

% Copyright 2025-2026 The MathWorks, Inc.

selectInterleavedPFCControllerType(blockPath);
selectInterleavedPFCOutputMode(blockPath);
selectInterleavedPFCPWMSolverMode(blockPath);

end
