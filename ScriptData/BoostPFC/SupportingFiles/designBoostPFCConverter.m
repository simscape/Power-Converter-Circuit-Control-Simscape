function [designTable, boostPFCDesign] = designBoostPFCConverter(boostPFCSpec, options)
%DESIGNBOOSTPFCCONVERTER Size the boost PFC power stage.
%
%   [designTable, boostPFCDesign] = designBoostPFCConverter(boostPFCSpec, Name=Value) sizes
%   the boost inductor and the DC-bus capacitor. It then reports the device current and
%   voltage rating over the AC input range, with the continuous-conduction-mode margin and
%   the realized ripple. The scope is the power stage only: the control loops and the EMI
%   filter are not sized here.
%
%   Inputs:
%     boostPFCSpec  Converter specification. Every field below is required.
%
%   Specification fields:
%     minInputVoltage                AC input voltage range, RMS (V).
%     nomInputVoltage
%     maxInputVoltage
%     lineFrequency                  AC line frequency (Hz).
%     outputVoltage                  Regulated DC bus voltage (V).
%     ratedPower                     Rated output power (W). The line current is sized on
%                                    this value, at each AC input voltage.
%     switchingFrequency             Boost switching frequency (Hz).
%     inductorCurrentRippleFraction  Peak-to-peak inductor ripple allowed at its worst point
%                                    in the line cycle, as a fraction of the peak line
%                                    current.
%     outputVoltageRippleFraction    Bus ripple allowed at twice the line frequency.
%     holdUpTime                     Time the bus must ride through a line dropout (s).
%     minHoldUpVoltage               Bus voltage the hold-up may sag to (V).
%     boostVoltageMargin             How far the bus sits above the highest AC peak.
%     deviceVoltageMargin            Derating on the blocking voltage, reported only.
%     inductorResistance             Boost inductor series resistance (Ohm).
%     capacitorResistance            Bus capacitor series resistance (Ohm).
%     initialCapacitorVoltage        Bus voltage at t = 0 (V).
%     bridgeDiodeForwardVoltage      Input rectifier forward drop (V).
%
%   Name-value options:
%     DisplayTableFlag    Display the design table. Default false.
%
%   Outputs:
%     designTable     Table summarizing the sized power stage.
%     boostPFCDesign  Structure the plant block mask reads, also carrying the currents the
%                     component-selection workflow rates devices against.
%
%   See also designBoostPFCController, selectBoostPFCDeviceRating,
%   plotBoostPFCInductorCurrent.

% Copyright 2026 The MathWorks, Inc.

arguments
    boostPFCSpec struct
    options.DisplayTableFlag (1,1) logical = false
end

% scalarValue accepts either simscape.Value or a plain double.
acVoltageMin = scalarValue(boostPFCSpec.minInputVoltage);
acVoltageNom = scalarValue(boostPFCSpec.nomInputVoltage);
acVoltageMax = scalarValue(boostPFCSpec.maxInputVoltage);
lineFrequency = scalarValue(boostPFCSpec.lineFrequency);

outputVoltage = scalarValue(boostPFCSpec.outputVoltage);
ratedPower = scalarValue(boostPFCSpec.ratedPower);

switchingFrequency = scalarValue(boostPFCSpec.switchingFrequency);
inductorCurrentRippleFraction = boostPFCSpec.inductorCurrentRippleFraction;
outputVoltageRippleFraction = boostPFCSpec.outputVoltageRippleFraction;

holdUpTime = scalarValue(boostPFCSpec.holdUpTime);
minHoldUpVoltage = scalarValue(boostPFCSpec.minHoldUpVoltage);

boostVoltageMargin = boostPFCSpec.boostVoltageMargin;
deviceVoltageMargin = boostPFCSpec.deviceVoltageMargin;

inductorResistance = scalarValue(boostPFCSpec.inductorResistance);
capacitorResistance = scalarValue(boostPFCSpec.capacitorResistance);
initialCapacitorVoltage = scalarValue(boostPFCSpec.initialCapacitorVoltage);
bridgeDiodeForwardVoltage = scalarValue(boostPFCSpec.bridgeDiodeForwardVoltage);

% ---- Boost feasibility ------------------------------------------------------
% The bus must clear the highest line peak, not the nominal one, or current control is
% lost for part of every line cycle.
acPeakVoltageMax = sqrt(2) * acVoltageMax;
minimumFeasibleOutputVoltage = boostVoltageMargin * acPeakVoltageMax;
if outputVoltage <= acPeakVoltageMax
    error("designBoostPFCConverter:OutputBelowACPeak", ...
        "Output voltage (%.1f V) must exceed the maximum AC peak (%.1f V).", ...
        outputVoltage, acPeakVoltageMax);
end

% ---- Operating point at each AC input voltage ------------------------------
% The two constraints land at opposite ends: device current is highest at minimum
% line, and the ripple fraction, so the inductance, is set at maximum line. The line
% current is sized on rated power. Device margin is selectBoostPFCDeviceRating's
% SafetyFactor, not an efficiency guessed before any loss is known.
cornerVoltages = [acVoltageMin, acVoltageNom, acVoltageMax];
cornerNames = ["Minimum line voltage", "Nominal line voltage", "Maximum line voltage"];

corners = struct([]);
for cornerIndex = 1:numel(cornerVoltages)
    acVoltageRms = cornerVoltages(cornerIndex);
    acPeakVoltage = sqrt(2) * acVoltageRms;

    corners(cornerIndex).name = cornerNames(cornerIndex);
    corners(cornerIndex).acVoltageRms = acVoltageRms;
    corners(cornerIndex).acPeakVoltage = acPeakVoltage;
    corners(cornerIndex).modulationIndex = acPeakVoltage / outputVoltage;
    corners(cornerIndex).minimumDuty = 1 - acPeakVoltage / outputVoltage;
    corners(cornerIndex).lineCurrentRms = ratedPower / acVoltageRms;
    corners(cornerIndex).lineCurrentPeak = sqrt(2) * ratedPower / acVoltageRms;

    % dIL = Vout*m*(1-m)/(L*fsw) with m = |vac|/Vout peaks at Vout/(4*L*fsw), independent
    % of line voltage; only the peak current changes, so the fraction is worst at high line.
    corners(cornerIndex).requiredInductance = outputVoltage / (4 * switchingFrequency * ...
        inductorCurrentRippleFraction * corners(cornerIndex).lineCurrentPeak);
end

% The largest requirement wins, so the ripple spec is met at every AC input voltage.
[boostInductance, rippleCornerIndex] = max([corners.requiredInductance]);

% ---- Ripple, CCM and device current at the sized inductance -----------------
for cornerIndex = 1:numel(corners)
    acPeakVoltage = corners(cornerIndex).acPeakVoltage;
    lineCurrentPeak = corners(cornerIndex).lineCurrentPeak;
    modulationIndex = corners(cornerIndex).modulationIndex;

    % Worst-case ripple, at |vac| = Vout/2 when the line peak reaches that point.
    if acPeakVoltage >= outputVoltage/2
        rippleMax = outputVoltage / (4 * boostInductance * switchingFrequency);
    else
        rippleMax = acPeakVoltage * (1 - modulationIndex) / (boostInductance * switchingFrequency);
    end
    corners(cornerIndex).inductorCurrentRipple = rippleMax;
    corners(cornerIndex).realizedRippleFraction = rippleMax / lineCurrentPeak;
    corners(cornerIndex).inductorCurrentRippleAtACPeak = ...
        acPeakVoltage * (1 - modulationIndex) / (boostInductance * switchingFrequency);

    % CCM is decided at the zero crossing, which is a different point of the line cycle from
    % where the ripple is worst. Requiring iL > dIL/2 with iL = Ipk*sin(theta) and
    % dIL = Vpk*sin(theta)*(1 - m*sin(theta))/(L*fsw), the sin(theta) cancels exactly and
    % leaves Lccm = Vpk/(2*fsw*Ipk), with no line phase left in it. Reaching the same margin
    % through the ripple fraction instead would tie it to |vac| = Vout/2, a point the cycle
    % never reaches when Vpk < Vout/2, and would overstate the margin there.
    criticalInductance = acPeakVoltage / (2 * switchingFrequency * lineCurrentPeak);
    corners(cornerIndex).criticalInductance = criticalInductance;
    corners(cornerIndex).ccmMargin = boostInductance / criticalInductance;

    % Load below which conduction goes discontinuous near the zero crossings. Raising fsw
    % does not help: holding the same ripple fraction shrinks L in exact proportion.
    corners(cornerIndex).ccmPowerThreshold = ...
        corners(cornerIndex).acVoltageRms^2 / (2 * switchingFrequency * boostInductance);

    % The margin and the threshold power are one result in two units, so they must agree
    % exactly. Asserted because reaching either one through the ripple fraction silently
    % breaks the agreement at any AC input whose peak stays below Vout/2.
    assert(abs(corners(cornerIndex).ccmMargin - ...
        ratedPower / corners(cornerIndex).ccmPowerThreshold) < ...
        1e-9 * corners(cornerIndex).ccmMargin, ...
        "designBoostPFCConverter:CCMResultsInconsistent", ...
        "CCM margin and CCM power threshold disagree at %s.", corners(cornerIndex).name);

    % The same criterion at the other end of the line cycle, theta = 90 deg. The surviving
    % factor after the sin(theta) cancellation is (1 - m*sin(theta)), which is largest at the
    % zero crossing and smallest at the line peak, so the margin at the peak is 1/(1-m) times
    % the zero-crossing margin. Below this load even the line peak is discontinuous, which
    % makes the two thresholds the edges of a band: full-cycle CCM above the first,
    % discontinuous everywhere below the second, and discontinuous only around the zero
    % crossings in between.
    corners(cornerIndex).fullCycleDCMPowerThreshold = ...
        corners(cornerIndex).ccmPowerThreshold * (1 - modulationIndex);

    % Peak inductor current (core saturation). The envelope peak sits slightly off the
    % line peak because the ripple is still growing there.
    linePhase = linspace(0, pi, 2001);
    instantaneousVoltage = acPeakVoltage * sin(linePhase);
    instantaneousRipple = instantaneousVoltage .* (1 - instantaneousVoltage/outputVoltage) / ...
        (boostInductance * switchingFrequency);
    envelope = lineCurrentPeak * sin(linePhase) + instantaneousRipple/2;
    [peakInductorCurrent, peakIndex] = max(envelope);
    corners(cornerIndex).peakInductorCurrent = peakInductorCurrent;
    corners(cornerIndex).peakInductorCurrentPhase = linePhase(peakIndex) * 180/pi;
    corners(cornerIndex).inductorCurrentRms = corners(cornerIndex).lineCurrentRms;

    % Device currents, closed form over a half cycle with duty d = 1 - m*sin(theta). The
    % switch and the boost diode split one inductor current: Iq^2 + Id^2 = IL^2 (asserted
    % below).
    corners(cornerIndex).switchCurrentRms = lineCurrentPeak * ...
        sqrt(1/2 - 4*modulationIndex/(3*pi));
    corners(cornerIndex).boostDiodeCurrentRms = lineCurrentPeak * ...
        sqrt(4*modulationIndex/(3*pi));
    corners(cornerIndex).boostDiodeCurrentAvg = lineCurrentPeak * modulationIndex / 2;

    % A bridge diode carries the whole line current on alternate half cycles, so it is
    % rated on the line current. Its datasheet limit is an average, hence both statistics.
    corners(cornerIndex).rectifierDiodeCurrentAvg = lineCurrentPeak / pi;
    corners(cornerIndex).rectifierDiodeCurrentRms = lineCurrentPeak / 2;

    % Two bridge diodes in series with the line at every instant - the loss a bridgeless
    % topology removes.
    corners(cornerIndex).bridgeConductionLoss = 2 * bridgeDiodeForwardVoltage * ...
        2 * lineCurrentPeak / pi;
end

% Self-check on the closed forms.
currentSplitError = max(abs([corners.switchCurrentRms].^2 + [corners.boostDiodeCurrentRms].^2 - ...
    [corners.inductorCurrentRms].^2));
assert(currentSplitError < 1e-9 * max([corners.lineCurrentPeak])^2, ...
    "designBoostPFCConverter:CurrentSplit", ...
    "Switch and diode RMS currents do not sum to the inductor RMS current.");

% Devices are rated at the lowest line voltage, where the current is highest.
[~, stressCornerIndex] = max([corners.lineCurrentPeak]);
stressCorner = corners(stressCornerIndex);

% ---- DC-bus capacitor: two independent requirements, the larger wins ---------
% Ripple: single-phase power arrives at 2*fLine, so peak-to-peak is Pout/(Vout*wLine*Co) -
% wLine, not 2*wLine, because peak-to-peak is twice the second-harmonic amplitude. The
% voltage loop must not correct it, so the capacitor sets it.
lineAngularFrequency = 2 * pi * lineFrequency;
capacitanceForRipple = ratedPower / (outputVoltage^2 * lineAngularFrequency * ...
    outputVoltageRippleFraction);

% Hold-up: stored-energy difference as the bus coasts from Vout to minHoldUpVoltage at
% rated power.
capacitanceForHoldUp = 2 * ratedPower * holdUpTime / (outputVoltage^2 - minHoldUpVoltage^2);

outputCapacitance = max(capacitanceForRipple, capacitanceForHoldUp);
if capacitanceForHoldUp > capacitanceForRipple
    capacitanceSetByRequirement = "Hold-up time";
else
    capacitanceSetByRequirement = "Output voltage ripple";
end

outputVoltageRipplePeakToPeak = ratedPower / (outputVoltage * lineAngularFrequency * ...
    outputCapacitance);
outputCurrent = ratedPower / outputVoltage;

% Capacitor RMS current: the second-harmonic term that sets its self-heating.
capacitorCurrentRms = ratedPower / (sqrt(2) * outputVoltage);

% ---- Assemble the design ----------------------------------------------------
% These field names are read by the plant mask - do not rename them here.
boostPFCDesign.ratedPower = simscape.Value(ratedPower, "W");
boostPFCDesign.nomInputVoltage = simscape.Value(acVoltageNom, "V");
boostPFCDesign.lineFrequency = simscape.Value(lineFrequency, "Hz");
boostPFCDesign.outputVoltage = simscape.Value(outputVoltage, "V");
boostPFCDesign.switchingFrequency = simscape.Value(switchingFrequency, "Hz");
boostPFCDesign.boostInductance = simscape.Value(boostInductance, "H");
boostPFCDesign.inductorResistance = simscape.Value(inductorResistance, "Ohm");
boostPFCDesign.outputCapacitance = simscape.Value(outputCapacitance, "F");
boostPFCDesign.capacitorResistance = simscape.Value(capacitorResistance, "Ohm");
boostPFCDesign.initialCapacitorVoltage = simscape.Value(initialCapacitorVoltage, "V");

% Specification echo, so the design carries its provenance.
boostPFCDesign.minInputVoltage = simscape.Value(acVoltageMin, "V");
boostPFCDesign.maxInputVoltage = simscape.Value(acVoltageMax, "V");
boostPFCDesign.requestedRippleFraction = inductorCurrentRippleFraction;
boostPFCDesign.boostVoltageRatio = outputVoltage / acPeakVoltageMax;
boostPFCDesign.boostIsFeasible = outputVoltage >= minimumFeasibleOutputVoltage;
boostPFCDesign.minimumFeasibleOutputVoltage = simscape.Value(minimumFeasibleOutputVoltage, "V");

% Capacitor sizing detail.
boostPFCDesign.capacitanceForRipple = simscape.Value(capacitanceForRipple, "F");
boostPFCDesign.capacitanceForHoldUp = simscape.Value(capacitanceForHoldUp, "F");
boostPFCDesign.capacitanceSetByRequirement = capacitanceSetByRequirement;
boostPFCDesign.outputVoltageRipplePeakToPeak = simscape.Value(outputVoltageRipplePeakToPeak, "V");
boostPFCDesign.capacitorCurrentRms = simscape.Value(capacitorCurrentRms, "A");
boostPFCDesign.outputCurrent = simscape.Value(outputCurrent, "A");

% Which AC input voltage set what, and the CCM outcome at the sized inductance.
boostPFCDesign.inductanceSetByInputVoltage = corners(rippleCornerIndex).name;
boostPFCDesign.ratingSetByInputVoltage = stressCorner.name;
[minimumCCMMargin, ccmMarginCornerIndex] = min([corners.ccmMargin]);
[maximumCCMPowerThreshold, ccmPowerCornerIndex] = max([corners.ccmPowerThreshold]);
boostPFCDesign.minimumCCMMargin = minimumCCMMargin;
boostPFCDesign.ccmHoldsOverFullLineCycle = minimumCCMMargin > 1;
boostPFCDesign.ccmPowerThreshold = simscape.Value(maximumCCMPowerThreshold, "W");
boostPFCDesign.ccmPowerThresholdFraction = maximumCCMPowerThreshold / ratedPower;
boostPFCDesign.ccmPowerThresholdInputVoltage = corners(ccmPowerCornerIndex).name;

% The lower edge of the same band: below this load conduction is discontinuous over the whole
% line cycle, the line peak included. Reported so the CCM result reads as a range rather than
% as a single pass or fail.
[maximumFullCycleDCMPowerThreshold, fullCycleDCMCornerIndex] = ...
    max([corners.fullCycleDCMPowerThreshold]);
boostPFCDesign.fullCycleDCMPowerThreshold = ...
    simscape.Value(maximumFullCycleDCMPowerThreshold, "W");
boostPFCDesign.fullCycleDCMPowerThresholdFraction = ...
    maximumFullCycleDCMPowerThreshold / ratedPower;
boostPFCDesign.fullCycleDCMPowerThresholdInputVoltage = corners(fullCycleDCMCornerIndex).name;

% Device currents at the lowest line voltage, consumed by the rating workflow.
boostPFCDesign.peakLineCurrent = simscape.Value(stressCorner.lineCurrentPeak, "A");
boostPFCDesign.rmsLineCurrent = simscape.Value(stressCorner.lineCurrentRms, "A");
boostPFCDesign.peakInductorCurrent = simscape.Value(stressCorner.peakInductorCurrent, "A");
boostPFCDesign.worstCaseInductorCurrentRipple = ...
    simscape.Value(max([corners.inductorCurrentRipple]), "A");
boostPFCDesign.switchCurrentRms = simscape.Value(stressCorner.switchCurrentRms, "A");
boostPFCDesign.boostDiodeCurrentRms = simscape.Value(stressCorner.boostDiodeCurrentRms, "A");
boostPFCDesign.boostDiodeCurrentAvg = simscape.Value(stressCorner.boostDiodeCurrentAvg, "A");
boostPFCDesign.rectifierDiodeCurrentRms = ...
    simscape.Value(stressCorner.rectifierDiodeCurrentRms, "A");
boostPFCDesign.rectifierDiodeCurrentAvg = ...
    simscape.Value(stressCorner.rectifierDiodeCurrentAvg, "A");
boostPFCDesign.bridgeConductionLoss = simscape.Value(stressCorner.bridgeConductionLoss, "W");

% The bridge diodes block only the line peak, so rating them at the bus would oversize
% them by 40%.
boostPFCDesign.deviceVoltageRating = simscape.Value(deviceVoltageMargin * outputVoltage, "V");
boostPFCDesign.rectifierVoltageRating = ...
    simscape.Value(deviceVoltageMargin * acPeakVoltageMax, "V");

% Per-input-voltage detail as plain doubles, for the plot function and programmatic use.
boostPFCDesign.operatingPoints = corners;

% ---- Display table ----------------------------------------------------------
% Component values, then the results the design is checked against. Device voltage and
% current ratings belong to selectBoostPFCDeviceRating, not here. Quantities that vary over
% the AC input range are reported at their worst value, and the full per-input-voltage
% detail stays in boostPFCDesign.operatingPoints.
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
    inductorResistance; ...
    outputCapacitance * 1e6; ...
    capacitorResistance; ...
    switchingFrequency * 1e-3; ...
    stressCorner.lineCurrentRms; ...
    stressCorner.peakInductorCurrent; ...
    corners(rippleCornerIndex).realizedRippleFraction; ...
    maximumCCMPowerThreshold; ...
    outputVoltageRipplePeakToPeak];
tableUnit = {'uH'; 'Ohm'; 'uF'; 'Ohm'; 'kHz'; 'A'; 'A'; '-'; 'W'; 'V'};

designTable = table(char(componentName), tableValue, char(tableUnit), ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});

if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', "Boost PFC Estimated Design Parameters"));
end

% Raised whether or not the tables are displayed: a silent caller still needs to know the
% design misses its own specification.
if ~boostPFCDesign.boostIsFeasible
    warning("designBoostPFCConverter:BoostMarginLow", ...
        "Output voltage (%.1f V) is only %.3f times the maximum AC peak (%.1f V), " + ...
        "below the requested margin of %.2f. The duty at the AC peak falls to %.3f, " + ...
        "leaving little room for the current loop. Raise outputVoltage above %.1f V.", ...
        outputVoltage, boostPFCDesign.boostVoltageRatio, acPeakVoltageMax, ...
        boostVoltageMargin, corners(end).minimumDuty, minimumFeasibleOutputVoltage);
end

if ~boostPFCDesign.ccmHoldsOverFullLineCycle
    % Quote the ripple bound, not a higher switching frequency, which cannot help.
    warning("designBoostPFCConverter:DiscontinuousConduction", ...
        "At %s the sized inductance (%.1f uH) is %.3f times the critical inductance, " + ...
        "so conduction is discontinuous over part of the line cycle even at rated " + ...
        "power. Full-cycle CCM needs inductorCurrentRippleFraction below %.3f " + ...
        "(currently %.2f).", corners(ccmMarginCornerIndex).name, boostInductance*1e6, ...
        minimumCCMMargin, 1/(2*corners(ccmMarginCornerIndex).modulationIndex), ...
        inductorCurrentRippleFraction);
end
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
