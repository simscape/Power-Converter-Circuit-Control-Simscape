function selectDCDCLoopStructure(blockPath)
%SELECTDCDCLOOPSTRUCTURE Mask callback for single/double-loop selection.

% Copyright 2025-2026 The MathWorks, Inc.

% The Non-Isolated DC-DC Controller offers two control structures, selected by
% the "Loop Structure" label-mode variant subsystem:
%   Single loop : error = Ref - Vmeas feeds the inner (duty) controller.
%   Double loop : an outer voltage PI produces a current reference, and
%                 error = iref - Imeas feeds the inner (now current) loop.
% This callback activates the matching variant choice and shows the
% voltage-loop parameters only when the double-loop structure is selected.
% (The voltage-loop discrete sample time, TsVoltage, is managed by
% selectDCDCControllerType so it also respects the continuous/discrete choice.)

% This callback is shared with library copies of the block that predate the
% single/double-loop option. Those masks have no loopStructure parameter and no
% Loop Structure variant subsystem, so there is nothing to switch: leave them
% exactly as they are instead of erroring out of the mask initialization.
maskObject = Simulink.Mask.get(blockPath);
if isempty(maskObject) || isempty(maskObject.getParameter('loopStructure'))
    return
end

loopChoice = get_param(blockPath, 'loopStructure');
loopStructureLoc = [blockPath, '/Loop Structure'];

voltageLoopParams = {'cntrlSelectVoltage', 'Kpv', 'Kiv', 'iRefMax', 'iRefMin'};

if strcmp(loopChoice, 'Double loop')
    set_param(loopStructureLoc, 'LabelModeActiveChoice', 'DoubleLoop');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=voltageLoopParams, Visibility='on');
else
    set_param(loopStructureLoc, 'LabelModeActiveChoice', 'SingleLoop');
    % Hide every voltage-loop parameter, including its sample time.
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=[voltageLoopParams, {'TsVoltage'}], Visibility='off');
end

end
