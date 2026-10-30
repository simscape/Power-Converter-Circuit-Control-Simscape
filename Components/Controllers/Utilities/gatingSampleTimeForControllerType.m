function gatingSampleTime = gatingSampleTimeForControllerType(controllerType, discreteSampleTime)
%GATINGSAMPLETIMEFORCONTROLLERTYPE Rate for a block that gates a controller's loops.
%   gatingSampleTime = gatingSampleTimeForControllerType(controllerType, discreteSampleTime)
%   returns discreteSampleTime for a discrete controller and -1, inherited, for a continuous
%   one. A block that gates control loops has to run at the rate of the loops it gates.
%
%   Use it in the gating block's SampleTime parameter, as the expression
%   gatingSampleTimeForControllerType(cntrlSelect, Ts), so that the rate follows the mask
%   without anything having to write it. A mask cannot set a parameter of a block that sits
%   inside a library link, so a scripted write made a controller dragged out of a library
%   error as soon as the controller type changed.
%
%   Input Arguments:
%   ----------------
%   controllerType : Value of a cntrlSelect mask parameter, such as
%                    'PI controller (Continuous)' or 'PI controller (Discrete)'.
%   discreteSampleTime : Sample time to use for a discrete controller, in s.
%
%   Output Arguments:
%   -----------------
%   gatingSampleTime : discreteSampleTime for a discrete controller, -1 otherwise.
%
%   See also carrierModeForControllerType, carrierVariantChoiceForControllerType.

% Copyright 2026 The MathWorks, Inc.

arguments
    controllerType (1,:) char
    discreteSampleTime (1,1) double
end

if strcmp(carrierModeForControllerType(controllerType), 'Fixed-step (discrete)')
    gatingSampleTime = discreteSampleTime;
else
    gatingSampleTime = -1;
end

end
