function selectLLCPlantModel(blockPath)
% This is a mask function of LLC Converter Power Circuit block to select
% the LLC converter model option.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);
llcConverterChoice = get_param(blockPath,'llcConverterModel');
llcConverterLoc = [blockPath, '/LLC Primary Inverter and Resonant Tank'];

switch llcConverterChoice
    case 'Simplified Half-Bridge'

        set_param(llcConverterLoc, 'LabelModeActiveChoice', 'SimplifiedModel');

        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOn','RdsOn_unit','GdsOff','GdsOff_unit','Vth','Vth_unit',...
            'VfBody','VfBody_unit','RdBody','RdBody_unit',...
            'GdBody','GdBody_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'VfSec','VfSec_unit',...
            'RdSec','RdSec_unit',...
            'GdSec','GdSec_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'secondaryDeviceOption','primaryDeviceOption',...
            'Cdsparasitic','Cdsparasitic_unit','rectifierOption'},Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'seriesInductorOption','Lr','Lr_unit','RLr','RLr_unit'},Visibility='off');
        h.getDialogControl("openMOSFETMask").Visible = "off";
        h.getDialogControl("applyMOSFETParam").Visible = "off";
        h.getDialogControl("openDiodeMask").Visible = "off";
        h.getDialogControl("applyDiodeParam").Visible = "off";

    case 'Detailed Half-Bridge'
        set_param(llcConverterLoc, 'LabelModeActiveChoice', 'DetailedModel');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'rectifierOption','secondaryDeviceOption'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'seriesInductorOption'},Visibility='on');
        selectLLCSeriesInductor(blockPath);
        selectLLCPlantPrimaryMOSFET(blockPath);
        selectLLCPlantSecondaryDiode(blockPath);

    case 'Detailed Full-Bridge'
        set_param(llcConverterLoc, 'LabelModeActiveChoice', 'DetailedModel');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'rectifierOption','secondaryDeviceOption'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'seriesInductorOption'},Visibility='on');
        selectLLCSeriesInductor(blockPath);
        selectLLCPlantPrimaryMOSFET(blockPath);
        selectLLCPlantSecondaryDiode(blockPath);

    otherwise
        disp('Select the proper LLC converter model option')
end
end
