function selectPrimaryMOSFET(blockPath)
% This is a mask function of LLC Converter Power Circuit block to select
% the primary MOSFET device select option.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);
primarySwitchChoice = get_param(blockPath,'primaryDeviceOption');
primarySwitchLoc = [blockPath, '/Inverter/Inverter Full Bridge']; 

switch primarySwitchChoice
    case 'Ideal Semiconductor Switch'

        set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'IdealSwitch');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Ron','Goff','Vth',...
            'VbodydiodeOn','RbodydiodeOn','GbodydiodeOff'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Cparasitic'},Visibility='off');
        
        h.getDialogControl("openMOSFETMask").Visible = "off";    
        h.getDialogControl("applyMOSFETParam").Visible = "off"; 

    case 'MOSFET (Ideal, Switching) without Thermal'
        set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'IdealMOSFETwithoutThermal');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Ron','Goff','Vth',...
            'VbodydiodeOn','RbodydiodeOn','GbodydiodeOff'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Cparasitic'},Visibility='off');
        
        h.getDialogControl("openMOSFETMask").Visible = "off";
        h.getDialogControl("applyMOSFETParam").Visible = "off"; 

   case 'MOSFET (Ideal, Switching) with Thermal'
       set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'IdealMOSFETwithThermal');

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Ron','Goff','Vth',...
           'VbodydiodeOn','RbodydiodeOn','GbodydiodeOff'},Visibility='off');
       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Cparasitic'},Visibility='on');
       h.getDialogControl("openMOSFETMask").Visible = "on";
       h.getDialogControl("applyMOSFETParam").Visible = "on"; 

    otherwise
        disp('Select the proper primary switch option')
end
end