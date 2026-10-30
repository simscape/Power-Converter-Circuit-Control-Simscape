function selectTotemPolePFCControllerOutputMode(blockPath)
%SELECTTOTEMPOLEPFCCTRLOUTPUTMODE Switch the controller output between duty cycle and gates.
%   The two carrier parameters appear only when a carrier exists. Only the fast leg
%   parameters hide with the modulator. The slow leg quantities, slowLegTurnOnDelay
%   and the two gate levels, stay visible in both modes. Gate Logic sits downstream
%   of Output Mode and commutates the slow leg either way.
%
%   Fline stays visible but feeds nothing. The slow leg turn-on delay is a time
%   ramp on the line-polarity signal, not a blanking window derived from Fline.

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

% Both belong to the 'Half Bridge PWM Generator' inside Output Mode: Fsw is its
% carrier period and fastLegDeadTime is the gap it inserts between the
% complementary edges. Neither has any effect on a raw duty-cycle output.
setVisibilityIfParameterExists(blockPath, 'Fsw', modulatorVisibility);
setVisibilityIfParameterExists(blockPath, 'fastLegDeadTime', modulatorVisibility);

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
