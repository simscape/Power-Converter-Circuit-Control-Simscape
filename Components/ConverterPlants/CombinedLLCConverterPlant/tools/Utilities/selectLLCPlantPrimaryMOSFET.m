function selectLLCPlantPrimaryMOSFET(blockPath)
% This is a mask function of LLC Converter Power Circuit block to select
% the primary MOSFET device option.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);
llcConverterChoice = get_param(blockPath,'llcConverterModel');
llcConverterLoc = [blockPath, '/LLC Primary Inverter and Resonant Tank'];
primarySwitchChoice = get_param(blockPath,'primaryDeviceOption');
primarySwitchLoc = [blockPath, '/LLC Primary Inverter and Resonant Tank/LLC Detailed Model/Inverter/Primary Inverter'];

% The "Simulation temperature" parameters (simTempPri/simTempPri_unit) exist only on
% the LLCResonantConverterFullBridge model block, not on the shared library copies.
% Guard every reference so this callback stays valid for blocks without them.
hasSimTempPri = any(strcmp({h.Parameters.Name}, 'simTempPri'));

switch primarySwitchChoice
    case 'Ideal Semiconductor Switch'

        switch llcConverterChoice
            case 'Detailed Half-Bridge'
                set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'HalfBridgewithoutThermal');
            case 'Detailed Full-Bridge'
                set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'FullBridgewithoutThermal');
        end

        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'primaryDeviceOption',...
            'RdsOn','RdsOn_unit','GdsOff','GdsOff_unit','Vth','Vth_unit',...
            'VfBody','VfBody_unit','RdBody','RdBody_unit',...
            'GdBody','GdBody_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'Cdsparasitic','Cdsparasitic_unit'},Visibility='off');
        % Simulation temperature applies only to the thermal MOSFET device, so hide it.
        if hasSimTempPri
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempPri','simTempPri_unit'},Visibility='off');
        end

        h.getDialogControl("openMOSFETMask").Visible = "off";
        h.getDialogControl("applyMOSFETParam").Visible = "off";

    case 'MOSFET (Ideal, Switching) with Thermal'

        switch llcConverterChoice
            case 'Detailed Half-Bridge'
                set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'HalfBridgewithThermal');
            case 'Detailed Full-Bridge'
                set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'FullBridgewithThermal');
        end

        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'primaryDeviceOption',...
            'Cdsparasitic','Cdsparasitic_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOn','RdsOn_unit','GdsOff','GdsOff_unit','Vth','Vth_unit',...
            'VfBody','VfBody_unit','RdBody','RdBody_unit',...
            'GdBody','GdBody_unit'},Visibility='off');
        % The thermal MOSFET device runs at a fixed junction temperature, so expose it.
        if hasSimTempPri
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempPri','simTempPri_unit'},Visibility='on');
        end

        h.getDialogControl("openMOSFETMask").Visible = "on";
        h.getDialogControl("applyMOSFETParam").Visible = "on";
        h.getDialogControl("openMOSFETMask").Enabled = "on";
        h.getDialogControl("applyMOSFETParam").Enabled = "on";

    otherwise
        disp('Select the proper primary switch option')
end
end
