function nonIsolatedDCDCControllerMaskInit(blockPath)
%NONISOLATEDDCDCCTRLMASKINIT Mask initialization for the Non-Isolated DC-DC
%   cascaded controller.

% Copyright 2026 The MathWorks, Inc.

% Order matters. The topology decides which duty feedforward law is active and
% whether the leg is synchronous; the loop structure decides whether the inner
% current loop exists; the controller type then switches each surviving loop
% between continuous and discrete; the output mode comes next because its parameter
% visibility depends on the topology chosen in the first step; and the carrier is
% derived last because it hides the modulator sample time when there is no
% modulator, which is the output mode's decision.
selectNonIsolatedDCDCControllerTopology(blockPath);
selectNonIsolatedDCDCControllerLoopStructure(blockPath);
selectNonIsolatedDCDCControllerType(blockPath);
selectNonIsolatedDCDCControllerOutputMode(blockPath);
selectNonIsolatedDCDCControllerSolverMode(blockPath);

end
