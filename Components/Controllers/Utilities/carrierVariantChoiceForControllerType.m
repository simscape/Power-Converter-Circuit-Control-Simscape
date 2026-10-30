function choiceLabel = carrierVariantChoiceForControllerType(controllerType)
%CARRIERVARIANTCHOICEFORCONTROLLERTYPE PWM carrier choice that goes with a controller type.
%   choiceLabel = carrierVariantChoiceForControllerType(controllerType) maps the controller
%   type selected on a controller mask to the name of the PWM generator choice it implies.
%
%   controllerType is the value of a cntrlSelect mask parameter, such as
%   'PI controller (Continuous)' or 'Compensator (Discrete Z domain)'. choiceLabel is
%   'VariableStep' or 'FixedStep', the two choices a PWM generator variant holds.
%
%   A controller selects one of two prebuilt generators rather than setting the carrier on
%   a single generator, because a mask cannot set a parameter of a block that sits inside a
%   library link, while it can select a variant choice.
%
%   See also carrierModeForControllerType, applyDerivedPWMCarrier.

% Copyright 2026 The MathWorks, Inc.

arguments
    controllerType (1,:) char
end

if strcmp(carrierModeForControllerType(controllerType), 'Fixed-step (discrete)')
    choiceLabel = 'FixedStep';
else
    choiceLabel = 'VariableStep';
end

end
