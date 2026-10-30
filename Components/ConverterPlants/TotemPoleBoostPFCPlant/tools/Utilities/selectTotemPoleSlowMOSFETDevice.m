function selectTotemPoleSlowMOSFETDevice(blockPath)
%SELECTTOTEMPOLESLOWMOSFETDEVICE Mask callback for slow leg MOSFET device selection.
%   Switches the nested SlowLeg/MOSFET variant (Ideal Switch or Switching MOSFET with
%   thermal) and owns every control that belongs to the chosen device.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'slowMOSFETDeviceOption');

% Switch the nested device variant inside the slow-leg MOSFET branch.
variantPath = [blockPath, '/TotemPoleBoostPFCVariant/DetailedModel/SlowLeg/MOSFET'];
switch choice
    case 'Ideal Switch'
        setVariantActiveChoice(variantPath, 'IdealSwitch');
    case 'MOSFET (Ideal, Switching) with Thermal'
        setVariantActiveChoice(variantPath, 'SwitchingMOSFETwithThermal');
    otherwise
        warning('selectTotemPoleSlowMOSFETDevice: Invalid selection: %s', choice);
end

% A mask callback fires on programmatic set_param too, so this one runs even while the
% block is Simplified or the slow leg is a Diode or a Thyristor and this popup is hidden
% - and unguarded it puts MOSFET controls back on the dialog that the active branch
% cannot use. The variant switch above still has to happen; only the visibility belongs
% to the outer callback in those cases.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed') || ...
        ~strcmp(get_param(blockPath, 'slowLegDeviceOption'), 'MOSFET')
    return;
end

controlGroups = totemPoleMaskControlGroups();

if strcmp(choice, 'Ideal Switch')
    % Channel data plus the data of the switch's own integral protection diode, which
    % carries the reverse current in a totem-pole leg. The standalone diode device's data
    % (slowDiode) is not in play here. No thermal port, so no simulation temperature, and
    % nothing worth opening on the device dialog.
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowSwitch, controlGroups.slowBodyDiode], 'on');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowDiode, controlGroups.slowThermal, ...
        controlGroups.slowMOSFETButtons], 'off');
elseif strcmp(choice, 'MOSFET (Ideal, Switching) with Thermal')
    % Datasheet channel and body-diode data live on the device block, reached through
    % the two buttons, so this dialog offers only the junction temperature.
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowSwitch, controlGroups.slowBodyDiode, ...
        controlGroups.slowDiode], 'off');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowThermal, controlGroups.slowMOSFETButtons], 'on');
end

end
