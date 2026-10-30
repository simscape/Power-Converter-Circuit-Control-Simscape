function [designTable, interleavedDesign] = designInterleavedBoostPFCConverter(interleavedSpec, options)
%DESIGNINTERLEAVEDBOOSTPFCCONVERTER Size the interleaved boost PFC power stage.
%
%   [designTable, interleavedDesign] = designInterleavedBoostPFCConverter(interleavedSpec,
%   Name=Value) sizes the per-leg boost inductor and the shared DC-bus capacitor. It then
%   reports the per-leg device rating and the input-ripple cancellation interleaving provides,
%   over the AC input range. Each leg carries its share of the line current and is sized as a
%   boost stage in its own right. The legs' carriers are evenly spread, so their ripple partly
%   cancels at the input. The scope is the power stage only: the control loops and the EMI
%   filter are not sized here.
%
%   Inputs:
%     interleavedSpec  Converter specification. Every field below is required.
%
%   Specification fields:
%     minInputVoltage                AC input voltage range, RMS (V).
%     nomInputVoltage
%     maxInputVoltage
%     lineFrequency                  AC line frequency (Hz).
%     outputVoltage                  Regulated DC bus voltage (V).
%     ratedPower                     Rated output power (W), shared by the legs. The line
%                                    current is sized on this value, at each AC input voltage.
%     numberOfLegs                   Interleaved boost legs.
%     switchingFrequency             Per-leg switching frequency (Hz).
%     inductorCurrentRippleFraction  Peak-to-peak ripple allowed at the AC peak, PER LEG, as
%                                    a fraction of that leg's peak current.
%     outputVoltageRippleFraction    Bus ripple allowed at twice the line frequency.
%     holdUpTime                     Time the bus must ride through a line dropout (s).
%     minHoldUpVoltage               Bus voltage the hold-up may sag to (V).
%     boostVoltageMargin             How far the bus sits above the highest AC peak.
%     deviceVoltageMargin            Derating on the blocking voltage, reported only.
%     inductorResistance             Per-leg inductor series resistance (Ohm).
%     capacitorResistance            Bus capacitor series resistance (Ohm).
%     initialCapacitorVoltage        Bus voltage at t = 0 (V).
%     bridgeDiodeForwardVoltage      Input rectifier forward drop (V).
%
%   Name-value options:
%     DisplayTableFlag    Display the design table. Default false.
%
%   Outputs:
%     designTable        Table summarizing the sized power stage.
%     interleavedDesign  Structure the plant block mask reads, also carrying the currents the
%                        component-selection workflow rates devices against.
%
%   See also designInterleavedBoostPFCController, selectInterleavedBoostPFCDeviceRating,
%   plotInterleavedBoostPFCInductorCurrent.

% Copyright 2026 The MathWorks, Inc.

arguments
    interleavedSpec struct
    options.DisplayTableFlag (1,1) logical = false
end

% scalarValue accepts either simscape.Value or a plain double.
acVoltageMin = scalarValue(interleavedSpec.minInputVoltage);
acVoltageNom = scalarValue(interleavedSpec.nomInputVoltage);
acVoltageMax = scalarValue(interleavedSpec.maxInputVoltage);
lineFrequency = scalarValue(interleavedSpec.lineFrequency);

outputVoltage = scalarValue(interleavedSpec.outputVoltage);
ratedPower = scalarValue(interleavedSpec.ratedPower);
numberOfLegs = interleavedSpec.numberOfLegs;

switchingFrequency = scalarValue(interleavedSpec.switchingFrequency);
inductorCurrentRippleFraction = interleavedSpec.inductorCurrentRippleFraction;
outputVoltageRippleFraction = interleavedSpec.outputVoltageRippleFraction;

holdUpTime = scalarValue(interleavedSpec.holdUpTime);
minHoldUpVoltage = scalarValue(interleavedSpec.minHoldUpVoltage);

boostVoltageMargin = interleavedSpec.boostVoltageMargin;
deviceVoltageMargin = interleavedSpec.deviceVoltageMargin;

inductorResistance = scalarValue(interleavedSpec.inductorResistance);
capacitorResistance = scalarValue(interleavedSpec.capacitorResistance);
initialCapacitorVoltage = scalarValue(interleavedSpec.initialCapacitorVoltage);
bridgeDiodeForwardVoltage = scalarValue(interleavedSpec.bridgeDiodeForwardVoltage);

% ---- Boost feasibility ------------------------------------------------------
% The bus must clear the HIGHEST line peak, not the nominal one. Interleaving does not
% change this: every leg sees the same rectified input and the same bus.
acPeakVoltageMax = sqrt(2) * acVoltageMax;
minimumFeasibleOutputVoltage = boostVoltageMargin * acPeakVoltageMax;
if outputVoltage <= acPeakVoltageMax
    error("designInterleavedBoostPFCConverter:OutputBelowACPeak", ...
        "Output voltage (%.1f V) must exceed the maximum AC peak (%.1f V).", ...
        outputVoltage, acPeakVoltageMax);
end

% ---- Operating point at each AC input voltage ------------------------------
% The two constraints land at opposite ends: device current is highest at MINIMUM line,
% and the ripple fraction, so the inductance, is set at MAXIMUM line. The line current is
% sized on rated power. Device margin is selectInterleavedBoostPFCDeviceRating's
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

    % The legs share the line current equally - N small devices instead of one large one.
    corners(cornerIndex).legCurrentRms = corners(cornerIndex).lineCurrentRms / numberOfLegs;
    corners(cornerIndex).legCurrentPeak = corners(cornerIndex).lineCurrentPeak / numberOfLegs;

    % dIL = Vout*m*(1-m)/(L*fsw) with m = |vac|/Vout peaks at Vout/(4*L*fsw), independent of
    % line voltage; only the peak leg current changes, so the fraction is worst at high line.
    corners(cornerIndex).requiredInductance = outputVoltage / (4 * switchingFrequency * ...
        inductorCurrentRippleFraction * corners(cornerIndex).legCurrentPeak);
end

% The largest requirement wins, so the ripple spec is met at every AC input voltage.
[boostInductance, rippleCornerIndex] = max([corners.requiredInductance]);

% ---- Ripple, CCM, interleaving gain and device current ---------------------
linePhase = linspace(0, pi, 4001);
for cornerIndex = 1:numel(corners)
    acPeakVoltage = corners(cornerIndex).acPeakVoltage;
    legCurrentPeak = corners(cornerIndex).legCurrentPeak;
    modulationIndex = corners(cornerIndex).modulationIndex;

    % Worst-case per-leg ripple, at |vac| = Vout/2 when the line peak reaches that point.
    if acPeakVoltage >= outputVoltage/2
        rippleMax = outputVoltage / (4 * boostInductance * switchingFrequency);
    else
        rippleMax = acPeakVoltage * (1 - modulationIndex) / (boostInductance * switchingFrequency);
    end
    corners(cornerIndex).inductorCurrentRipple = rippleMax;
    corners(cornerIndex).realizedRippleFraction = rippleMax / legCurrentPeak;
    corners(cornerIndex).inductorCurrentRippleAtACPeak = ...
        acPeakVoltage * (1 - modulationIndex) / (boostInductance * switchingFrequency);

    % Input-current ripple after interleaving. N triangles shifted by Tsw/N sum to a
    % peak-to-peak Vout*f*(1-f)/(N*L*fsw) with f = frac(N*duty), so cancellation is complete
    % wherever N*duty is a whole number and worst on a half. Swept, not assumed.
    instantaneousVoltage = acPeakVoltage * sin(linePhase);
    instantaneousDuty = 1 - instantaneousVoltage / outputVoltage;
    dutyFraction = mod(numberOfLegs * instantaneousDuty, 1);
    inputRippleOverCycle = outputVoltage * dutyFraction .* (1 - dutyFraction) / ...
        (numberOfLegs * boostInductance * switchingFrequency);
    corners(cornerIndex).inputCurrentRipple = max(inputRippleOverCycle);
    corners(cornerIndex).rippleCancellationRatio = ...
        corners(cornerIndex).inputCurrentRipple / rippleMax;

    % CCM is decided at the ZERO CROSSING, which is a different point of the line cycle from
    % where the ripple is worst. Requiring iL > dIL/2 in a leg, with iL = (Ipk/N)*sin(theta)
    % and dIL = Vpk*sin(theta)*(1 - m*sin(theta))/(L*fsw), the sin(theta) cancels exactly and
    % leaves Lccm = Vpk/(2*fsw*Ileg,pk), with no line phase left in it. Reaching the same
    % margin through the ripple fraction instead would tie it to |vac| = Vout/2, a point the
    % cycle never reaches when Vpk < Vout/2, and would overstate the margin there.
    criticalInductance = acPeakVoltage / (2 * switchingFrequency * legCurrentPeak);
    corners(cornerIndex).criticalInductance = criticalInductance;
    corners(cornerIndex).ccmMargin = boostInductance / criticalInductance;

    % Load below which conduction goes discontinuous near the zero crossings - N times the
    % single-leg threshold, because it is a total power and each leg carries a share.
    % Raising fsw does not help: holding the same ripple fraction shrinks L in exact
    % proportion.
    corners(cornerIndex).ccmPowerThreshold = numberOfLegs * ...
        corners(cornerIndex).acVoltageRms^2 / (2 * switchingFrequency * boostInductance);

    % The margin and the threshold power are one result in two units, so they must agree
    % exactly. Asserted because reaching either one through the ripple fraction silently
    % breaks the agreement at any AC input whose peak stays below Vout/2.
    assert(abs(corners(cornerIndex).ccmMargin - ...
        ratedPower / corners(cornerIndex).ccmPowerThreshold) < ...
        1e-9 * corners(cornerIndex).ccmMargin, ...
        "designInterleavedBoostPFCConverter:CCMResultsInconsistent", ...
        "CCM margin and CCM power threshold disagree at %s.", corners(cornerIndex).name);

    % The same criterion at the OTHER end of the line cycle, theta = 90 deg. The surviving
    % factor after the sin(theta) cancellation is (1 - m*sin(theta)), which is largest at the
    % zero crossing and smallest at the line peak, so the margin at the peak is 1/(1-m) times
    % the zero-crossing margin. Below this load even the line peak is discontinuous, which
    % makes the two thresholds the edges of a band: full-cycle CCM above the first,
    % discontinuous everywhere below the second, and discontinuous only around the zero
    % crossings in between.
    corners(cornerIndex).fullCycleDCMPowerThreshold = ...
        corners(cornerIndex).ccmPowerThreshold * (1 - modulationIndex);

    % Peak leg current (core saturation). The envelope peak sits slightly off the line peak
    % because the ripple is still growing there.
    instantaneousRipple = instantaneousVoltage .* (1 - instantaneousVoltage/outputVoltage) / ...
        (boostInductance * switchingFrequency);
    envelope = legCurrentPeak * sin(linePhase) + instantaneousRipple/2;
    [peakInductorCurrent, peakIndex] = max(envelope);
    corners(cornerIndex).peakInductorCurrent = peakInductorCurrent;
    corners(cornerIndex).peakInductorCurrentPhase = linePhase(peakIndex) * 180/pi;
    corners(cornerIndex).inductorCurrentRms = corners(cornerIndex).legCurrentRms;

    % Per-leg device currents, closed form over a half cycle with duty d = 1 - m*sin(theta).
    % The switch and the boost diode split one leg current: Iq^2 + Id^2 = IL^2 (asserted
    % below).
    corners(cornerIndex).switchCurrentRms = legCurrentPeak * ...
        sqrt(1/2 - 4*modulationIndex/(3*pi));
    corners(cornerIndex).boostDiodeCurrentRms = legCurrentPeak * ...
        sqrt(4*modulationIndex/(3*pi));
    corners(cornerIndex).boostDiodeCurrentAvg = legCurrentPeak * modulationIndex / 2;

    % The bridge sits BEFORE the legs split, so its diodes carry the whole line current and
    % gain nothing from interleaving. Its datasheet limit is an AVERAGE, hence both statistics.
    corners(cornerIndex).rectifierDiodeCurrentAvg = corners(cornerIndex).lineCurrentPeak / pi;
    corners(cornerIndex).rectifierDiodeCurrentRms = corners(cornerIndex).lineCurrentPeak / 2;

    % Two bridge diodes in series with the line at every instant - the loss a bridgeless
    % topology removes.
    corners(cornerIndex).bridgeConductionLoss = 2 * bridgeDiodeForwardVoltage * ...
        2 * corners(cornerIndex).lineCurrentPeak / pi;
end

% Self-check on the closed forms.
currentSplitError = max(abs([corners.switchCurrentRms].^2 + [corners.boostDiodeCurrentRms].^2 - ...
    [corners.inductorCurrentRms].^2));
assert(currentSplitError < 1e-9 * max([corners.legCurrentPeak])^2, ...
    "designInterleavedBoostPFCConverter:CurrentSplit", ...
    "Switch and diode RMS currents do not sum to the leg RMS current.");

% Devices are rated at the lowest line voltage, where the current is highest.
[~, stressCornerIndex] = max([corners.lineCurrentPeak]);
stressCorner = corners(stressCornerIndex);

% ---- DC-bus capacitor: two independent requirements, the larger wins ---------
% Interleaving cancels ripple at the SWITCHING frequency only. The bus ripple is at 2*fLine
% from the single-phase power pulsation, which every leg shares, so the capacitor is sized
% exactly as for a single-leg converter of the same rating: peak-to-peak is
% Pout/(Vout*wLine*Co) - wLine, not 2*wLine, because peak-to-peak is twice the
% second-harmonic amplitude. The voltage loop must not correct it, so the capacitor sets it.
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
capacitorCurrentRms = ratedPower / (sqrt(2) * outputVoltage);

% ---- Assemble the design ----------------------------------------------------
% These field names are read by the plant mask - do not rename them here.
interleavedDesign.ratedPower = simscape.Value(ratedPower, "W");
interleavedDesign.nomInputVoltage = simscape.Value(acVoltageNom, "V");
interleavedDesign.lineFrequency = simscape.Value(lineFrequency, "Hz");
interleavedDesign.outputVoltage = simscape.Value(outputVoltage, "V");
interleavedDesign.switchingFrequency = simscape.Value(switchingFrequency, "Hz");
interleavedDesign.numberOfLegs = numberOfLegs;
interleavedDesign.boostInductance = simscape.Value(boostInductance, "H");
interleavedDesign.inductorResistance = simscape.Value(inductorResistance, "Ohm");
interleavedDesign.outputCapacitance = simscape.Value(outputCapacitance, "F");
interleavedDesign.capacitorResistance = simscape.Value(capacitorResistance, "Ohm");
interleavedDesign.initialCapacitorVoltage = simscape.Value(initialCapacitorVoltage, "V");

% Specification echo, so the design carries its provenance.
interleavedDesign.minInputVoltage = simscape.Value(acVoltageMin, "V");
interleavedDesign.maxInputVoltage = simscape.Value(acVoltageMax, "V");
interleavedDesign.requestedRippleFraction = inductorCurrentRippleFraction;
interleavedDesign.boostVoltageRatio = outputVoltage / acPeakVoltageMax;
interleavedDesign.boostIsFeasible = outputVoltage >= minimumFeasibleOutputVoltage;
interleavedDesign.minimumFeasibleOutputVoltage = simscape.Value(minimumFeasibleOutputVoltage, "V");

% Capacitor sizing detail.
interleavedDesign.capacitanceForRipple = simscape.Value(capacitanceForRipple, "F");
interleavedDesign.capacitanceForHoldUp = simscape.Value(capacitanceForHoldUp, "F");
interleavedDesign.capacitanceSetByRequirement = capacitanceSetByRequirement;
interleavedDesign.outputVoltageRipplePeakToPeak = simscape.Value(outputVoltageRipplePeakToPeak, "V");
interleavedDesign.capacitorCurrentRms = simscape.Value(capacitorCurrentRms, "A");
interleavedDesign.outputCurrent = simscape.Value(outputCurrent, "A");

% Which AC input voltage set what, and the CCM outcome at the sized inductance.
interleavedDesign.inductanceSetByInputVoltage = corners(rippleCornerIndex).name;
interleavedDesign.ratingSetByInputVoltage = stressCorner.name;
[minimumCCMMargin, ccmMarginCornerIndex] = min([corners.ccmMargin]);
[maximumCCMPowerThreshold, ccmPowerCornerIndex] = max([corners.ccmPowerThreshold]);
interleavedDesign.minimumCCMMargin = minimumCCMMargin;
interleavedDesign.ccmHoldsOverFullLineCycle = minimumCCMMargin > 1;
interleavedDesign.ccmPowerThreshold = simscape.Value(maximumCCMPowerThreshold, "W");
interleavedDesign.ccmPowerThresholdFraction = maximumCCMPowerThreshold / ratedPower;
interleavedDesign.ccmPowerThresholdInputVoltage = corners(ccmPowerCornerIndex).name;

% The lower edge of the same band: below this load conduction is discontinuous over the whole
% line cycle, the line peak included. Reported so the CCM result reads as a range rather than
% as a single pass or fail.
[maximumFullCycleDCMPowerThreshold, fullCycleDCMCornerIndex] = ...
    max([corners.fullCycleDCMPowerThreshold]);
interleavedDesign.fullCycleDCMPowerThreshold = ...
    simscape.Value(maximumFullCycleDCMPowerThreshold, "W");
interleavedDesign.fullCycleDCMPowerThresholdFraction = ...
    maximumFullCycleDCMPowerThreshold / ratedPower;
interleavedDesign.fullCycleDCMPowerThresholdInputVoltage = corners(fullCycleDCMCornerIndex).name;

% What interleaving achieves, at the worst AC input voltage for each quantity.
interleavedDesign.worstCaseInductorCurrentRipple = ...
    simscape.Value(max([corners.inductorCurrentRipple]), "A");
interleavedDesign.worstCaseInputCurrentRipple = ...
    simscape.Value(max([corners.inputCurrentRipple]), "A");
interleavedDesign.rippleCancellationRatio = max([corners.inputCurrentRipple]) / ...
    max([corners.inductorCurrentRipple]);
interleavedDesign.carrierPhaseShift = 360 / numberOfLegs;

% Per-leg device currents at the lowest line voltage, for the rating workflow.
interleavedDesign.peakLineCurrent = simscape.Value(stressCorner.lineCurrentPeak, "A");
interleavedDesign.rmsLineCurrent = simscape.Value(stressCorner.lineCurrentRms, "A");
interleavedDesign.peakLegCurrent = simscape.Value(stressCorner.legCurrentPeak, "A");
interleavedDesign.rmsLegCurrent = simscape.Value(stressCorner.legCurrentRms, "A");
interleavedDesign.peakInductorCurrent = simscape.Value(stressCorner.peakInductorCurrent, "A");
interleavedDesign.switchCurrentRms = simscape.Value(stressCorner.switchCurrentRms, "A");
interleavedDesign.boostDiodeCurrentRms = simscape.Value(stressCorner.boostDiodeCurrentRms, "A");
interleavedDesign.boostDiodeCurrentAvg = simscape.Value(stressCorner.boostDiodeCurrentAvg, "A");
interleavedDesign.rectifierDiodeCurrentRms = ...
    simscape.Value(stressCorner.rectifierDiodeCurrentRms, "A");
interleavedDesign.rectifierDiodeCurrentAvg = ...
    simscape.Value(stressCorner.rectifierDiodeCurrentAvg, "A");
interleavedDesign.bridgeConductionLoss = simscape.Value(stressCorner.bridgeConductionLoss, "W");

% The bridge diodes only ever block the line peak, so rating them at the bus would give
% 40% more device than they need.
interleavedDesign.deviceVoltageRating = simscape.Value(deviceVoltageMargin * outputVoltage, "V");
interleavedDesign.rectifierVoltageRating = ...
    simscape.Value(deviceVoltageMargin * acPeakVoltageMax, "V");

% Per-input-voltage detail as plain doubles, for the plot function and programmatic use.
interleavedDesign.operatingPoints = corners;

% ---- Display table ----------------------------------------------------------
% Component values, then the results the design is checked against. Device voltage and
% current ratings belong to selectInterleavedBoostPFCDeviceRating, not here. Quantities that
% vary over the AC input range are reported at their worst value, and the full
% per-input-voltage detail stays in interleavedDesign.operatingPoints.
componentName = { ...
    'Number of interleaved legs'; ...
    'Boost inductance per leg (LBoost)'; ...
    'Boost inductor ESR (RLboost)'; ...
    'DC-bus capacitance (CBoost)'; ...
    'DC-bus capacitor ESR (Rco)'; ...
    'Switching frequency (Fsw)'; ...
    'RMS line current (worst case)'; ...
    'Peak leg current with ripple (worst case)'; ...
    'Per-leg current ripple (worst case)'; ...
    'Input current ripple after cancellation'; ...
    'Minimum power for continuous conduction'; ...
    'DC-bus ripple, peak-to-peak'};
tableValue = [ ...
    numberOfLegs; ...
    boostInductance * 1e6; ...
    inductorResistance; ...
    outputCapacitance * 1e6; ...
    capacitorResistance; ...
    switchingFrequency * 1e-3; ...
    stressCorner.lineCurrentRms; ...
    stressCorner.peakInductorCurrent; ...
    max([corners.inductorCurrentRipple]); ...
    max([corners.inputCurrentRipple]); ...
    maximumCCMPowerThreshold; ...
    outputVoltageRipplePeakToPeak];
tableUnit = {'-'; 'uH'; 'Ohm'; 'uF'; 'Ohm'; 'kHz'; 'A'; 'A'; 'A'; 'A'; 'W'; 'V'};

designTable = table(char(componentName), tableValue, char(tableUnit), ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});

if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', "Interleaved Boost PFC Estimated Design Parameters"));
end

% Raised whether or not the tables are displayed: a silent caller still needs to know the
% design misses its own specification.
if ~interleavedDesign.boostIsFeasible
    warning("designInterleavedBoostPFCConverter:BoostMarginLow", ...
        "Output voltage (%.1f V) is only %.3f times the maximum AC peak (%.1f V), " + ...
        "below the requested margin of %.2f. The duty at the AC peak falls to %.3f, " + ...
        "leaving little room for the current loop. Raise outputVoltage above %.1f V.", ...
        outputVoltage, interleavedDesign.boostVoltageRatio, acPeakVoltageMax, ...
        boostVoltageMargin, corners(end).minimumDuty, minimumFeasibleOutputVoltage);
end

if ~interleavedDesign.ccmHoldsOverFullLineCycle
    % Quote the ripple bound, not a higher switching frequency, which cannot help.
    warning("designInterleavedBoostPFCConverter:DiscontinuousConduction", ...
        "At %s the sized per-leg inductance (%.1f uH) is %.3f times the critical " + ...
        "inductance, so conduction is discontinuous over part of the line cycle even at " + ...
        "rated power. Full-cycle CCM needs inductorCurrentRippleFraction below %.3f " + ...
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
