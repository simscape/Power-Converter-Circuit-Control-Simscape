function selectNonIsolatedDCDCControllerLoopStructure(blockPath)
%SELECTNONISOLATEDDCDCCTRLLOOPSTRUCTURE Mask callback for single/double loop.
%
%   Single loop : the voltage PI produces the duty trim directly. Its output
%                 limits are the duty trim range left over after the feedforward
%                 (computed in the mask initialization), so no inner loop runs.
%   Double loop : the voltage PI produces a per-unit inductor-current reference
%                 and the inner current PI produces the duty trim. The current PI
%                 takes its saturation limits from external ports driven by the
%                 feedforward trim. Its anti-windup clamp therefore tracks the duty
%                 headroom exactly at every operating point.

% Copyright 2026 The MathWorks, Inc.

loopChoice = get_param(blockPath, 'loopStructure');
loopStructureLoc = [blockPath, '/Loop Structure'];

% Parameters that only mean something when the inner current loop exists.
% TsCurrent is deliberately absent: selectNonIsolatedDCDCControllerType owns
% it, because it must also respect the continuous/discrete choice.
currentLoopParams = {'KpCurrent', 'KiCurrent', 'iRefMaxPu', 'iRefMinPu'};

% A dialog open runs this callback with the choice already in force, so the variant
% write compares first. Writing the value a block already holds throws
% Simulink:Libraries:LockViolation on a locked library.
if strcmp(loopChoice, 'Double loop')
    setControllerVariantActiveChoice(loopStructureLoc, 'DoubleLoop');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=currentLoopParams, Visibility='on');
else
    setControllerVariantActiveChoice(loopStructureLoc, 'SingleLoop');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=currentLoopParams, Visibility='off');
end

end
