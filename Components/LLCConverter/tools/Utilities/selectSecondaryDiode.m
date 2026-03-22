function selectSecondaryDiode(blockPath)
% This is a mask function of LLC Converter Power Circuit block to select
% the secondary Diode device select option.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);
secondaryDiodeChoice = get_param(gcb,'secondaryDeviceOption');
secondaryDiodeLoc = [gcb, '/Rectifier/Full Bridge Rectifier']; 

switch secondaryDiodeChoice
    case 'Ideal Diode'
        set_param(secondaryDiodeLoc, 'LabelModeActiveChoice', 'IdealDiode');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'VsdiodeOn',...
            'RsdiodeOn','GsdiodeOff'},Visibility='on');
        h.getDialogControl("openDiodeMask").Visible = "off"; 
        h.getDialogControl("applyDiodeParam").Visible = "off"; 

    case 'Tabulated Diode'
        set_param(secondaryDiodeLoc, 'LabelModeActiveChoice', 'TabulatedDiode');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'VsdiodeOn',...
            'RsdiodeOn','GsdiodeOff'},Visibility='off');
        h.getDialogControl("openDiodeMask").Visible = "on";
        h.getDialogControl("applyDiodeParam").Visible = "on"; 
        h.getDialogControl("openDiodeMask").Enabled = "on";
        h.getDialogControl("applyDiodeParam").Enabled = "on"; 

    otherwise

        disp('Select proper secondary diode model')
end
end