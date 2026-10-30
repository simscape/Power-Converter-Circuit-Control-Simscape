function selectLLCSeriesInductor(blockPath)
% selectLLCSeriesInductor Callback for series resonant inductor option.
%   Sets the variant active choice on the Lr variant subsystem and
%   shows/hides the Lr parameters based on the selected option.

% Copyright 2026 The MathWorks, Inc.

seriesChoice = get_param(blockPath, 'seriesInductorOption');

% Path to the Lr variant subsystem in the Resonant Tank
lrVariantPath = [blockPath, ...
    '/LLC Primary Inverter and Resonant Tank/LLC Detailed Model/Resonant Tank/Lr'];

switch seriesChoice
    case 'Use external inductance'
        set_param(lrVariantPath, 'LabelModeActiveChoice', 'ExternalInductance');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'Lr', 'Lr_unit', 'RLr', 'RLr_unit'}, Visibility='on');

    case 'Use transformer leakage inductance'
        set_param(lrVariantPath, 'LabelModeActiveChoice', 'LeakageInductance');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'Lr', 'Lr_unit', 'RLr', 'RLr_unit'}, Visibility='off');

    otherwise
        disp('Select a valid series inductor option.');
end

end
