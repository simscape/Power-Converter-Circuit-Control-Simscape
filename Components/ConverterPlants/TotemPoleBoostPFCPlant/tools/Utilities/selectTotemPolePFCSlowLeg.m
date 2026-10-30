function selectTotemPolePFCSlowLeg(blockPath)
%SELECTTOTEMPOLEPFCSLOWLEG Mask callback for slow leg device variant selection.
%   Switches the slow leg between MOSFET, Diode and Thyristor. The MOSFET and Diode
%   branches are variant subsystems in their own right. This callback therefore shows the
%   matching nested popup and leaves the device-level visibility to the nested callback.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'slowLegDeviceOption');

variantPath = [blockPath, '/TotemPoleBoostPFCVariant/DetailedModel/SlowLeg'];
switch choice
    case 'Diode'
        setVariantActiveChoice(variantPath, 'Diode');
    case 'MOSFET'
        setVariantActiveChoice(variantPath, 'MOSFET');
    case 'Thyristor'
        setVariantActiveChoice(variantPath, 'Thyristor');
    otherwise
        warning('selectTotemPolePFCSlowLeg: Invalid selection: %s', choice);
end

% See selectTotemPolePFCFastLeg: the variant switch above must happen even in Simplified
% mode, but the visibility is the model-option callback's to own there.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed')
    return;
end

controlGroups = totemPoleMaskControlGroups();

if strcmp(choice, 'Diode')
    setTotemPoleDialogVisibility(blockPath, {'slowDiodeDeviceOption'}, 'on');
    setTotemPoleDialogVisibility(blockPath, [{'slowMOSFETDeviceOption'}, ...
        controlGroups.slowSwitch, controlGroups.slowBodyDiode, ...
        controlGroups.slowHolding, controlGroups.slowMOSFETButtons], 'off');
    % The nested callback owns the diode data, the diode buttons and the simulation
    % temperature. The temperature is not hidden here: a tabulated diode
    % interpolates its I-V data at that temperature, so the Diode leg needs it as much as
    % the MOSFET leg does, and only the nested callback knows which diode is selected.
    selectTotemPoleSlowDiodeDevice(blockPath);

elseif strcmp(choice, 'MOSFET')
    setTotemPoleDialogVisibility(blockPath, {'slowMOSFETDeviceOption'}, 'on');
    setTotemPoleDialogVisibility(blockPath, [{'slowDiodeDeviceOption'}, ...
        controlGroups.slowHolding, controlGroups.slowDiodeButtons], 'off');
    % The nested callback owns the switch data, the protection-diode data, the
    % simulation temperature and the MOSFET buttons.
    selectTotemPoleSlowMOSFETDevice(blockPath);

elseif strcmp(choice, 'Thyristor')
    % The thyristor is parameterized entirely from this dialog: forward voltage, on
    % resistance and off conductance, its gate trigger voltage reusing the threshold
    % control, and its holding current. It has no drain-source on-state data, no nested
    % device choice, no thermal port and no per-device dialog worth opening.
    setTotemPoleDialogVisibility(blockPath, [ ...
        controlGroups.slowDiode, controlGroups.slowThreshold, ...
        controlGroups.slowHolding], 'on');
    setTotemPoleDialogVisibility(blockPath, [ ...
        controlGroups.nestedPopups, controlGroups.slowSwitchOnState, ...
        controlGroups.slowBodyDiode, controlGroups.slowThermal, ...
        controlGroups.slowMOSFETButtons, controlGroups.slowDiodeButtons], 'off');
end

end
