function applyInterleavedMOSFETParameters(blockPath)
%APPLYINTERLEAVEDMOSFETPARAMS Apply MOSFET parameters to all interleaved boost switches.
%   Copies mask parameters from BoostSwitch1 MOSFET (representative)
%   to BoostSwitch2 MOSFET.

% Copyright 2025-2026 The MathWorks, Inc.

basePath = [blockPath, '/InterleavedBoostPFCVariant/DetailedModel'];

% Source: BoostSwitch1 MOSFET (the one opened by "Open MOSFET Mask")
srcPath = [basePath, '/BoostSwitch1/SwitchingMOSFETwithThermal/MOSFET'];

% Target: BoostSwitch2 MOSFET
targetPaths = {
    [basePath, '/BoostSwitch2/SwitchingMOSFETwithThermal/MOSFET']
    };

% Get all mask parameter names from source MOSFET
srcMask = Simulink.Mask.get(srcPath);
if isempty(srcMask)
    warning('applyInterleavedMOSFETParameters: Could not find mask on source MOSFET at %s', srcPath);
    return;
end

paramNames = {srcMask.Parameters.Name};

% Copy each parameter value from source to all targets
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
        warning('applyInterleavedMOSFETParameters: Failed to apply params to %s: %s', tgtPath, ME.message);
    end
end

fprintf('Applied MOSFET parameters from BoostSwitch1 to %d other MOSFET(s).\n', nApplied);

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source MOSFET, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(srcPath, OnIssue="warn");

end
