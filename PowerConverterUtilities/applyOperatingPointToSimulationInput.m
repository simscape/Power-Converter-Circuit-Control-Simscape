function simIn = applyOperatingPointToSimulationInput(simIn, modelName, reg, opValues)
%APPLYOPERATINGPOINTTOSIMULATIONINPUT Set a converter's operating point on its harness blocks.
%   simIn = APPLYOPERATINGPOINTTOSIMULATIONINPUT(simIn, modelName, reg, opValues)
%
%   Inputs:
%     simIn      Simulink.SimulationInput to add the block parameters to.
%     modelName  Model name.
%     reg        Registry entry from converterRegistry.
%     opValues   Struct of base-SI operating-point values, from operatingPointValues.
%
%   Outputs:
%     simIn      Simulink.SimulationInput with one block parameter per resolved quantity.
%
%   Descriptor fields of reg.operatingPoint:
%     .quantity   Quantity name in opValues.
%     .block      Harness block name.
%     .param      Block parameter to set.
%     .required   true to error when no value resolves.
%     .transform  Function of opValues that returns the value, or [].

% Copyright 2026 The MathWorks, Inc.

spec = reg.operatingPoint;
for i = 1:numel(spec)
    d = spec(i);

    % Take the value from the transform, else from opValues.
    v = [];
    if ~isempty(d.transform)
        v = d.transform(opValues);
    elseif isfield(opValues, d.quantity) && ~isempty(opValues.(d.quantity))
        v = opValues.(d.quantity);
    end

    if isempty(v)
        if d.required
            error('applyOperatingPointToSimulationInput:missingQuantity', ...
                ['Operating-point quantity "%s" is required for this converter but ' ...
                 'was not supplied (nor computable). Provide it as a name-value argument.'], ...
                d.quantity);
        end
        continue;   % keep the block's saved value
    end

    blkPath = [char(modelName) '/' char(d.block)];
    if getSimulinkBlockHandle(blkPath) <= 0
        if d.required
            error('applyOperatingPointToSimulationInput:missingBlock', ...
                'Operating-point block "%s" not found in model "%s".', d.block, modelName);
        end
        continue;
    end
    simIn = setBlockParameter(simIn, blkPath, d.param, num2str(v));
end
end
