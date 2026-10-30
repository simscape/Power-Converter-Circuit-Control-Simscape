function selectBoostPFCPWMSolverMode(blockPath)
%SELECTBOOSTPFCPWMSOLVERMODE Apply the modulator carrier implied by the controller type.
%   The carrier follows the controller type and is not asked for on the dialog box. A
%   continuous controller takes the variable-step carrier, and a discrete controller
%   takes the fixed-step carrier.
%
%   The carrier is a ramp of elapsed time that resets every switching period. It comes
%   in two forms, held as the label-mode choices of the Ramp Mode variant subsystem:
%     VariableStep - continuous Integrator with zero-crossing detection on the reset.
%                    Switching edges land exactly, and the variable-step solver takes
%                    a step at every edge. This suits the Simscape models here.
%     FixedStep    - Discrete-Time Integrator clocked at Ts, for fixed-step
%                    simulation and code generation. Edge placement quantizes to Ts.
%
%   Ts is shown only for the fixed-step carrier, and only while the block emits PWM,
%   because Duty Cycle output mode has no carrier. This callback tests both
%   conditions, so either dropdown leaves the dialog box in the same state.
%
%   See also carrierModeForControllerType, selectBoostPFCOutputMode,
%   boostPFCControllerMaskInit.

% Copyright 2026 The MathWorks, Inc.

carrierMode = carrierModeForControllerType(get_param(blockPath, 'cntrlSelect'));
outputChoice = get_param(blockPath, 'outputSelect');
rampModeLocation = [blockPath, '/Output Mode/PWMSignal/Ramp Mode'];

if strcmp(carrierMode, 'Fixed-step (discrete)')
    activeChoice = 'FixedStep';
    sampleTimeVisibility = 'on';
else
    activeChoice = 'VariableStep';
    sampleTimeVisibility = 'off';
end

% The carrier lives inside the PWMSignal choice of the Output Mode variant. That choice
% is a real block whether or not it is active, so the setting sticks and is already
% correct when the output switches back to PWM.
if getSimulinkBlockHandle(rampModeLocation) > 0
    set_param(rampModeLocation, 'LabelModeActiveChoice', activeChoice);
end

% No carrier, no sample time.
if ~strcmp(outputChoice, 'PWM Signal')
    sampleTimeVisibility = 'off';
end

maskObject = Simulink.Mask.get(blockPath);
if any(strcmp({maskObject.Parameters.Name}, 'Ts'))
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'Ts'}, Visibility=sampleTimeVisibility);
end

end
