function selectLLCPlantSecondaryDiode(blockPath)
% This is a mask function of LLC Converter Power Circuit block to select
% the secondary rectifier topology and diode device option.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);
llcConverterChoice = get_param(blockPath,'llcConverterModel');
secondaryDiodeChoice = get_param(blockPath,'secondaryDeviceOption');
rectifierChoice = get_param(blockPath,'rectifierOption');

rectifierBridgeLoc = [blockPath, '/Rectifier/Rectifier Bridge'];

% The "Simulation temperature" parameters (simTempSec/simTempSec_unit) exist only on
% the LLCResonantConverterFullBridge model block, not on the shared library copies.
% Guard every reference so this callback stays valid for blocks without them.
hasSimTempSec = any(strcmp({h.Parameters.Name}, 'simTempSec'));

% Determine active variant from both selections
if strcmp(rectifierChoice, 'Centre-Tap')
    if strcmp(secondaryDiodeChoice, 'Ideal Diode')
        set_param(rectifierBridgeLoc, 'LabelModeActiveChoice', 'CentreTapIdealDiode');
    else
        set_param(rectifierBridgeLoc, 'LabelModeActiveChoice', 'CentreTapTabulatedDiode');
    end
else
    if strcmp(secondaryDiodeChoice, 'Ideal Diode')
        set_param(rectifierBridgeLoc, 'LabelModeActiveChoice', 'FullBridgeIdealDiode');
    else
        set_param(rectifierBridgeLoc, 'LabelModeActiveChoice', 'FullBridgeTabulatedDiode');
    end
end

% Set visibility based on diode type
switch secondaryDiodeChoice
    case 'Ideal Diode'
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'VfSec','VfSec_unit',...
            'RdSec','RdSec_unit',...
            'GdSec','GdSec_unit'},Visibility='on');
        % The ideal diode has no temperature dependence, so hide the temperature.
        if hasSimTempSec
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempSec','simTempSec_unit'},Visibility='off');
        end
        h.getDialogControl("openDiodeMask").Visible = "off";
        h.getDialogControl("applyDiodeParam").Visible = "off";

    case 'Tabulated Diode'
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'VfSec','VfSec_unit',...
            'RdSec','RdSec_unit',...
            'GdSec','GdSec_unit'},Visibility='off');
        % The tabulated diode interpolates its I-V data at a device simulation
        % temperature, so expose it. It is the only temperature input the block has:
        % in this configuration the diode has two electrical ports and no thermal
        % port, so a junction-temperature target on it would be inert.
        if hasSimTempSec
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempSec','simTempSec_unit'},Visibility='on');
        end
        h.getDialogControl("openDiodeMask").Visible = "on";
        h.getDialogControl("applyDiodeParam").Visible = "on";
        h.getDialogControl("openDiodeMask").Enabled = "on";
        h.getDialogControl("applyDiodeParam").Enabled = "on";

    otherwise
        disp('Select proper secondary diode model')
end

% Override if Simplified mode is selected
if strcmp(llcConverterChoice, 'Simplified Half-Bridge')
    set_param(rectifierBridgeLoc, 'LabelModeActiveChoice', 'CentreTapIdealDiode');
    h.getDialogControl("openDiodeMask").Visible = "off";
    h.getDialogControl("applyDiodeParam").Visible = "off";
    % Simplified forces the ideal center-tap rectifier, so no tabulated data is in play.
    if hasSimTempSec
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'simTempSec','simTempSec_unit'},Visibility='off');
    end
end
end
