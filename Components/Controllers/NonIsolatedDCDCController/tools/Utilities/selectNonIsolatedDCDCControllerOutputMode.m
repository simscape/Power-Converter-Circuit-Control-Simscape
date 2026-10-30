function selectNonIsolatedDCDCControllerOutputMode(blockPath)
%SELECTNONISOLATEDDCDCCTRLOUTPUTMODE Mask callback for the output stage.
%
%   Duty Cycle  : the block emits the commanded duty, for use against an averaged
%                 plant model. No carrier, no gate levels, no dead time.
%   PWM Signal  : the block emits gate voltages for the plant's G port. The port
%                 is one gate wide for Buck/Boost/Buck-Boost and two gates wide
%                 for the synchronous topologies, matching what the plant demuxes.
%
%   The dead time applies only to a synchronous leg. It is shown only when
%   the topology has a second switch to hand over to.

% Copyright 2026 The MathWorks, Inc.

outputChoice = get_param(blockPath, 'outputSelect');
outputModeLoc = [blockPath, '/Output Mode'];

isPwm = strcmp(outputChoice, 'PWM Signal');
isSynchronous = any(strcmp(get_param(blockPath, 'modelOption'), ...
    {'Synchronous Buck', 'Synchronous Boost', 'Synchronous Buck-Boost'}));

% A dialog open runs this callback with the choice already in force, so the variant
% write compares first. Writing the value a block already holds throws
% Simulink:Libraries:LockViolation on a locked library.
if isPwm
    setControllerVariantActiveChoice(outputModeLoc, 'PWMSignal');
else
    setControllerVariantActiveChoice(outputModeLoc, 'DutyCycle');
end

setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'Fsw', 'gateVoltageOn', 'gateVoltageOff'}, ...
    Visibility=onOff(isPwm));
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'Tdead'}, Visibility=onOff(isPwm && isSynchronous));

end

% ------------------------------------------------------------------------
function visibility = onOff(isVisible)
if isVisible
    visibility = 'on';
else
    visibility = 'off';
end
end
