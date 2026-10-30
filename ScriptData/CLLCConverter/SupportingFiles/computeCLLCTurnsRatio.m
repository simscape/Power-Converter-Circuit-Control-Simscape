function turnsRatioData = computeCLLCTurnsRatio(CLLCSpec, options)
%   This function computes the transformer turns ratio of a CLLC resonant converter
%   from a ratio you specify, or from the voltage specification and the selected
%   turns-ratio strategy. It is shared by designCLLCFullBridgeConverter and
%   computeCLLCMagnetizingCurrentLimit so that the two can never disagree about the
%   ratio, the winding counts, or the primary-referred voltages derived from them.
%
%   Inputs:
%     CLLCSpec   Struct containing CLLC converter specifications. Required fields:
%                 - minInputVoltage / maxInputVoltage   (simscape.Value, V)
%                 - minOutputVoltage / maxOutputVoltage (simscape.Value, V)
%                 - turnratioVoltageLevel: Which voltage pair anchors the ratio. One of
%                     "Average Output and Input Voltage"
%                     "Max Output Voltage and Min Input Voltage"
%                     "Min Output Voltage and Max Input Voltage"
%                   Not read when the TurnsRatio option is set.
%
%     options   Structure with optional fields:
%                 - N2: Secondary winding turns, the anchor for the winding counts
%                   (default: 10). CLLC anchors the secondary because its tank is
%                   symmetric and the secondary arm is referred to the primary.
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). Set it to
%                   raise or lower the ratio away from the voltage pair, which is how you
%                   trade gain headroom against magnetizing current. A lower ratio raises
%                   the gain the tank must supply; a higher one lowers it. The value is
%                   the DESIGNED ratio, so the winding counts are
%                   still rounded from it, exactly as a derived ratio is. To specify an
%                   exact winding pair, set TurnsRatio to N1/N2 for your own N2.
%
%   Output:
%     turnsRatioData   Struct with fields:
%                 - designTurnsRatio: Unrounded ratio from the strategy, or the
%                   ratio the caller specified. This is the ratio used to size the tank,
%                   because the tank is sized before the windings are rounded to integers.
%                 - realizedTurnsRatio: N1/N2, the ratio the transformer block
%                   realizes. Every secondary-to-primary referral must use this one.
%                 - N1: Primary winding turns (integer).
%                 - N2: Secondary winding turns (integer).
%                 - isTurnsRatioSpecified: Logical. True when the ratio came from the
%                   TurnsRatio option rather than from the voltage specification.
%
%   Example:
%     CLLCSpec.minInputVoltage = simscape.Value(350, "V");
%     CLLCSpec.maxInputVoltage = simscape.Value(400, "V");
%     CLLCSpec.minOutputVoltage = simscape.Value(300, "V");
%     CLLCSpec.maxOutputVoltage = simscape.Value(400, "V");
%     CLLCSpec.turnratioVoltageLevel = "Average Output and Input Voltage";
%     turnsRatioData = computeCLLCTurnsRatio(CLLCSpec);
%
%     % The same transformer, with the ratio specified instead of derived
%     turnsRatioData = computeCLLCTurnsRatio(CLLCSpec, N2=29, TurnsRatio=0.9655);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    CLLCSpec struct
    options.N2 (1,1) {mustBePositive, mustBeInteger} = 10
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = []
end

isTurnsRatioSpecified = ~isempty(options.TurnsRatio);

if isTurnsRatioSpecified
    % The caller gave the ratio outright, so the voltage pair is not read at all. The
    % number is the designed ratio, the same quantity the strategy below produces, which
    % keeps everything downstream - the tank sizing, the winding rounding and the
    % primary-referred voltages - on one definition.
    designTurnsRatio = options.TurnsRatio;
else
    avgInputVoltage = (CLLCSpec.minInputVoltage + CLLCSpec.maxInputVoltage) / 2;
    avgOutputVoltage = (CLLCSpec.minOutputVoltage + CLLCSpec.maxOutputVoltage) / 2;

    % Anchor the ratio on the voltage pair you selected. The average pair centers the
    % gain requirement in both power-flow directions and is the natural choice for a
    % bidirectional converter. The extreme pairs bias the design towards one end of the
    % voltage window, which is useful when one direction needs more boost headroom.
    switch CLLCSpec.turnratioVoltageLevel
        case "Average Output and Input Voltage"
            designTurnsRatio = avgInputVoltage / avgOutputVoltage;
        case "Max Output Voltage and Min Input Voltage"
            designTurnsRatio = CLLCSpec.minInputVoltage / CLLCSpec.maxOutputVoltage;
        case "Min Output Voltage and Max Input Voltage"
            designTurnsRatio = CLLCSpec.maxInputVoltage / CLLCSpec.minOutputVoltage;
        otherwise
            error("computeCLLCTurnsRatio:UnknownStrategy", ...
                "Unknown turnratioVoltageLevel ""%s"". Expected one of " + ...
                """Average Output and Input Voltage"", " + ...
                """Max Output Voltage and Min Input Voltage"", or " + ...
                """Min Output Voltage and Max Input Voltage"".", ...
                string(CLLCSpec.turnratioVoltageLevel));
    end

    designTurnsRatio = value(designTurnsRatio, "1");
end

% The transformer needs integer winding counts, so the ratio the converter
% realizes differs slightly from the designed one.
turnsRatioData.designTurnsRatio = designTurnsRatio;
turnsRatioData.isTurnsRatioSpecified = isTurnsRatioSpecified;
turnsRatioData.N2 = options.N2;
turnsRatioData.N1 = round(designTurnsRatio * options.N2);
turnsRatioData.realizedTurnsRatio = turnsRatioData.N1 / turnsRatioData.N2;

end
