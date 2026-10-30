function selectDCDCMainSwitch(blockPath)
%SELECTDCDCMAINSWITCH Mask callback for switch device variant selection.
%   Sets the MainSwitch variant in all topologies.
%   For synchronous variants, also sets the SyncSwitch variant.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'switchDeviceOption');

% Normal topologies have MainSwitch
normalTopologies = {'Buck', 'Boost', 'BuckBoost'};
for k = 1:numel(normalTopologies)
    variantPath = [blockPath, '/NonIsolatedDCDCVariant/', normalTopologies{k}, '/MainSwitch'];
    switch choice
        case 'Ideal Switch'
            set_param(variantPath, 'LabelModeActiveChoice', 'IdealSwitch');
        case 'MOSFET (Ideal, Switching) with Thermal'
            set_param(variantPath, 'LabelModeActiveChoice', 'SwitchingMOSFETwithThermal');
    end
end

% Synchronous topologies have both MainSwitch and SyncSwitch
syncTopologies = {'SynchronousBuck', 'SynchronousBoost', 'SynchronousBuckBoost'};
for k = 1:numel(syncTopologies)
    msPath = [blockPath, '/NonIsolatedDCDCVariant/', syncTopologies{k}, '/MainSwitch'];
    ssPath = [blockPath, '/NonIsolatedDCDCVariant/', syncTopologies{k}, '/SyncSwitch'];
    switch choice
        case 'Ideal Switch'
            set_param(msPath, 'LabelModeActiveChoice', 'IdealSwitch');
            set_param(ssPath, 'LabelModeActiveChoice', 'IdealSwitch');
        case 'MOSFET (Ideal, Switching) with Thermal'
            set_param(msPath, 'LabelModeActiveChoice', 'SwitchingMOSFETwithThermal');
            set_param(ssPath, 'LabelModeActiveChoice', 'SwitchingMOSFETwithThermal');
    end
end

% Manage visibility. The ideal switch takes its channel and body-diode data from these
% mask parameters. The thermal MOSFET carries its own datasheet data on its block dialog,
% reached through the 'Open MOSFET block mask' button, so the mask parameters are hidden for
% it rather than offering values the device does not use.
idealSwitchParameters = {'RdsOn', 'RdsOn_unit', 'GdsOff', 'GdsOff_unit', ...
    'Vth', 'Vth_unit', 'VfBody', 'VfBody_unit', 'RdBody', 'RdBody_unit', ...
    'GdBody', 'GdBody_unit'};
h = Simulink.Mask.get(blockPath);
if strcmp(choice, 'Ideal Switch')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=idealSwitchParameters, Visibility='on');
    h.getDialogControl('openMOSFETMask').Visible = 'off';
elseif strcmp(choice, 'MOSFET (Ideal, Switching) with Thermal')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec=idealSwitchParameters, Visibility='off');
    h.getDialogControl('openMOSFETMask').Visible = 'on';
end

% The simulation temperature belongs to whichever devices are selected.
updateDCDCTemperatureVisibility(blockPath);

end
