function selectBoostPFCSwitchDevice(blockPath)
%SELECTBOOSTPFCSWITCHDEVICE Mask callback for variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'switchDeviceOption');

variantPath = [blockPath, '/BoostPFCVariant/DetailedModel/BoostSwitch'];
switch choice
    case 'Ideal Switch'
        setVariantActiveChoice(variantPath, 'IdealSwitch');
    case 'MOSFET (Ideal, Switching) with Thermal'
        setVariantActiveChoice(variantPath, 'SwitchingMOSFETwithThermal');
    otherwise
        warning('Invalid selection: %s', choice);
end

% Simulink runs a mask parameter callback whenever the dialog opens, and again on a
% programmatic set_param, so this one runs even while the block is in Simplified mode and
% this popup is hidden. Without this guard it hides the ideal-switch parameters the
% Simplified branch does use and shows the MOSFET button it does not have, which is what
% made a Simplified dialog come up offering a thermal MOSFET. The variant switch above
% still has to happen, so the Detailed branch is right if you switch back; in
% Simplified mode the visibility belongs to selectBoostPFCModelOption alone.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed')
    return;
end

if strcmp(choice, 'Ideal Switch')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'RdsOn', 'RdsOn_unit', 'GdsOff', 'GdsOff_unit', 'Vth', 'Vth_unit'}, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openMOSFETMask'}, Visibility='off');
elseif strcmp(choice, 'MOSFET (Ideal, Switching) with Thermal')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'RdsOn', 'RdsOn_unit', 'GdsOff', 'GdsOff_unit', 'Vth', 'Vth_unit'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openMOSFETMask'}, Visibility='on');
end

% Only the thermal MOSFET build takes a junction temperature, so the shared simulation
% temperature parameter follows this choice.
updateBoostPFCTemperatureVisibility(blockPath);

end
