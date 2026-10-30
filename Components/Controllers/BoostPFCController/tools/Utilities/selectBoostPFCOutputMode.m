function selectBoostPFCOutputMode(blockPath)
%SELECTBOOSTPFCOUTPUTMODE Switch the controller output between duty cycle and gates.
%   The dialog box then shows only the parameters that act in the selected mode. The
%   modulator lives inside the PWM choice, so in Duty Cycle mode the switching
%   frequency and the gate-drive levels have no effect.
%
%   Ts is not in the list below. It depends on the controller type as well as the
%   output mode, so selectBoostPFCPWMSolverMode owns it.
%
%   See also selectBoostPFCPWMSolverMode, boostPFCControllerMaskInit.

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

modulatorParameters = {'Fsw', 'Tdead', 'gateVoltageOn', 'gateVoltageOff'};
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
