function selectDCDCModelOption(blockPath)
%SELECTDCDCMODELOPTION Mask callback for topology variant selection.
%   Handles 6 topology choices: Buck, Synchronous Buck, Boost,
%   Synchronous Boost, Buck-Boost, Synchronous Buck-Boost.
%   Normal variants have a single gate (G) and a freewheeling diode.
%   Synchronous variants have two gates (G1, G2) and two switches.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'modelOption');

variantPath = [blockPath, '/NonIsolatedDCDCVariant'];
switch choice
    case 'Buck'
        set_param(variantPath, 'LabelModeActiveChoice', 'Buck');
    case 'Synchronous Buck'
        set_param(variantPath, 'LabelModeActiveChoice', 'SynchronousBuck');
    case 'Boost'
        set_param(variantPath, 'LabelModeActiveChoice', 'Boost');
    case 'Synchronous Boost'
        set_param(variantPath, 'LabelModeActiveChoice', 'SynchronousBoost');
    case 'Buck-Boost'
        set_param(variantPath, 'LabelModeActiveChoice', 'BuckBoost');
    case 'Synchronous Buck-Boost'
        set_param(variantPath, 'LabelModeActiveChoice', 'SynchronousBuckBoost');
    otherwise
        warning('selectDCDCModelOption: Invalid selection: %s', choice);
end

% Determine if this is a synchronous variant
isSynchronous = contains(choice, 'Synchronous');

% Manage diode group visibility
h = Simulink.Mask.get(blockPath);
if isSynchronous
    % Hide the diode device group (synchronous variants have no diode)
    h.getDialogControl('DiodeDevice').Visible = 'off';
else
    % Show diode device group
    h.getDialogControl('DiodeDevice').Visible = 'on';
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'diodeDeviceOption'}, Visibility='on');
    % Cascade to diode device callback to manage diode param visibility
    selectDCDCDiodeDevice(blockPath);
end

% Cascade to switch device callback (applies to all variants)
selectDCDCMainSwitch(blockPath);

end
