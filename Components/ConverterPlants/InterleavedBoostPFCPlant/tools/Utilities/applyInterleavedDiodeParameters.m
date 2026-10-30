function applyInterleavedDiodeParameters(blockPath)
%APPLYINTERLEAVEDDIODEPARAMS Apply Diode parameters to all interleaved boost diodes.
%   Copies mask parameters from BoostDiode1 Diode (representative)
%   to BoostDiode2 Diode.

% Copyright 2025-2026 The MathWorks, Inc.

basePath = [blockPath, '/InterleavedBoostPFCVariant/DetailedModel'];

% Source: BoostDiode1 Diode (the one opened by "Open Diode Mask")
srcPath = [basePath, '/BoostDiode1/TabulatedDiode/Diode1'];

% Target: BoostDiode2 Diode
targetPaths = {
    [basePath, '/BoostDiode2/TabulatedDiode/Diode1']
    };

% Get all mask parameter names from source Diode
srcMask = Simulink.Mask.get(srcPath);
if isempty(srcMask)
    warning('applyInterleavedDiodeParameters: Could not find mask on source Diode at %s', srcPath);
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
        warning('applyInterleavedDiodeParameters: Failed to apply params to %s: %s', tgtPath, ME.message);
    end
end

fprintf('Applied Diode parameters from BoostDiode1 to %d other Diode(s).\n', nApplied);

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source Diode, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(srcPath, OnIssue="warn");

end
