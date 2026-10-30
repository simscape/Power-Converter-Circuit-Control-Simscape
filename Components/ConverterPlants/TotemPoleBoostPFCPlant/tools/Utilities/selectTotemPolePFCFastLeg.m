function selectTotemPolePFCFastLeg(blockPath)
%SELECTTOTEMPOLEPFCFASTLEG Mask callback for fast leg device variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'fastLegDeviceOption');

variantPath = [blockPath, '/TotemPoleBoostPFCVariant/DetailedModel/FastLeg'];
switch choice
    case 'Ideal Switch'
        setVariantActiveChoice(variantPath, 'IdealSwitch');
    case 'MOSFET (Ideal, Switching) with Thermal'
        setVariantActiveChoice(variantPath, 'SwitchingMOSFETwithThermal');
    otherwise
        warning('selectTotemPolePFCFastLeg: Invalid selection: %s', choice);
end

% A mask callback fires on programmatic set_param too, so this one runs even while the
% block is in Simplified mode and this popup is hidden, and unguarded it shows device
% controls the Simplified branch does not use. The variant switch above still has to
% happen, so the Detailed branch is correct if you switch back; only the
% visibility belongs to the model-option callback in that case.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed')
    return;
end

controlGroups = totemPoleMaskControlGroups();

if strcmp(choice, 'Ideal Switch')
    % The ideal switch is parameterized entirely from this dialog: its channel data and
    % the data of its integral protection diode, which conducts the reverse current in a
    % totem-pole leg. It has no thermal port, so no simulation temperature.
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.fastSwitch, controlGroups.fastBodyDiode], 'on');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.fastThermal, controlGroups.fastButtons], 'off');
elseif strcmp(choice, 'MOSFET (Ideal, Switching) with Thermal')
    % The thermal MOSFET carries datasheet channel and body-diode data on the device
    % block itself, reached through the two buttons, so this dialog offers only the
    % junction temperature the loss analysis sweeps.
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.fastSwitch, controlGroups.fastBodyDiode], 'off');
    setTotemPoleDialogVisibility(blockPath, ...
        [controlGroups.fastThermal, controlGroups.fastButtons], 'on');
end

end
