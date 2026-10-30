function selectDCDCDiodeDevice(blockPath)
%SELECTDCDCDIODEDEVICE Mask callback for diode device variant selection.
%   Sets the Diode variant in all normal (non-synchronous) topologies.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'diodeDeviceOption');

% Only normal topologies have a Diode variant
topologies = {'Buck', 'Boost', 'BuckBoost'};
for k = 1:numel(topologies)
    variantPath = [blockPath, '/NonIsolatedDCDCVariant/', topologies{k}, '/Diode'];
    switch choice
        case 'Ideal Diode'
            set_param(variantPath, 'LabelModeActiveChoice', 'IdealDiode');
        case 'Tabulated Diode'
            set_param(variantPath, 'LabelModeActiveChoice', 'TabulatedDiode');
        otherwise
            warning('selectDCDCDiodeDevice: Invalid selection: %s', choice);
    end
end

% Manage visibility
h = Simulink.Mask.get(blockPath);
if strcmp(choice, 'Ideal Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'Vf', 'Vf_unit', 'Rd', 'Rd_unit', 'Gd', 'Gd_unit'}, ...
        Visibility='on');
    h.getDialogControl('openDiodeMask').Visible = 'off';
elseif strcmp(choice, 'Tabulated Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'Vf', 'Vf_unit', 'Rd', 'Rd_unit', 'Gd', 'Gd_unit'}, ...
        Visibility='off');
    h.getDialogControl('openDiodeMask').Visible = 'on';
end

% The simulation temperature belongs to whichever devices are selected.
updateDCDCTemperatureVisibility(blockPath);

end
