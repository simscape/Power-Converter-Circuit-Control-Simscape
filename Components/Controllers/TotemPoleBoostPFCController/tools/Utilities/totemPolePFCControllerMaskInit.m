function totemPolePFCControllerMaskInit(blockPath)
%TOTEMPOLEPFCCONTROLLERMASKINIT Apply the totem-pole PFC controller mask dropdowns.
%   totemPolePFCControllerMaskInit(blockPath) runs every selector callback on the
%   totem-pole boost PFC controller mask, so the block contents match the dialog.
%
%   See also applyDerivedPWMCarrier.

% Copyright 2025-2026 The MathWorks, Inc.

selectTotemPolePFCControllerType(blockPath);
selectTotemPolePFCControllerOutputMode(blockPath);

% Both modulators take the carrier implied by the controller type. Neither modulator
% sample time is on this dialog, so each generator keeps the rate it holds.
applyDerivedPWMCarrier(blockPath, 'Output Mode/PWMSignal/Half Bridge PWM Generator', '');
applyDerivedPWMCarrier(blockPath, 'Gate Logic/Slow Leg Complementary PWM', '');

end
