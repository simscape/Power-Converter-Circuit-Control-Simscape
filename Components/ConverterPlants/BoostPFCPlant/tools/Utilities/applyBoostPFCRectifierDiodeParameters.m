function applyBoostPFCRectifierDiodeParameters(blockPath)
%APPLYBOOSTPFCRECTDIODEPARAMS Copy Diode1 parameters to Diode2-4 in TabulatedDiode bridge.

% Copyright 2025-2026 The MathWorks, Inc.

rbBase = [blockPath, '/BoostPFCVariant/DetailedModel/RectifierBridge/TabulatedDiode'];
srcPath = [rbBase '/Diode1'];
srcMask = Simulink.Mask.get(srcPath);

if isempty(srcMask)
    return;
end

params = srcMask.Parameters;
for i = 2:4
    dstPath = [rbBase '/Diode' num2str(i)];
    for p = 1:numel(params)
        try
            val = get_param(srcPath, params(p).Name);
            set_param(dstPath, params(p).Name, val);
        catch
        end
    end
end

% A setting the plant cannot honor is reported, not corrected: what the copy just spread
% across the siblings is what you typed into the source Diode, so the source is the
% one place to check and change.
enforceIntegralDiodeSettings(srcPath, OnIssue="warn");

end
