function opValues = operatingPointValues(opArgs)
%OPERATINGPOINTVALUES Convert operating-point arguments to base-SI values.
%   opValues = OPERATINGPOINTVALUES(opArgs)
%
%   Inputs:
%     opArgs    Struct of operating-point arguments, each optional:
%                 Vin, Vout, Vref     voltages, V
%                 Iref, Iin, Iout     currents, A
%                 Pload               power, W
%                 ControlMode         "voltage" or "current"
%                 PowerFlowDirection  "forward" or "reverse"
%
%   Outputs:
%     opValues  Struct of base-SI values, with a field only for each non-empty input.

% Copyright 2026 The MathWorks, Inc.

opValues = struct();

% Convert each physical quantity to its base-SI unit.
physUnits = struct('Vin',"V", 'Vout',"V", 'Vref',"V", ...
                   'Iref',"A", 'Iin',"A", 'Iout',"A", 'Pload',"W");
physNames = fieldnames(physUnits);
for i = 1:numel(physNames)
    q = physNames{i};
    if isfield(opArgs, q) && ~isempty(opArgs.(q))
        opValues.(q) = toBaseSI(opArgs.(q), physUnits.(q));
    end
end

% Copy the control selectors as strings.
for q = ["ControlMode","PowerFlowDirection"]
    if isfield(opArgs, q) && ~isempty(opArgs.(q))
        opValues.(q) = string(opArgs.(q));
    end
end
end

% ======================================================================
function v = toBaseSI(x, unit)
% Convert a simscape.Value or numeric to a double in the given unit.
if isa(x, 'simscape.Value')
    xc = convert(x, unit);
    v = xc.value;
else
    v = double(x);   % numeric is already base SI
end
end
