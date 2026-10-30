function turnsRatioData = computeLLCTurnsRatio(LLCSpec, options)
%   This function computes the transformer turns ratio of an LLC resonant converter
%   from a ratio you specify, or from the voltage specification and the selected
%   turns-ratio strategy. It is shared by designLLCFullBridgeConverter and
%   computeMagnetizingCurrentLimit so that the two can never disagree about the ratio,
%   the winding counts, or the effective load resistance derived from them.
%
%   Inputs:
%     LLCSpec   Struct containing LLC converter specifications. Required fields:
%                 - minInputVoltage / maxInputVoltage   (simscape.Value, V)
%                 - minOutputVoltage / maxOutputVoltage (simscape.Value, V)
%                 - LLCModelOption: "Full-Bridge" or "Half-Bridge". The primary inverter
%                   of a half bridge applies half the input voltage to the tank, so the
%                   turns ratio is halved with it.
%                 - turnratioVoltageLevel: Which voltage pair anchors the ratio. One of
%                     "Average Output and Input Voltage"
%                     "Max Output Volttage and Min Input Voltage"
%                     "Min Output Voltage and Max Input Voltage"
%                   Not read when the TurnsRatio option is set.
%
%     options   Structure with optional fields:
%                 - N1: Primary winding turns, the anchor for the winding counts
%                   (default: 50). The LLC transfers power one way, so the primary is
%                   the natural anchor.
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). Set it to
%                   raise or lower the ratio away from the voltage pair, which is how you
%                   trade gain headroom against magnetizing current. A lower ratio raises
%                   the gain the tank must supply; a higher one lowers it. The value is
%                   the DESIGNED ratio, so the winding counts are still rounded from it,
%                   exactly as a derived ratio is. To specify an exact winding pair, set
%                   TurnsRatio to N1/N2 for your own N1.
%
%   Output:
%     turnsRatioData   Struct with fields:
%                 - designTurnsRatio: Unrounded ratio from the strategy, or the ratio the
%                   caller specified. This is the ratio used to size the tank, because the
%                   tank is sized before the windings are rounded to integers.
%                 - realizedTurnsRatio: N1/N2, the ratio the transformer block actually
%                   realizes. Every secondary-to-primary referral must use this one.
%                 - N1: Primary winding turns (integer).
%                 - N2: Secondary winding turns (integer).
%                 - isTurnsRatioSpecified: Logical. True when the ratio came from the
%                   TurnsRatio option rather than from the voltage specification.
%
%   Example:
%     LLCSpec.LLCModelOption = "Full-Bridge";
%     LLCSpec.minInputVoltage = simscape.Value(380, "V");
%     LLCSpec.maxInputVoltage = simscape.Value(400, "V");
%     LLCSpec.minOutputVoltage = simscape.Value(350, "V");
%     LLCSpec.maxOutputVoltage = simscape.Value(400, "V");
%     LLCSpec.turnratioVoltageLevel = "Average Output and Input Voltage";
%     turnsRatioData = computeLLCTurnsRatio(LLCSpec);
%
%     % The same transformer, with the ratio specified instead of derived
%     turnsRatioData = computeLLCTurnsRatio(LLCSpec, N1=50, TurnsRatio=0.9595);

% Copyright 2026 The MathWorks, Inc.

arguments
    LLCSpec struct
    options.N1 (1,1) {mustBePositive, mustBeInteger} = 50
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = []
end

isTurnsRatioSpecified = ~isempty(options.TurnsRatio);

if isTurnsRatioSpecified
    % The caller gave the ratio outright, so the voltage pair is not read at all. The
    % number is the designed ratio, the same quantity the strategy below produces, which
    % keeps everything downstream - the tank sizing, the winding rounding and the
    % secondary-to-primary referral - on one definition.
    designTurnsRatio = options.TurnsRatio;
else
    % A half-bridge primary inverter applies half the input voltage to the tank, so the
    % ratio that meets the same output voltage is half the full-bridge one.
    topologyFactor = llcPrimaryBridgeTopologyFactor(LLCSpec.LLCModelOption);

    avgInputVoltage = (LLCSpec.minInputVoltage + LLCSpec.maxInputVoltage) / 2;
    avgOutputVoltage = (LLCSpec.minOutputVoltage + LLCSpec.maxOutputVoltage) / 2;

    % Anchor the ratio on the voltage pair the user selected. The average pair centers the
    % gain requirement across the voltage window. The extreme pairs bias the design
    % towards one end of it, which is useful when one end needs more boost headroom.
    %
    % The first case is matched on two spellings on purpose. The shipped specification
    % carries "Volttage", and every consumer of it does too, so correcting the string in
    % one place would leave a spec that silently fell through to the average pair.
    switch LLCSpec.turnratioVoltageLevel
        case {"Max Output Volttage and Min Input Voltage", ...
                "Max Output Voltage and Min Input Voltage"}
            designTurnsRatio = LLCSpec.minInputVoltage / ...
                (topologyFactor * LLCSpec.maxOutputVoltage);
        case "Min Output Voltage and Max Input Voltage"
            designTurnsRatio = LLCSpec.maxInputVoltage / ...
                (topologyFactor * LLCSpec.minOutputVoltage);
        case "Average Output and Input Voltage"
            designTurnsRatio = avgInputVoltage / (topologyFactor * avgOutputVoltage);
        otherwise
            error("computeLLCTurnsRatio:UnknownStrategy", ...
                "Unknown turnratioVoltageLevel ""%s"". Expected one of " + ...
                """Average Output and Input Voltage"", " + ...
                """Max Output Volttage and Min Input Voltage"", or " + ...
                """Min Output Voltage and Max Input Voltage"".", ...
                string(LLCSpec.turnratioVoltageLevel));
    end

    designTurnsRatio = value(designTurnsRatio, "1");
end

% The transformer needs integer winding counts, so the ratio the converter actually
% realizes differs slightly from the designed one.
turnsRatioData.designTurnsRatio = designTurnsRatio;
turnsRatioData.isTurnsRatioSpecified = isTurnsRatioSpecified;
turnsRatioData.N1 = options.N1;
turnsRatioData.N2 = round(options.N1 / designTurnsRatio);
turnsRatioData.realizedTurnsRatio = turnsRatioData.N1 / turnsRatioData.N2;

end
