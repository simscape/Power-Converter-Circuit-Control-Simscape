function [designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec, options)
%DESIGNTOTEMPOLEBOOSTPFCCONVERTER Size the totem-pole boost PFC power stage.
%
%   [designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec,
%   Name=Value) sizes the boost inductor and the DC-bus capacitor. It then reports the device
%   and magnetics rating, the continuous-conduction-mode (CCM) margin and the feasibility of
%   the design at every AC input voltage. The scope is the power stage only: the control
%   loops, the PWM dead time and the EMI filter are not sized here.
%
%   Inputs:
%     totemPoleSpec  Converter specification: the AC input range, the bus voltage, the
%                    power level, the switching frequency, the ripple allowances and the
%                    parasitics.
%
%   Required totemPoleSpec fields:
%     minInputVoltage                AC input voltage range, RMS (V).
%     nomInputVoltage
%     maxInputVoltage
%     lineFrequency                  AC line frequency (Hz).
%     outputVoltage                  Regulated DC bus voltage (V).
%     ratedPower                     Rated power (W). The line current is sized on this
%                                    value, at each AC input voltage.
%     switchingFrequency             Fast-leg switching frequency (Hz).
%     inductorCurrentRippleFraction  Peak-to-peak inductor ripple allowed at the AC peak,
%                                    as a fraction of the peak line current.
%     outputVoltageRippleFraction    Bus ripple allowed at twice the line frequency.
%     inductorESR                    Boost inductor series resistance (Ohm).
%     capacitorESR                   Bus capacitor series resistance (Ohm).
%
%   Optional totemPoleSpec fields:
%     holdUpTime                  Time the bus must ride through a line dropout (s).
%                                 Default 0, which drops the requirement.
%     minHoldUpVoltage            Bus voltage the hold-up may sag to (V). Default 0.8 of
%                                 the output voltage.
%     boostVoltageMargin          How far the bus sits above the highest AC peak.
%                                 Default 1.05.
%     deviceVoltageMargin         Derating on the bus voltage, reported only. Default 1.30.
%     initialCapacitorVoltage     Bus voltage at t = 0 (V). Default 0.
%     slowLegDiodeForwardVoltage  Rectifier drop of a conventional bridge PFC (V), used to
%                                 report the conduction loss this topology avoids.
%                                 Default 0.7.
%
%   Name-value options:
%     DisplayTableFlag    Display the design table and the notes. Default true.
%
%   Outputs:
%     designTable      Table summarizing the sized power stage.
%     totemPoleDesign  Structure the plant block mask reads, also carrying the worst-case
%                      currents the component-selection workflow rates devices against.
%                      Physical quantities are simscape.Value in SI base units, ratios and
%                      flags plain doubles.
%
%   Example:
%     TotemPoleBoostPFCDefaultInputParameters;
%     [designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec);
%
%   See also EstimateTotemPoleBoostPFCParameters,
%   plotTotemPoleInductorCurrentRipple, plotTotemPoleCCMBoundary.

% Copyright 2026 The MathWorks, Inc.

arguments
    totemPoleSpec struct
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

% ---- Validate that every required specification field is present ------------
% The rating and parasitic fields have no sensible default, so a missing one is named
% here rather than failing cryptically deep in the sizing math.
requiredSpecFields = [ ...
    "minInputVoltage", "nomInputVoltage", "maxInputVoltage", ...
    "lineFrequency", "outputVoltage", "ratedPower", ...
    "switchingFrequency", "inductorCurrentRippleFraction", ...
    "outputVoltageRippleFraction", "inductorESR", "capacitorESR"];
missingSpecFields = requiredSpecFields(~isfield(totemPoleSpec, requiredSpecFields));
if ~isempty(missingSpecFields)
    error("designTotemPoleBoostPFCConverter:MissingSpecField", ...
        "totemPoleSpec is missing required field(s): %s.", strjoin(missingSpecFields, ", "));
end

% ---- Extract specification to plain doubles in SI base units ----------------
acVoltageMin = value(totemPoleSpec.minInputVoltage, "V");
acVoltageNom = value(totemPoleSpec.nomInputVoltage, "V");
acVoltageMax = value(totemPoleSpec.maxInputVoltage, "V");
lineFrequency      = value(totemPoleSpec.lineFrequency, "Hz");
outputVoltage      = value(totemPoleSpec.outputVoltage, "V");
ratedPower         = value(totemPoleSpec.ratedPower, "W");
switchingFrequency = value(totemPoleSpec.switchingFrequency, "Hz");
inductorESR        = value(totemPoleSpec.inductorESR, "Ohm");
capacitorESR       = value(totemPoleSpec.capacitorESR, "Ohm");
inductorCurrentRippleFraction = totemPoleSpec.inductorCurrentRippleFraction;
outputVoltageRippleFraction   = totemPoleSpec.outputVoltageRippleFraction;

% The capacitor math below is written on the SECOND harmonic: a single-phase PFC
% absorbs a power pulsation at twice the line frequency.
lineAngularFrequency = 2 * pi * lineFrequency;

% Catch a nonsensical spec here rather than in a silently absurd design.
if ~(acVoltageMin > 0 && acVoltageNom >= acVoltageMin && acVoltageMax >= acVoltageNom)
    error("designTotemPoleBoostPFCConverter:BadVoltageRange", ...
        "AC input voltages must satisfy 0 < min (%.1f V) <= nom (%.1f V) <= max (%.1f V).", ...
        acVoltageMin, acVoltageNom, acVoltageMax);
end
if ~(inductorCurrentRippleFraction > 0 && outputVoltageRippleFraction > 0)
    error("designTotemPoleBoostPFCConverter:BadRippleFraction", ...
        "Ripple fractions must be positive; got %g (current) and %g (voltage).", ...
        inductorCurrentRippleFraction, outputVoltageRippleFraction);
end

% ---- Optional specification fields with documented defaults -----------------
% A zero hold-up time drops the requirement, leaving the ripple to size the capacitor.
if isfield(totemPoleSpec, 'holdUpTime')
    holdUpTime = value(totemPoleSpec.holdUpTime, "s");
else
    holdUpTime = 0;                     % hold-up not required by default
end
if isfield(totemPoleSpec, 'minHoldUpVoltage')
    minHoldUpVoltage = value(totemPoleSpec.minHoldUpVoltage, "V");
else
    minHoldUpVoltage = 0.8 * outputVoltage;   % allow a 20% bus sag during hold-up
end

% How far the DC bus must sit above the highest AC peak. A margin of 1 is the exact
% boundary, with no duty range left at the AC peak, so it must exceed 1.
if isfield(totemPoleSpec, 'boostVoltageMargin')
    boostVoltageMargin = totemPoleSpec.boostVoltageMargin;
else
    boostVoltageMargin = 1.05;          % 5% headroom above the maximum AC peak
end

% Reported rating only. Every device in this topology blocks the full DC bus.
if isfield(totemPoleSpec, 'deviceVoltageMargin')
    deviceVoltageMargin = totemPoleSpec.deviceVoltageMargin;
else
    deviceVoltageMargin = 1.3;          % 30% derating on the DC bus voltage
end

if isfield(totemPoleSpec, 'initialCapacitorVoltage')
    initialCapacitorVoltage = value(totemPoleSpec.initialCapacitorVoltage, "V");
else
    initialCapacitorVoltage = 0;        % bus starts discharged
end

% Drop of one rectifier in a CONVENTIONAL bridge PFC, used only to report the
% conduction loss the bridgeless totem-pole avoids.
if isfield(totemPoleSpec, 'slowLegDiodeForwardVoltage')
    slowLegDiodeForwardVoltage = value(totemPoleSpec.slowLegDiodeForwardVoltage, "V");
else
    slowLegDiodeForwardVoltage = 0.7;   % typical silicon rectifier drop
end

if holdUpTime > 0 && minHoldUpVoltage >= outputVoltage
    error("designTotemPoleBoostPFCConverter:BadHoldUpVoltage", ...
        "minHoldUpVoltage (%.1f V) must be below outputVoltage (%.1f V) for the " + ...
        "hold-up energy to be available.", minHoldUpVoltage, outputVoltage);
end

% ---- STEP 0: boost feasibility at the highest line voltage ------------------
% A boost cannot buck, so the limit is set at the MAXIMUM AC input - the highest
% peak the DC bus must exceed.
acPeakVoltageMax = sqrt(2) * acVoltageMax;
minimumFeasibleOutputVoltage = boostVoltageMargin * acPeakVoltageMax;
totemPoleDesign.minimumFeasibleOutputVoltage = minimumFeasibleOutputVoltage;
totemPoleDesign.boostVoltageRatio = outputVoltage / acPeakVoltageMax;
totemPoleDesign.boostIsFeasible = outputVoltage >= minimumFeasibleOutputVoltage;

% An error, not a warning: below this the topology does not operate at all and every
% downstream number would be meaningless.
if outputVoltage <= acPeakVoltageMax
    error("designTotemPoleBoostPFCConverter:BoostInfeasible", ...
        "Output voltage (%.1f V) does not exceed the maximum AC peak (%.1f V = " + ...
        "sqrt(2)*%.1f V). A boost PFC cannot step down. Raise outputVoltage above " + ...
        "%.1f V (boostVoltageMargin = %.2f) or lower maxInputVoltage.", ...
        outputVoltage, acPeakVoltageMax, acVoltageMax, minimumFeasibleOutputVoltage, ...
        boostVoltageMargin);
end

% ---- STEP 1: operating point at each AC input voltage -----------------------
% A PFC draws sinusoidal current in phase with the voltage, and the single boost
% inductor sits on the line, so it carries the whole line current. That current is sized
% on rated power. Device margin is selectTotemPoleDeviceRating's SafetyFactor, not an
% efficiency guessed before any loss is known.
cornerNames = ["Minimum line", "Nominal line", "Maximum line"];
cornerVoltages = [acVoltageMin, acVoltageNom, acVoltageMax];
cornerCount = numel(cornerVoltages);

corners = struct('name', cell(1, cornerCount));
for cornerIndex = 1:cornerCount
    acVoltageRms = cornerVoltages(cornerIndex);
    acPeakVoltage = sqrt(2) * acVoltageRms;

    corners(cornerIndex).name = cornerNames(cornerIndex);
    corners(cornerIndex).acVoltageRms = acVoltageRms;
    corners(cornerIndex).acPeakVoltage = acPeakVoltage;
    corners(cornerIndex).modulationIndex = acPeakVoltage / outputVoltage;
    corners(cornerIndex).minimumDuty = 1 - acPeakVoltage / outputVoltage;
    corners(cornerIndex).lineCurrentRms = ratedPower / acVoltageRms;
    corners(cornerIndex).lineCurrentPeak = sqrt(2) * corners(cornerIndex).lineCurrentRms;

    % Inductance this AC input needs to hold the ripple fraction. The worst-case ripple
    % over the line cycle is Vout/(4*L*fsw) with no AC voltage term, so the SMALLEST
    % peak current demands the LARGEST inductance - the maximum line voltage.
    corners(cornerIndex).requiredInductance = localRequiredInductance( ...
        acPeakVoltage, outputVoltage, switchingFrequency, ...
        inductorCurrentRippleFraction, corners(cornerIndex).lineCurrentPeak);
end

% Located by value, not by index, so the logic survives a spec with repeated voltages.
[~, stressCornerIndex] = max([corners.lineCurrentPeak]);
[~, rippleCornerIndex] = max([corners.requiredInductance]);

% ---- STEP 2: boost inductance from the worst-case ripple --------------------
% The largest requirement, so the spec holds across the whole AC input range.
boostInductance = corners(rippleCornerIndex).requiredInductance;

% ---- STEP 3 and 5 (per AC input): CCM margin, ripple and peak current ------
% Re-evaluated for the sized inductance, so the table shows where each limit is reached.
for cornerIndex = 1:cornerCount
    acPeakVoltage   = corners(cornerIndex).acPeakVoltage;
    lineCurrentPeak = corners(cornerIndex).lineCurrentPeak;

    % Worst-case ripple over the line cycle, and where it occurs.
    [rippleMax, rippleVoltage] = localWorstCaseInductorRipple( ...
        acPeakVoltage, outputVoltage, boostInductance, switchingFrequency);
    corners(cornerIndex).inductorCurrentRipple = rippleMax;
    corners(cornerIndex).rippleVoltage = rippleVoltage;
    corners(cornerIndex).realizedRippleFraction = rippleMax / lineCurrentPeak;

    % Ripple at the AC peak: the value the conventional (non-worst-case) sizing rule
    % uses. Reported alongside so the difference is visible, not a hidden assumption.
    corners(cornerIndex).inductorCurrentRippleAtACPeak = ...
        acPeakVoltage * (1 - acPeakVoltage / outputVoltage) / ...
        (boostInductance * switchingFrequency);

    % Full-cycle CCM threshold: in i_L > dIL/2 the sin(theta) cancels exactly, leaving
    % one line-phase-independent inductance bound.
    criticalInductance = acPeakVoltage / (2 * switchingFrequency * lineCurrentPeak);
    corners(cornerIndex).criticalInductance = criticalInductance;
    corners(cornerIndex).ccmMargin = boostInductance / criticalInductance;

    % Power below which conduction goes discontinuous near the zero crossings. Normal
    % for a PFC at light load, so it is reported, not corrected.
    corners(cornerIndex).ccmPowerThreshold = ...
        corners(cornerIndex).acVoltageRms^2 / (2 * switchingFrequency * boostInductance);

    % Core saturation rating, as the NUMERICAL maximum of the envelope i_L + dIL/2. The
    % at-AC-peak closed form is exact only at moderate ripple, so it is a cross-check.
    [peakInductorCurrent, peakPhase] = localPeakInductorCurrent( ...
        lineCurrentPeak, acPeakVoltage, outputVoltage, boostInductance, switchingFrequency);
    corners(cornerIndex).peakInductorCurrent = peakInductorCurrent;
    corners(cornerIndex).peakInductorCurrentPhase = peakPhase;
    corners(cornerIndex).peakInductorCurrentClosedForm = lineCurrentPeak + ...
        acPeakVoltage * (1 - acPeakVoltage / outputVoltage) / ...
        (2 * boostInductance * switchingFrequency);

    % Dominated by the fundamental; the ripple adds only a second-order term.
    corners(cornerIndex).inductorCurrentRms = corners(cornerIndex).lineCurrentRms;

    % Fast-leg and slow-leg conduction currents, exact over a line half cycle.
    corners(cornerIndex).legCurrents = localLegCurrents( ...
        lineCurrentPeak, corners(cornerIndex).modulationIndex);
end

% After the loop, not before: the struct array is copied by value.
stressCorner = corners(stressCornerIndex);

% The CCM limit is worst where the margin is smallest and the DCM threshold highest -
% both at the maximum line voltage.
[minimumCCMMargin, ccmMarginCornerIndex] = min([corners.ccmMargin]);
[maximumCCMPowerThreshold, ccmPowerCornerIndex] = max([corners.ccmPowerThreshold]);

% ---- STEP 4: DC-bus capacitance, the larger of two requirements -------------
% (a) Second-harmonic ripple. Input power is Pin*(1 - cos(2*wLine*t)) against a
% constant load, so the capacitor absorbs the whole cosine term, giving a
% peak-to-peak ripple of Pout/(wLine*Co*Vout). The spec fraction is PEAK-TO-PEAK.
capacitanceForRipple = ratedPower / ...
    (lineAngularFrequency * outputVoltageRippleFraction * outputVoltage^2);

% (b) Hold-up. The ENERGY balance 0.5*Co*(Vout^2 - Vmin^2) = Pout*holdUpTime, exact
% over the many line cycles such a sag lasts. A linear-discharge form is not used: it
% is only valid for a small sag.
if holdUpTime > 0
    capacitanceForHoldUp = 2 * ratedPower * holdUpTime / ...
        (outputVoltage^2 - minHoldUpVoltage^2);
else
    capacitanceForHoldUp = 0;           % hold-up not required
end

outputCapacitance = max(capacitanceForRipple, capacitanceForHoldUp);
if capacitanceForHoldUp > capacitanceForRipple
    capacitanceSetByRequirement = "Hold-up";
else
    capacitanceSetByRequirement = "Second-harmonic ripple";
end

% Realized ripple for the selected capacitance, and the low-frequency RMS current the
% capacitor must be rated to carry.
outputVoltageRipplePeakToPeak = ratedPower / ...
    (lineAngularFrequency * outputCapacitance * outputVoltage);
outputVoltageRippleAmplitude = outputVoltageRipplePeakToPeak / 2;
capacitorCurrentRms = ratedPower / (sqrt(2) * outputVoltage);
outputCurrent = ratedPower / outputVoltage;

% ---- STEP 5: bridgeless conduction-loss advantage --------------------------
% A conventional bridge-plus-boost PFC keeps TWO rectifier drops in the path at all
% times; the totem-pole removes them. Reported at the minimum line voltage, where the
% mean rectified current 2*Ipk/pi, and so the saving, is largest.
meanRectifiedLineCurrent = 2 * stressCorner.lineCurrentPeak / pi;
bridgeConductionLossSaved = 2 * slowLegDiodeForwardVoltage * meanRectifiedLineCurrent;

% ---- STEP 6: feasibility flags ---------------------------------------------
% Separate from the warnings below, so a caller that suppresses display can still branch.
totemPoleDesign.ccmHoldsOverFullLineCycle = minimumCCMMargin > 1;
totemPoleDesign.rippleSpecMetAtAllInputVoltages = ...
    all([corners.realizedRippleFraction] <= inductorCurrentRippleFraction * (1 + 1e-9));
totemPoleDesign.holdUpSizesCapacitor = capacitanceForHoldUp > capacitanceForRipple;

% ---- Collect the design outputs --------------------------------------------
totemPoleDesign.boostInductance = boostInductance;
totemPoleDesign.inductorESR = inductorESR;
totemPoleDesign.outputCapacitance = outputCapacitance;
totemPoleDesign.capacitorESR = capacitorESR;
totemPoleDesign.initialCapacitorVoltage = initialCapacitorVoltage;
totemPoleDesign.switchingFrequency = switchingFrequency;
totemPoleDesign.lineFrequency = lineFrequency;
totemPoleDesign.outputVoltage = outputVoltage;
totemPoleDesign.ratedPower = ratedPower;
totemPoleDesign.nomInputVoltage = acVoltageNom;

totemPoleDesign.capacitanceForRipple = capacitanceForRipple;
totemPoleDesign.capacitanceForHoldUp = capacitanceForHoldUp;
totemPoleDesign.capacitanceSetByRequirement = capacitanceSetByRequirement;
totemPoleDesign.outputVoltageRipplePeakToPeak = outputVoltageRipplePeakToPeak;
totemPoleDesign.outputVoltageRippleAmplitude = outputVoltageRippleAmplitude;
totemPoleDesign.capacitorCurrentRms = capacitorCurrentRms;
totemPoleDesign.outputCurrent = outputCurrent;

totemPoleDesign.requestedRippleFraction = inductorCurrentRippleFraction;
totemPoleDesign.inductanceSetByInputVoltage = corners(rippleCornerIndex).name;
totemPoleDesign.ratingSetByInputVoltage = stressCorner.name;
totemPoleDesign.minimumCCMMargin = minimumCCMMargin;
totemPoleDesign.minimumCCMMarginInputVoltage = corners(ccmMarginCornerIndex).name;
totemPoleDesign.ccmPowerThreshold = maximumCCMPowerThreshold;
totemPoleDesign.ccmPowerThresholdFraction = maximumCCMPowerThreshold / ratedPower;
totemPoleDesign.ccmPowerThresholdInputVoltage = corners(ccmPowerCornerIndex).name;

% Currents at the minimum line voltage, which is what the devices and magnetics must
% be rated for.
totemPoleDesign.peakLineCurrent = stressCorner.lineCurrentPeak;
totemPoleDesign.rmsLineCurrent = stressCorner.lineCurrentRms;
totemPoleDesign.peakInductorCurrent = stressCorner.peakInductorCurrent;
totemPoleDesign.rmsInductorCurrent = stressCorner.inductorCurrentRms;
totemPoleDesign.worstCaseInductorCurrentRipple = stressCorner.inductorCurrentRipple;
totemPoleDesign.fastLegMainSwitchCurrentRms = stressCorner.legCurrents.mainSwitchRms;
totemPoleDesign.fastLegRectifierCurrentRms = stressCorner.legCurrents.rectifierRms;
totemPoleDesign.fastLegRectifierCurrentAvg = stressCorner.legCurrents.rectifierAvg;
totemPoleDesign.fastLegDeviceCurrentRms = stressCorner.legCurrents.fastLegDeviceRms;
totemPoleDesign.slowLegDeviceCurrentRms = stressCorner.legCurrents.slowLegRms;
totemPoleDesign.slowLegDeviceCurrentAvg = stressCorner.legCurrents.slowLegAvg;
totemPoleDesign.deviceVoltageRating = deviceVoltageMargin * outputVoltage;
totemPoleDesign.bridgeConductionLossSaved = bridgeConductionLossSaved;

% The operating point at each AC input voltage, as plain doubles for the plot functions.
totemPoleDesign.operatingPoints = corners;

% ---- Build display table ---------------------------------------------------
% Component values, then the results the design is checked against. Device voltage and
% current ratings belong to selectTotemPoleDeviceRating, not here. Quantities that vary over
% the AC input range are reported at their worst value, and the full per-input-voltage
% detail stays in totemPoleDesign.operatingPoints.
componentName = { ...
    'Boost inductance (LBoost)'; ...
    'Boost inductor ESR (RLboost)'; ...
    'DC-bus capacitance (CBoost)'; ...
    'DC-bus capacitor ESR (Rco)'; ...
    'Switching frequency (Fsw)'; ...
    'RMS line current (worst case)'; ...
    'Peak inductor current (worst case)'; ...
    'Realized ripple fraction (worst case)'; ...
    'Minimum power for continuous conduction'; ...
    'DC-bus ripple, peak-to-peak'};
tableValue = [ ...
    boostInductance * 1e6; ...
    inductorESR; ...
    outputCapacitance * 1e6; ...
    capacitorESR; ...
    switchingFrequency * 1e-3; ...
    totemPoleDesign.rmsLineCurrent; ...
    totemPoleDesign.peakInductorCurrent; ...
    corners(rippleCornerIndex).realizedRippleFraction; ...
    maximumCCMPowerThreshold; ...
    outputVoltageRipplePeakToPeak];
tableUnit = {'uH'; 'Ohm'; 'uF'; 'Ohm'; 'kHz'; 'A'; 'A'; '-'; 'W'; 'V'};

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(componentName), tableValue, char(tableUnit), ...
    'VariableNames', tableHeaderNames);

if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', "Totem-Pole Boost PFC Estimated Design Parameters"));

    % Operation is possible - the error above ruled out the impossible case - but the
    % duty range left at the AC peak is thin.
    if ~totemPoleDesign.boostIsFeasible
        warning("designTotemPoleBoostPFCConverter:BoostMarginLow", ...
            "Output voltage (%.1f V) is only %.3f times the maximum AC peak " + ...
            "(%.1f V), below the requested boost margin of %.2f. The duty range " + ...
            "at the AC peak shrinks to %.3f, leaving little room for the current " + ...
            "loop to shape the current near the peak. Raise outputVoltage above " + ...
            "%.1f V, or lower maxInputVoltage.", ...
            outputVoltage, totemPoleDesign.boostVoltageRatio, acPeakVoltageMax, ...
            boostVoltageMargin, corners(end).minimumDuty, minimumFeasibleOutputVoltage);
    end

    % Losing CCM near the zero crossings is normal and not corrected, so this is
    % informational but explicit.
    if ~totemPoleDesign.ccmHoldsOverFullLineCycle
        % The margin is exactly 1/(2*rippleFraction*m), so full-cycle CCM at rated power
        % needs rippleFraction < 1/(2*m). A higher switching frequency does not help:
        % re-sizing L to hold the same ripple fraction cancels it out.
        maximumRippleFractionForCCM = 1 / (2 * corners(ccmMarginCornerIndex).modulationIndex);
        warning("designTotemPoleBoostPFCConverter:DiscontinuousConduction", ...
            "At %s the sized inductance (%.1f uH) is only %.3f times the critical " + ...
            "inductance (%.1f uH), so conduction becomes discontinuous over part of " + ...
            "the line cycle even at rated power. DCM raises the current ripple and " + ...
            "the peak current and changes the small-signal plant the current loop " + ...
            "sees. The margin equals 1/(2*rippleFraction*m) exactly, so full-cycle " + ...
            "CCM at rated power needs inductorCurrentRippleFraction below %.3f " + ...
            "(currently %.2f, m = %.3f). Raising the switching frequency " + ...
            "does NOT help, because holding the same ripple fraction shrinks the " + ...
            "inductance in exact proportion.", ...
            corners(ccmMarginCornerIndex).name, boostInductance * 1e6, ...
            minimumCCMMargin, corners(ccmMarginCornerIndex).criticalInductance * 1e6, ...
            maximumRippleFractionForCCM, inductorCurrentRippleFraction, ...
            corners(ccmMarginCornerIndex).modulationIndex);
    end

    % Some DCM is unavoidable (CCM to zero load needs infinite inductance) and the
    % threshold is locked to 2*rippleFraction*m, so warn only when it covers most of
    % the load range.
    if totemPoleDesign.ccmPowerThresholdFraction > 0.7
        warning("designTotemPoleBoostPFCConverter:CCMPowerThresholdHigh", ...
            "The converter runs in DCM near the line zero crossings below %.0f W " + ...
            "(%.0f%% of rated) at %s, so most of the load range is partly " + ...
            "discontinuous. This threshold is exactly 2*rippleFraction*m " + ...
            "(2 * %.2f * %.3f), so the ONLY lever is a smaller " + ...
            "inductorCurrentRippleFraction or a larger Vout/Vac ratio - raising the " + ...
            "switching frequency has no effect, because holding the same ripple " + ...
            "fraction shrinks the inductance in exact proportion.", ...
            maximumCCMPowerThreshold, 100 * totemPoleDesign.ccmPowerThresholdFraction, ...
            corners(ccmPowerCornerIndex).name, inductorCurrentRippleFraction, ...
            corners(ccmPowerCornerIndex).modulationIndex);
    end

    % A legitimate outcome, but worth surfacing: it can multiply the capacitance.
    if totemPoleDesign.holdUpSizesCapacitor
        warning("designTotemPoleBoostPFCConverter:HoldUpSizesCapacitor", ...
            "The hold-up requirement (%.0f uF for %.0f ms down to %.0f V) sizes the " + ...
            "DC-bus capacitor rather than the ripple requirement (%.0f uF), a factor " + ...
            "of %.2f larger. The realized bus ripple is therefore only %.1f V " + ...
            "peak-to-peak (%.1f%% of the bus) against the %.1f%% specified. Shorten " + ...
            "holdUpTime or lower minHoldUpVoltage if the capacitor is too large.", ...
            capacitanceForHoldUp * 1e6, holdUpTime * 1e3, minHoldUpVoltage, ...
            capacitanceForRipple * 1e6, capacitanceForHoldUp / capacitanceForRipple, ...
            outputVoltageRipplePeakToPeak, ...
            100 * outputVoltageRipplePeakToPeak / outputVoltage, ...
            100 * outputVoltageRippleFraction);
    end

    % Where the numerical envelope departs from the closed form, that form would have
    % under-rated the core. EVERY AC input voltage is scanned: the closed form breaks
    % down first at the highest line voltage (largest m), so checking only the minimum
    % would stay silent - at rippleFraction 1.0 the maximum line voltage is 4.6% out
    % while the minimum line voltage is still exact.
    peakCurrentClosedFormError = abs([corners.peakInductorCurrent] - ...
        [corners.peakInductorCurrentClosedForm]) ./ [corners.peakInductorCurrent];
    [worstClosedFormError, closedFormCornerIndex] = max(peakCurrentClosedFormError);
    if worstClosedFormError > 0.01
        closedFormCorner = corners(closedFormCornerIndex);
        warning("designTotemPoleBoostPFCConverter:PeakCurrentOffACPeak", ...
            "At %s the inductor current envelope peaks at a line phase of %.3f rad " + ...
            "rather than at the AC peak (pi/2), because the requested ripple " + ...
            "fraction (%.2f) is large. The peak inductor current reported for that " + ...
            "voltage (%.2f A) is the true numerical maximum; the usual at-AC-peak " + ...
            "closed form gives %.2f A and would under-rate the core by %.1f%%. The " + ...
            "closed form degrades as the modulation index rises, so it fails at the " + ...
            "highest line voltage first.", ...
            closedFormCorner.name, closedFormCorner.peakInductorCurrentPhase, ...
            inductorCurrentRippleFraction, closedFormCorner.peakInductorCurrent, ...
            closedFormCorner.peakInductorCurrentClosedForm, 100 * worstClosedFormError);
    end
end

% ---- Seal physical quantities as simscape.Value in SI base units -----------
% The mask reads an SI magnitude directly, as totemPoleDesign.boostInductance.value
% with its unit popup on the matching SI base unit. Dimensionless quantities, the
% tables (already in uH, uF, kHz) and the operating-point struct stay plain doubles.
totemPoleDesign.boostInductance = simscape.Value(totemPoleDesign.boostInductance, "H");
totemPoleDesign.inductorESR = simscape.Value(totemPoleDesign.inductorESR, "Ohm");
totemPoleDesign.outputCapacitance = simscape.Value(totemPoleDesign.outputCapacitance, "F");
totemPoleDesign.capacitorESR = simscape.Value(totemPoleDesign.capacitorESR, "Ohm");
totemPoleDesign.initialCapacitorVoltage = simscape.Value(totemPoleDesign.initialCapacitorVoltage, "V");
totemPoleDesign.switchingFrequency = simscape.Value(totemPoleDesign.switchingFrequency, "Hz");
totemPoleDesign.lineFrequency = simscape.Value(totemPoleDesign.lineFrequency, "Hz");
totemPoleDesign.outputVoltage = simscape.Value(totemPoleDesign.outputVoltage, "V");
totemPoleDesign.ratedPower = simscape.Value(totemPoleDesign.ratedPower, "W");
totemPoleDesign.nomInputVoltage = simscape.Value(totemPoleDesign.nomInputVoltage, "V");

totemPoleDesign.capacitanceForRipple = simscape.Value(totemPoleDesign.capacitanceForRipple, "F");
totemPoleDesign.capacitanceForHoldUp = simscape.Value(totemPoleDesign.capacitanceForHoldUp, "F");
totemPoleDesign.outputVoltageRipplePeakToPeak = simscape.Value(totemPoleDesign.outputVoltageRipplePeakToPeak, "V");
totemPoleDesign.outputVoltageRippleAmplitude = simscape.Value(totemPoleDesign.outputVoltageRippleAmplitude, "V");
totemPoleDesign.capacitorCurrentRms = simscape.Value(totemPoleDesign.capacitorCurrentRms, "A");
totemPoleDesign.outputCurrent = simscape.Value(totemPoleDesign.outputCurrent, "A");

totemPoleDesign.minimumFeasibleOutputVoltage = simscape.Value(totemPoleDesign.minimumFeasibleOutputVoltage, "V");
totemPoleDesign.ccmPowerThreshold = simscape.Value(totemPoleDesign.ccmPowerThreshold, "W");
totemPoleDesign.peakLineCurrent = simscape.Value(totemPoleDesign.peakLineCurrent, "A");
totemPoleDesign.rmsLineCurrent = simscape.Value(totemPoleDesign.rmsLineCurrent, "A");
totemPoleDesign.peakInductorCurrent = simscape.Value(totemPoleDesign.peakInductorCurrent, "A");
totemPoleDesign.rmsInductorCurrent = simscape.Value(totemPoleDesign.rmsInductorCurrent, "A");
totemPoleDesign.worstCaseInductorCurrentRipple = simscape.Value(totemPoleDesign.worstCaseInductorCurrentRipple, "A");
totemPoleDesign.fastLegMainSwitchCurrentRms = simscape.Value(totemPoleDesign.fastLegMainSwitchCurrentRms, "A");
totemPoleDesign.fastLegRectifierCurrentRms = simscape.Value(totemPoleDesign.fastLegRectifierCurrentRms, "A");
totemPoleDesign.fastLegRectifierCurrentAvg = simscape.Value(totemPoleDesign.fastLegRectifierCurrentAvg, "A");
totemPoleDesign.fastLegDeviceCurrentRms = simscape.Value(totemPoleDesign.fastLegDeviceCurrentRms, "A");
totemPoleDesign.slowLegDeviceCurrentRms = simscape.Value(totemPoleDesign.slowLegDeviceCurrentRms, "A");
totemPoleDesign.slowLegDeviceCurrentAvg = simscape.Value(totemPoleDesign.slowLegDeviceCurrentAvg, "A");
totemPoleDesign.deviceVoltageRating = simscape.Value(totemPoleDesign.deviceVoltageRating, "V");
totemPoleDesign.bridgeConductionLossSaved = simscape.Value(totemPoleDesign.bridgeConductionLossSaved, "W");

end

% =============================================================================
function requiredInductance = localRequiredInductance(acPeakVoltage, ...
    outputVoltage, switchingFrequency, rippleFraction, peakLineCurrent)
%LOCALREQUIREDINDUCTANCE Inductance needed to hold a peak-to-peak ripple fraction.
%   Inverts dIL = |v_ac|*(1 - |v_ac|/Vout)/(L*fsw) against
%   dIL_max = rippleFraction*peakLineCurrent. That ripple is quadratic in |v_ac| and
%   peaks at |v_ac| = Vout/2, which the line reaches whenever the AC peak is at least
%   Vout/2 (the normal case); below that the worst point is the AC peak itself.

if acPeakVoltage >= outputVoltage / 2
    % Mid-cycle at |v_ac| = Vout/2, independent of the AC voltage.
    requiredInductance = outputVoltage / ...
        (4 * switchingFrequency * rippleFraction * peakLineCurrent);
else
    % Low line or high boost ratio: worst case is at the AC peak.
    requiredInductance = acPeakVoltage * (1 - acPeakVoltage / outputVoltage) / ...
        (switchingFrequency * rippleFraction * peakLineCurrent);
end
end

% =============================================================================
function [rippleMax, voltageAtRippleMax] = localWorstCaseInductorRipple( ...
    acPeakVoltage, outputVoltage, inductance, switchingFrequency)
%LOCALWORSTCASEINDUCTORRIPPLE Peak-to-peak ripple maximum over the line cycle.
%   The largest ripple anywhere in the line cycle and the AC voltage magnitude at
%   which it occurs - localRequiredInductance evaluated forwards.

if acPeakVoltage >= outputVoltage / 2
    rippleMax = outputVoltage / (4 * inductance * switchingFrequency);
    voltageAtRippleMax = outputVoltage / 2;
else
    rippleMax = acPeakVoltage * (1 - acPeakVoltage / outputVoltage) / ...
        (inductance * switchingFrequency);
    voltageAtRippleMax = acPeakVoltage;
end
end

% =============================================================================
function [peakInductorCurrent, peakPhase] = localPeakInductorCurrent( ...
    peakLineCurrent, acPeakVoltage, outputVoltage, inductance, switchingFrequency)
%LOCALPEAKINDUCTORCURRENT Numerical maximum of the inductor current envelope.
%   The upper envelope over a line half cycle is i_L + dIL/2, with i_L = Ipk*sin(theta)
%   and dIL = |v_ac|*(1 - |v_ac|/Vout)/(L*fsw). The sinusoid pulls the maximum toward
%   the AC peak and the ripple term toward |v_ac| = Vout/2, so its location depends on
%   the ripple magnitude.
%
%   Evaluated NUMERICALLY, not with the at-AC-peak closed form
%   Ipk + Vpk*(1-m)/(2*L*fsw): that form under-predicts the true peak by about 5% as
%   the ripple fraction approaches 1, and this number sets the core saturation rating.
%   The envelope is smooth, so a fine grid is exact for practical purposes.

linePhase = linspace(0, pi, 200001);
acVoltageInstantaneous = acPeakVoltage * sin(linePhase);

% CCM duty of the main switch, clamped so the helper stays physical in isolation if the
% AC peak ever reaches the bus voltage (a spec the caller already rejects).
mainSwitchDuty = max(1 - acVoltageInstantaneous / outputVoltage, 0);

inductorCurrentRipple = acVoltageInstantaneous .* mainSwitchDuty / ...
    (inductance * switchingFrequency);
envelope = peakLineCurrent * sin(linePhase) + inductorCurrentRipple / 2;

[peakInductorCurrent, peakIndex] = max(envelope);
peakPhase = linePhase(peakIndex);
end

% =============================================================================
function legCurrents = localLegCurrents(peakLineCurrent, modulationIndex)
%LOCALLEGCURRENTS Exact fast-leg and slow-leg conduction currents.
%   Integrating i_L = Ipk*sin(theta) with the CCM duty d = 1 - m*sin(theta) over a half
%   cycle gives closed forms for the main (boost) switch and the rectifier (freewheel)
%   device. The two fast-leg devices swap those roles every half cycle, so each carries
%   their quadratic mean, Ipk/2. Each slow-leg device conducts for one half cycle.

% Fast leg, per role, over the half cycle in which that role applies.
legCurrents.mainSwitchRms = peakLineCurrent * ...
    sqrt(1/2 - 4 * modulationIndex / (3 * pi));
legCurrents.rectifierRms = peakLineCurrent * ...
    sqrt(4 * modulationIndex / (3 * pi));

% An exact self-check: ID_avg = Ipk*m/2 = Ipk*Vpk/(2*Vout) = Pin/Vout.
legCurrents.rectifierAvg = peakLineCurrent * modulationIndex / 2;

% Over a FULL line cycle the two half-cycle contributions combine in quadrature and the
% modulation index cancels exactly, leaving Ipk/2.
legCurrents.fastLegDeviceRms = sqrt( ...
    (legCurrents.mainSwitchRms^2 + legCurrents.rectifierRms^2) / 2);

% Slow leg: each device conducts the full line current for one half cycle.
legCurrents.slowLegRms = peakLineCurrent / 2;
legCurrents.slowLegAvg = peakLineCurrent / pi;
legCurrents.slowLegPeak = peakLineCurrent;
end
