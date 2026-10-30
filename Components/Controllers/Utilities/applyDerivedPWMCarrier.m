function applyDerivedPWMCarrier(controllerPath, generatorPath, sampleTimeName, controllerTypeName)
%APPLYDERIVEDPWMCARRIER Give a nested PWM generator the carrier its controller implies.
%   applyDerivedPWMCarrier(controllerPath, generatorPath, sampleTimeName) reads the
%   controller type from the controller mask and selects the PWM generator built for the
%   carrier that type implies.
%
%   controllerPath is the path to the controller block, and generatorPath is the path to
%   the generator relative to it. The generator holds one Ramp Mode variant per sawtooth,
%   each offering a VariableStep and a FixedStep implementation, and the controller selects
%   the one its type implies. Selecting a variant choice is the whole of the work: a mask
%   cannot set a parameter of a block that sits inside a library link, which is what setting
%   the generator's solver mode used to do, and that made a controller dragged out of a
%   library error as soon as the controller type changed.
%
%   sampleTimeName is the mask parameter holding the modulator sample time, which is shown
%   only for the fixed-step carrier. Set it to '' for a controller whose sample time has
%   further conditions on it, or has none on the dialog.
%
%   applyDerivedPWMCarrier(controllerPath, generatorPath, sampleTimeName, controllerTypeName)
%   reads the time domain from the mask parameter named controllerTypeName instead of the
%   default 'cntrlSelect'. Use it for a controller whose time domain is a parameter of its
%   own, such as the CLLC controller's 'controllerDomain'.
%
%   See also carrierVariantChoiceForControllerType, setPWMRampVariantChoice.

% Copyright 2026 The MathWorks, Inc.

if nargin < 4 || isempty(controllerTypeName)
    controllerTypeName = 'cntrlSelect';
end

choiceLabel = carrierVariantChoiceForControllerType(get_param(controllerPath, controllerTypeName));

setPWMRampVariantChoice([controllerPath '/' generatorPath], choiceLabel);

% Only the discrete carrier declares a rate, so the sample time is hidden otherwise.
if ~isempty(sampleTimeName)
    maskObject = Simulink.Mask.get(controllerPath);
    sampleTimeParameter = maskObject.getParameter(sampleTimeName);
    if ~isempty(sampleTimeParameter)
        if strcmp(choiceLabel, 'FixedStep')
            sampleTimeParameter.Visible = 'on';
        else
            sampleTimeParameter.Visible = 'off';
        end
    end
end

end
