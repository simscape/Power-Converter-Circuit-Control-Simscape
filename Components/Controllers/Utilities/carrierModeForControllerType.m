function carrierMode = carrierModeForControllerType(controllerType)
%CARRIERMODEFORCONTROLLERTYPE Carrier implementation that goes with a controller type.
%   carrierMode = carrierModeForControllerType(controllerType) maps the controller type
%   selected on a controller mask to the PWM carrier implementation it implies. A
%   continuous controller takes the variable-step carrier, and a discrete controller
%   takes the fixed-step carrier.
%
%   controllerType is the value of a cntrlSelect mask parameter, such as
%   'PI controller (Continuous)' or 'Compensator (Discrete Z domain)'. carrierMode is
%   'Variable-step (continuous)' or 'Fixed-step (discrete)', which are the two values a
%   PWM generator block and a Ramp Mode variant accept.
%
%   See also applyDerivedPWMCarrier.

% Copyright 2026 The MathWorks, Inc.

% The carrier is not a separate choice. A continuous controller is
% simulated with a variable-step solver, where the continuous ramp places each switching
% edge exactly. A discrete controller runs on a fixed step, so its ramp has to be
% clocked at that step instead.
if contains(controllerType, 'Discrete')
    carrierMode = 'Fixed-step (discrete)';
elseif contains(controllerType, 'Continuous')
    carrierMode = 'Variable-step (continuous)';
else
    error('converterController:unknownControllerType', ...
        'Cannot derive a carrier implementation from controller type "%s".', ...
        controllerType);
end

end
