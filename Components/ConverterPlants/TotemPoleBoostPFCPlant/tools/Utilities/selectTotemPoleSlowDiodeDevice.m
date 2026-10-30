function selectTotemPoleSlowDiodeDevice(blockPath)
%SELECTTOTEMPOLESLOWDIODEDEVICE Mask callback for slow leg diode device selection.
%   Switches the nested SlowLeg/Diode variant (Ideal or Tabulated diode) and owns every
%   control that belongs to the chosen device.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'slowDiodeDeviceOption');

% Switch the nested device variant inside the slow-leg diode branch.
variantPath = [blockPath, '/TotemPoleBoostPFCVariant/DetailedModel/SlowLeg/Diode'];
switch choice
    case 'Ideal Diode'
        setVariantActiveChoice(variantPath, 'IdealDiode');
    case 'Tabulated Diode'
        setVariantActiveChoice(variantPath, 'TabulatedDiode');
    otherwise
        warning('selectTotemPoleSlowDiodeDevice: Invalid selection: %s', choice);
end

% A mask callback fires on programmatic set_param too, so this one runs even while the
% block is Simplified or the slow leg is a MOSFET or a Thyristor and this popup is
% hidden. Without this guard it turns the diode's forward voltage, on resistance and off
% conductance back on underneath a thermal MOSFET:
% the outer callback hid them, then this one ran and undid it. The variant switch above
% still has to happen; only the visibility belongs to the outer callback here.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed') || ...
        ~strcmp(get_param(blockPath, 'slowLegDeviceOption'), 'Diode')
    return;
end

controlGroups = totemPoleMaskControlGroups();

if strcmp(choice, 'Ideal Diode')
    % Parameterized entirely from this dialog, on both DiodeHigh and DiodeLow, so there
    % is nothing to open and nothing to copy between the two devices. Its forward voltage
    % and resistances are constants, so it has no temperature dependence either.
    setTotemPoleDialogVisibility(blockPath, controlGroups.slowDiode, 'on');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowDiodeButtons, controlGroups.slowThermal], 'off');
elseif strcmp(choice, 'Tabulated Diode')
    % Driven by tabulated data on the device block instead, reached through the buttons.
    % That data is a family of I-V curves over junction temperature, and the block has no
    % thermal port, so the mask's simulation temperature is what picks the curve.
    setTotemPoleDialogVisibility(blockPath, controlGroups.slowDiode, 'off');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.slowDiodeButtons, controlGroups.slowThermal], 'on');
end

end
