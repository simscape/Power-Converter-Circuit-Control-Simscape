function applyInterleavedRectifierDiodeParameters(blockPath)
%APPLYINTERLEAVEDRECTDIODEPARAMS Apply rectifier diode parameters to all bridge diodes.
%   Copies mask parameters from RectifierBridge/TabulatedDiode/Diode1
%   (representative) to Diode2, Diode3, and Diode4.

% Copyright 2025-2026 The MathWorks, Inc.

basePath = [blockPath, '/InterleavedBoostPFCVariant/DetailedModel/RectifierBridge/TabulatedDiode'];

% Source: Diode1 (the one opened by "Open Rectifier Diode Mask")
srcPath = [basePath, '/Diode1'];

% Targets: Diode2, Diode3, Diode4
targetPaths = {
    [basePath, '/Diode2']
    [basePath, '/Diode3']
    [basePath, '/Diode4']
    };

% Get all mask parameter names from source Diode
srcMask = Simulink.Mask.get(srcPath);
if isempty(srcMask)
    warning('applyInterleavedRectifierDiodeParameters: Could not find mask on source Diode at %s', srcPath);
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
        warning('applyInterleavedRectifierDiodeParameters: Failed to apply params to %s: %s', tgtPath, ME.message);
    end
end

fprintf('Applied Rectifier Diode parameters from Diode1 to %d other Diode(s).\n', nApplied);

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source Diode, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(srcPath, OnIssue="warn");

end
