function selectDABControllerOutputMode(blockPath)
%SELECTDABCTRLOUTPUTMODE Switch the DAB controller output between gates and phase shift.
%   selectDABControllerOutputMode(blockPath) activates the Output Mode variant the mask
%   requests, and shows only the parameters that variant uses.

% Copyright 2025-2026 The MathWorks, Inc.

outputChoice = get_param(blockPath, 'outputSelect');
outLoc = [blockPath, '/Output Mode'];

% Show the gate-signal parameters only when the block outputs gate signals, and hide
% them when it outputs a phase-shift command. Filter to the parameters
% present on this block so the callback stays valid on older blocks.
gateSignalOnlyParameters = {'Fsw', 'Tdead', ...
    'primaryGateVoltage', 'secondaryGateVoltage'};
existingParameters = get_param(blockPath, 'MaskNames');
gateSignalOnlyParameters = gateSignalOnlyParameters( ...
    ismember(gateSignalOnlyParameters, existingParameters));

if strcmp(outputChoice, 'Phase Shift (rad)')
    set_param(outLoc, 'LabelModeActiveChoice', 'DutyCycle');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=gateSignalOnlyParameters, Visibility='off');
elseif strcmp(outputChoice, 'Gate Signals')
    set_param(outLoc, 'LabelModeActiveChoice', 'PWMSignal');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=gateSignalOnlyParameters, Visibility='on');
end

end
