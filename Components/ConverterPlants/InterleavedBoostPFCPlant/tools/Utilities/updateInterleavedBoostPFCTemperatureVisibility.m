function updateInterleavedBoostPFCTemperatureVisibility(blockPath)
%UPDATEINTERLEAVEDBOOSTPFCTEMPERATUREVISIBILITY Show the device simulation temperature when it applies.
%   The "Boost Stage Devices" group holds one temperature that reaches three kinds of
%   target in the Detailed variant: each leg's thermal MOSFET junction-temperature target,
%   each leg's Temperature Source, and every tabulated diode's device simulation
%   temperature. The Simplified variant has none of them, and the ideal switch/diode
%   choices carry no temperature dependence. So the parameter is shown only when the Detailed
%   variant has at least one temperature-sensitive device selected.

% Copyright 2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);

% The temperature pair and its note are optional: the shared library copies of this plant
% predate them, and these callbacks are shared with those copies.
if ~any(strcmp({h.Parameters.Name}, 'simTemp'))
    return;
end

isDetailed = strcmp(get_param(blockPath, 'modelOption'), 'Detailed');
hasThermalSwitch = strcmp(get_param(blockPath, 'switchDeviceOption'), ...
    'MOSFET (Ideal, Switching) with Thermal');
hasTabulatedBoostDiode = strcmp(get_param(blockPath, 'diodeDeviceOption'), 'Tabulated Diode');
hasTabulatedRectifier = strcmp(get_param(blockPath, 'rectDiodeDeviceOption'), 'Tabulated Diode');

temperatureApplies = isDetailed && ...
    (hasThermalSwitch || hasTabulatedBoostDiode || hasTabulatedRectifier);

if temperatureApplies
    visibility = 'on';
else
    visibility = 'off';
end

% The pair sits in the device group itself, next to the switch parameters it belongs with,
% so there is no group and no explanatory text to hide alongside it - only the two
% parameters, as in DAB.
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'simTemp', 'simTemp_unit'}, Visibility=visibility);

end
