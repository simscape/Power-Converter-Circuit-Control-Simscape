function applyDABConverterMOSFETParameters(blockPath, bridge)
%APPLYDABCONVERTERMOSFETPARAMS Copy the representative MOSFET's parameters to every MOSFET in a bridge.

% Copyright 2025-2026 The MathWorks, Inc.

basePath = [blockPath, '/DABConverterVariant/DetailedModel'];

switch bridge
    case 'primary'
        srcPath = [basePath, '/PrimaryBridge/SwitchingMOSFETwithThermal/MOSFETPriA1'];
        targetPaths = {
            [basePath, '/PrimaryBridge/SwitchingMOSFETwithThermal/MOSFETPriA2']
            [basePath, '/PrimaryBridge/SwitchingMOSFETwithThermal/MOSFETPriB1']
            [basePath, '/PrimaryBridge/SwitchingMOSFETwithThermal/MOSFETPriB2']
            };
    case 'secondary'
        srcPath = [basePath, '/SecondaryBridge/SwitchingMOSFETwithThermal/MOSFETSecA1'];
        targetPaths = {
            [basePath, '/SecondaryBridge/SwitchingMOSFETwithThermal/MOSFETSecA2']
            [basePath, '/SecondaryBridge/SwitchingMOSFETwithThermal/MOSFETSecB1']
            [basePath, '/SecondaryBridge/SwitchingMOSFETwithThermal/MOSFETSecB2']
            };
    otherwise
        warning('applyDABConverterMOSFETParameters: Invalid bridge argument: %s', bridge);
        return;
end

srcMask = Simulink.Mask.get(srcPath);
if isempty(srcMask)
    warning('applyDABConverterMOSFETParameters: Could not find mask on source MOSFET at %s', srcPath);
    return;
end

paramNames = {srcMask.Parameters.Name};

nApplied = 0;
for t = 1:numel(targetPaths)
    tgtPath = targetPaths{t};
    try
        for p = 1:numel(paramNames)
            val = get_param(srcPath, paramNames{p});
            set_param(tgtPath, paramNames{p}, val);
        end
        nApplied = nApplied + 1;
    catch ME
        warning('applyDABConverterMOSFETParameters: Failed to apply params to %s: %s', tgtPath, ME.message);
    end
end

fprintf('Applied MOSFET parameters from %s source to %d other MOSFETs.\n', bridge, nApplied);

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source MOSFET, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(srcPath, OnIssue="warn");

end
