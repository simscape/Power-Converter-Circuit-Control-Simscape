function updateDCDCTemperatureVisibility(blockPath)
%UPDATEDCDCTEMPERATUREVISIBILITY Show the simulation temperature when it applies.
%   The Switch Device group holds one temperature for every temperature-sensitive
%   device: the thermal MOSFET junction target and its Temperature Source, and the
%   tabulated diode device temperature. Shown only when one of those is selected.

% Copyright 2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);

% The library copies of this plant predate the parameter and share this callback.
if ~any(strcmp({h.Parameters.Name}, 'simTemp'))
    return;
end

hasThermalSwitch = strcmp(get_param(blockPath, 'switchDeviceOption'), ...
    'MOSFET (Ideal, Switching) with Thermal');

% Synchronous topologies have no diode position.
isSynchronous = contains(get_param(blockPath, 'modelOption'), 'Synchronous');
hasTabulatedDiode = ~isSynchronous && ...
    strcmp(get_param(blockPath, 'diodeDeviceOption'), 'Tabulated Diode');

if hasThermalSwitch || hasTabulatedDiode
    visibility = 'on';
else
    visibility = 'off';
end

setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'simTemp', 'simTemp_unit'}, Visibility=visibility);

end
