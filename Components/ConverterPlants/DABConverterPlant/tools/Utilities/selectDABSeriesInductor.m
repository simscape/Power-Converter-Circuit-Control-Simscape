function selectDABSeriesInductor(blockPath)
%SELECTDABSERIESINDUCTOR Mask callback for the DAB series inductance option.
%   Selects how the series inductance is realized and shows/hides the
%   external series inductor parameters accordingly:
%     - "Use external inductance": a discrete series inductor (Lr, RLr) is
%       placed in series with the transformer. The transformer keeps its own
%       per-winding leakage (Llk1, Llk2).
%     - "Use transformer leakage inductance": the discrete inductor is
%       bypassed (pass-through short) and the series inductance is provided
%       solely by the transformer leakage.
%
%   The option is applied to BOTH model variants, Detailed and Simplified,
%   which each contain the Lr variant subsystem. The setting is therefore
%   consistent whichever model is active. The transformer
%   parameters are not touched here; the transformer always carries its
%   per-winding leakage.

% Copyright 2026 The MathWorks, Inc.

seriesChoice = get_param(blockPath, 'seriesInductorOption');

% Series-inductance variant subsystem inside each model choice.
variantPath      = [blockPath, '/DABConverterVariant'];
lrDetailedPath   = [variantPath, '/DetailedModel/Lr'];
lrSimplifiedPath = [variantPath, '/SimplifiedModel/Lr'];

switch seriesChoice
    case 'Use external inductance'
        set_param(lrDetailedPath,   'LabelModeActiveChoice', 'ExternalInductance');
        set_param(lrSimplifiedPath, 'LabelModeActiveChoice', 'ExternalInductance');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'Lr', 'Lr_unit', 'RLr', 'RLr_unit'}, Visibility='on');

    case 'Use transformer leakage inductance'
        set_param(lrDetailedPath,   'LabelModeActiveChoice', 'LeakageInductance');
        set_param(lrSimplifiedPath, 'LabelModeActiveChoice', 'LeakageInductance');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'Lr', 'Lr_unit', 'RLr', 'RLr_unit'}, Visibility='off');

    otherwise
        disp('Select a valid series inductor option.');
end

end
