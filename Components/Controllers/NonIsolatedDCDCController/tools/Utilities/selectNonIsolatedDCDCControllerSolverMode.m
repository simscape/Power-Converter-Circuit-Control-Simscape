function selectNonIsolatedDCDCControllerSolverMode(blockPath)
%SELECTNONISOLATEDDCDCCTRLSOLVERMODE Apply the modulator carrier implied by the controller type.
%
%   The carrier follows the controller type and is not asked for on the dialog box. A
%   continuous controller takes the variable-step carrier, and a discrete controller
%   takes the fixed-step carrier.
%
%   The PWM carrier is a ramp of elapsed time that resets every switching period,
%   and it comes in two forms:
%     Variable-step (continuous) - a continuous Integrator with zero-crossing
%       detection on the reset, which places the switching edges exactly. This is
%       the choice for the Simscape models in this repository.
%     Fixed-step (discrete) - a Discrete-Time Integrator clocked at Ts, for
%       fixed-step simulation and code generation. Edge placement is quantized to Ts.
%
%   The modulator holds a Ramp Mode variant offering both implementations, and the derived
%   carrier selects one. Ts is shown only for the fixed-step carrier, and only when the
%   block is emitting PWM at all. Duty Cycle output mode has no carrier. Both conditions
%   are tested here so that either dropdown leaves the dialog box in the
%   same state.
%
%   See also carrierVariantChoiceForControllerType, setPWMRampVariantChoice,
%   selectNonIsolatedDCDCControllerOutputMode, nonIsolatedDCDCControllerMaskInit.

% Copyright 2026 The MathWorks, Inc.

choiceLabel = carrierVariantChoiceForControllerType(get_param(blockPath, 'cntrlSelect'));
outputChoice = get_param(blockPath, 'outputSelect');
modulatorLoc = [blockPath, '/Output Mode/PWMSignal/Half Bridge PWM Generator'];

isFixedStep = strcmp(choiceLabel, 'FixedStep');

% The modulator lives inside the PWMSignal choice of the Output Mode variant. That
% choice is a real block whether or not it is the active one, so the setting sticks
% and is already correct the next time the output is switched back to PWM.
% Selecting a variant choice is the only write available here: a mask cannot set a
% parameter of a block inside a library link, so setting the generator's solver mode
% errored the moment this controller was dragged out of a library.
setPWMRampVariantChoice(modulatorLoc, choiceLabel);

% No carrier, no sample time.
sampleTimeVisibility = 'off';
if isFixedStep && strcmp(outputChoice, 'PWM Signal')
    sampleTimeVisibility = 'on';
end

setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'Ts'}, Visibility=sampleTimeVisibility);

end
