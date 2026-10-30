function selectInterleavedPFCOutputMode(blockPath)
%SELECTINTERLEAVEDPFCOUTPUTMODE Switch the output between per-leg duty cycles and gates.
%   The dialog box then shows only the parameters that act in the selected mode.
%   Interleaving lives in this block, where the carriers are offset by
%   1/(numberOfLegs*Fsw). In Duty Cycle mode Fsw, numberOfLegs and the gate-drive
%   levels therefore have no effect.
%
%   Ts is not in the list below. It depends on the controller type as well as the
%   output mode, so selectInterleavedPFCPWMSolverMode owns it.

% Copyright 2025-2026 The MathWorks, Inc.

outputChoice = get_param(blockPath, 'outputSelect');
outLoc = [blockPath, '/Output Mode'];

if strcmp(outputChoice, 'Duty Cycle')
    set_param(outLoc, 'LabelModeActiveChoice', 'DutyCycle');
    modulatorVisibility = 'off';
elseif strcmp(outputChoice, 'PWM Signal')
    set_param(outLoc, 'LabelModeActiveChoice', 'PWMSignal');
    modulatorVisibility = 'on';
else
    return
end

modulatorParameters = {'Fsw', 'numberOfLegs', 'Tdead', ...
    'gateVoltageOn', 'gateVoltageOff'};
for parameterIndex = 1:numel(modulatorParameters)
    setVisibilityIfParameterExists(blockPath, modulatorParameters{parameterIndex}, ...
        modulatorVisibility);
end

end

function setVisibilityIfParameterExists(blockPath, parameterName, visibility)
% Guarded wrapper: setVisibilityForMaskParameter indexes the parameter list
% directly and errors on a name that is not there.

maskObject = Simulink.Mask.get(blockPath);
if any(strcmp({maskObject.Parameters.Name}, parameterName))
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={parameterName}, Visibility=visibility);
end

end
