function selectIGBTModelDiodeOption(blockPath)
%SELECTIGBTMODELDIODEOPTION Mask callback for the IGBT Model diode option.
%   Selects whether the anti-parallel (free-wheeling) diode is built into the
%   block or supplied externally, and shows or hides the diode parameters
%   accordingly:
%     - "Inbuilt diode": a Simscape Diode sits anti-parallel with the IGBT
%       (anode at E, cathode at C). Its current is probed and drives the diode
%       conduction-loss lookup, so the diode loss heats the same junction as
%       the IGBT.
%     - "External diode": the internal branch becomes an open circuit and the
%       probed diode current is forced to zero, so the diode contributes no
%       conduction loss. Connect your own diode across the C and E terminals.
%
%   An IGBT cannot conduct in reverse, so the anti-parallel diode is never
%   gated: it conducts whenever it is forward biased. This is the deliberate
%   difference from the SiC MOSFET Model block. There the channel carries all the
%   reverse current, and the body diode is gated off.

% Copyright 2026 The MathWorks, Inc.

diodeChoice = get_param(blockPath, 'diodeOption');

% Variant subsystem that holds the two diode branch choices.
variantPath = [blockPath, '/Antiparallel Diode'];

% Parameters that only mean anything while the diode is inside the block.
diodeParameters = {'diodeVf',   'diodeVf_unit',   ...
                   'diodeRon',  'diodeRon_unit',  ...
                   'diodeGoff', 'diodeGoff_unit', ...
                   'Tj_diode',  'Tj_diode_unit',  ...
                   'If_data',   'If_data_unit',   ...
                   'Vf_data',   'Vf_data_unit'};

switch diodeChoice
    case 'Inbuilt diode'
        set_param(variantPath, 'LabelModeActiveChoice', 'InbuiltDiode');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=diodeParameters, Visibility='on');

    case 'External diode'
        set_param(variantPath, 'LabelModeActiveChoice', 'ExternalDiode');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=diodeParameters, Visibility='off');

    otherwise
        disp('Select a valid anti-parallel diode option.');
end

end
