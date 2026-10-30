function [designTable, DABDesign] = designDABConverter(DABSpec, options)
%DESIGNDABCONVERTER Size the DAB power stage under single-phase-shift modulation.
%
%   [designTable, DABDesign] = designDABConverter(DABSpec, Name=Value) sizes the turns
%   ratio, the primary-referred series inductance, the dead time, the magnetizing
%   inductance, the output capacitor and the inductance realization split. It then reports
%   the phase shift, the device currents and the zero-voltage-switching (ZVS) feasibility
%   across the operating envelope, with the soft-switching floor for each bridge in each
%   power direction.
%
%   Inputs:
%     DABSpec  Converter specification: the voltage ranges, power levels, switching
%              frequency, device output capacitance, headroom and parasitics.
%
%   Optional DABSpec fields:
%     seriesInductanceOption             "Use transformer leakage inductance" or "Use external
%                                        inductance". Default transformer leakage.
%     leakageDistributionFactor          Primary share of the winding leakage, between 0 and
%                                        1. Default 0.8.
%     outputDischargeCycles              Switching cycles the output capacitor holds the
%                                        output up for unreplenished. Default 3.
%     outputVoltageRippleFraction        Output sag allowed over those cycles. Default 0.05.
%     minimumAllowedDeadTime             Dead time floor (s). Default 200e-9.
%     maximumAllowedDeadTime             Dead time ceiling (s). Default 0.08/fsw.
%     secondaryMosfetOutputCapacitance   Secondary device output capacitance (F). Default
%                                        mosfetOutputCapacitance.
%
%   Name-value options:
%     Realization                "Use transformer leakage inductance" or "Use external
%                                inductance". Default DABSpec.seriesInductanceOption.
%     DistributionFactor         Primary share of the winding leakage, between 0 and 1.
%                                Default DABSpec.leakageDistributionFactor.
%     LeakageReserveFraction     Leakage held back under the external realization.
%                                Default 0.10.
%     DisplayTableFlag           Display the design table and the notes. Default true.
%     DisplaySoftSwitchingTable  Display the per-bridge soft-switching table. Default false.
%
%   Outputs:
%     designTable  Table summarizing the sized power stage.
%     DABDesign    Structure the plant block mask reads. Physical quantities are
%                  simscape.Value in SI base units, ratios and flags plain doubles.
%
%   Example:
%     DABDefaultInputParameters;
%     [designTable, DABDesign] = designDABConverter(DABSpec);
%
%   See also DABDefaultInputParameters, DABSPSPhysics, computeDABSoftSwitchingLimit,
%   selectDABDeviceRating, plotDABZVSRegion.

% Copyright 2026 The MathWorks, Inc.

arguments
    DABSpec struct
    options.Realization (1,1) string = ""
    options.DistributionFactor double {mustBeScalarOrEmpty} = []
    options.LeakageReserveFraction (1,1) {mustBeNonnegative, mustBeLessThan(options.LeakageReserveFraction,1)} = 0.10
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
    options.DisplaySoftSwitchingTable (1,1) {mustBeNumericOrLogical} = false
end

% ---- Validate that every required specification field is present ------------
% The rating, device and parasitic fields have no defensible default, so a missing one is
% named here. The hold-up and
% dead-time bounds have defaults, applied below.
requiredSpecFields = [ ...
    "minInputVoltage", "maxInputVoltage", "minOutputVoltage", "maxOutputVoltage", ...
    "ratedPower", "minSoftSwitchPower", "switchingFrequency", "mosfetOutputCapacitance", ...
    "peakPowerHeadroom", "magCurrentFraction", ...
    "seriesInductorESR", "primaryWindingR", "secondaryWindingR"];
missingSpecFields = requiredSpecFields(~isfield(DABSpec, requiredSpecFields));
if ~isempty(missingSpecFields)
    error("designDABConverter:MissingSpecField", ...
        "DABSpec is missing required field(s): %s.", strjoin(missingSpecFields, ", "));
end

% ---- Extract specification to plain doubles in SI base units ----------------
V1min = value(DABSpec.minInputVoltage,  "V");
V1max = value(DABSpec.maxInputVoltage,  "V");
V2min = value(DABSpec.minOutputVoltage, "V");
V2max = value(DABSpec.maxOutputVoltage, "V");
Prated = value(DABSpec.ratedPower,        "W");
Pmin   = value(DABSpec.minSoftSwitchPower, "W");
fsw    = value(DABSpec.switchingFrequency, "Hz");
Coss   = value(DABSpec.mosfetOutputCapacitance, "F");
peakPowerHeadroom = DABSpec.peakPowerHeadroom;
alpha  = DABSpec.magCurrentFraction;

% Optional hold-up spec.
if isfield(DABSpec, 'outputDischargeCycles')
    outputDischargeCycles = DABSpec.outputDischargeCycles;
else
    outputDischargeCycles = 3;
end
if isfield(DABSpec, 'outputVoltageRippleFraction')
    outputVoltageRippleFraction = DABSpec.outputVoltageRippleFraction;
else
    outputVoltageRippleFraction = 0.05;
end

% Optional secondary device capacitance. The two bridges often use different parts, and each
% bridge commutates against its own. Default to the primary value.
if isfield(DABSpec, 'secondaryMosfetOutputCapacitance')
    CossSec = value(DABSpec.secondaryMosfetOutputCapacitance, "F");
else
    CossSec = Coss;
end

% Optional dead-time bounds: a hardware floor from the processor timer and gate-driver
% delay, and a ceiling at a usable fraction of the switching period.
if isfield(DABSpec, 'minimumAllowedDeadTime')
    TdMin = value(DABSpec.minimumAllowedDeadTime, "s");
else
    TdMin = 200e-9;                 % 200 ns processor/gate-driver hardware floor
end
if isfield(DABSpec, 'maximumAllowedDeadTime')
    TdMax = value(DABSpec.maximumAllowedDeadTime, "s");
else
    TdMax = 0.08 / fsw;             % ~8% of the switching period
end

% ---- STEP 1: turns ratio by nominal-voltage matching ------------------------
V1nom = (V1min + V1max) / 2;
V2nom = (V2min + V2max) / 2;
n = V1nom / V2nom;

% Voltage conversion ratio M = n*V2/V1 and its extremes across the voltage range.
DABDesign.maxConversionRatio = n * V2max / V1min;   % highest M (primary ZVS hardest)
DABDesign.minConversionRatio = n * V2min / V1max;   % lowest  M (secondary ZVS hardest)
DABDesign.nomConversionRatio = n * V2nom / V1nom;   % ~1 by construction

% ---- STEP 2: series inductance from the peak-power headroom rule ------------
% LpeakRated is the inductance whose pi/2 peak at V1min and V2min is exactly rated power;
% dividing by the headroom makes L smaller, so rated power is reached strictly below pi/2.
% More headroom widens the control margin and raises the device currents.
LpeakRated = n * V1min * V2min / (8 * fsw * Prated);   % peak power = rated at pi/2
L = LpeakRated / peakPowerHeadroom;                    % peak power = headroom*rated
DABDesign.peakPowerHeadroom = peakPowerHeadroom;

% ---- STEP 3: realization split (external inductor or transformer leakage) ----
% Either way the primary-referred total stays equal to L. The per-winding leakage is split
% by the distribution factor h (the primary share), the secondary share referred by n^2.
% This is sized before the soft-switching work because it decides how much inductance sits
% on each side of the magnetizing branch, and each bridge commutates against its own side.
% The name-value options override the specification fields, which default to transformer
% leakage with 80 % of it on the primary
if options.Realization == ""
    options.Realization = "Use transformer leakage inductance";
    if isfield(DABSpec, 'seriesInductanceOption'), options.Realization = string(DABSpec.seriesInductanceOption); end
end
mustBeMember(options.Realization, ["Use transformer leakage inductance", "Use external inductance"]);
if isempty(options.DistributionFactor)
    options.DistributionFactor = 0.8;
    if isfield(DABSpec, 'leakageDistributionFactor'), options.DistributionFactor = DABSpec.leakageDistributionFactor; end
end
% Both windings need positive leakage, so the primary share is strictly between 0 and 1
if ~(options.DistributionFactor > 0 && options.DistributionFactor < 1)
    error('designDABConverter:distributionFactor', ...
        'The leakage distribution factor must be between 0 and 1, not %g.', options.DistributionFactor);
end
DABDesign.realization = options.Realization;
h = options.DistributionFactor;
DABDesign.leakageDistributionFactor = h;
switch options.Realization
    case "Use transformer leakage inductance"
        % All of it is transformer leakage; the external inductor is bypassed. Lr is still
        % set to 2 % of L, so switching the plant mask to the external inductor simulates
        % instead of erroring on a zero inductance.
        leakageTotal   = L;
        DABDesign.Lr   = 0.02 * L;
        externalInductanceInCircuit = 0;
    otherwise   % "Use external inductance"
        % A real transformer always has leakage and the plant requires it positive, so
        % reserve a fraction as leakage and put the rest in the external inductor, which
        % sits in series: Lr + leakageTotal = L, all primary-referred.
        leakageTotal   = options.LeakageReserveFraction * L;
        DABDesign.Lr   = L - leakageTotal;
        externalInductanceInCircuit = DABDesign.Lr;
end
% Llk2 is the physical secondary-side leakage, so its primary-referred share
% (1-h)*leakageTotal is divided by n^2 to express it on the secondary.
DABDesign.Llk1 = h * leakageTotal;
DABDesign.Llk2 = (1 - h) * leakageTotal / n^2;

% Primary-referred inductance on each side of the magnetizing branch. The external inductor
% and the primary leakage are on the primary side, the referred secondary leakage on the
% other, and the two still add up to L.
primarySideFraction = (externalInductanceInCircuit + DABDesign.Llk1) / L;
DABDesign.primarySideFraction = primarySideFraction;

% ---- STEP 4: dead time and magnetizing inductance ---------------------------
% Both leg switches commutate together - the turning-off device's capacitance charges while
% the turning-on device's discharges - so the inductor swings two device capacitances.
legNodeCapacitance = 2 * Coss;
% From the resonant leg transition (L resonating against the node capacitance), held
% inside the allowed range: too small is unreachable for the processor timer and gate
% driver, too large steals from the power-transfer window. The flags record which bound was
% hit, so it can be reported.
deadTimeComputed = pi * sqrt(legNodeCapacitance * L);
Td = min(max(deadTimeComputed, TdMin), TdMax);
DABDesign.deadTime = Td;
DABDesign.deadTimeComputed = deadTimeComputed;
DABDesign.deadTimeBelowMin = deadTimeComputed < TdMin;
DABDesign.deadTimeExceedsMax = deadTimeComputed > TdMax;

% At the efficiency floor: the whole magnetizing-current budget goes on ZVS. A smaller Lm
% gives a larger load-independent magnetizing current and wider ZVS, bounded by efficiency.
ratedPrimaryCurrent = Prated / V1nom;
magCurrentPeak = alpha * ratedPrimaryCurrent;          % Im_pk budget
Lm = V1nom / (4 * fsw * magCurrentPeak);               % Lm from Im_pk = V1/(4 fsw Lm)
DABDesign.magnetizingCurrentPeak = magCurrentPeak;

% ---- STEP 5: the shared physics object --------------------------------------
% The power law, its D<=0.5 inverse and the per-bridge soft-switching model in one object,
% shared with the plot and selection functions.
sps = localPhysicsFor(n, fsw, L, Coss, CossSec, primarySideFraction, Lm, Td);

% Reported only.
DABDesign.peakPowerAtHalfPi = sps.maxPower(V1min, V2min);
% Fraction of the magnetizing current each bridge receives. The magnetizing branch sits
% between the two side inductances, so each bridge gets the share set by the inductance on
% the other side.
DABDesign.magnetizingShareToPrimary   = sps.magnetizingShareToPrimary;
DABDesign.magnetizingShareToSecondary = sps.magnetizingShareToSecondary;

% ---- STEP 6: switching-instant currents and device rating (rated, nominal) --
% Below 0.5 by the headroom construction.
DABDesign.dutyRatedAtLowestVoltages = sps.dutyForPower(Prated, V1min, V2min);
Dnom = sps.dutyForPower(Prated, V1nom, V2nom);
DABDesign.dutyRatedNominal = Dnom;

% The larger of the two commutation-instant currents: equal at the nominal matched ratio,
% and still right if the nominal voltage pair ever moves away from it.
DABDesign.peakInductorCurrent = sps.peakSeriesCurrent(Dnom, V1nom, V2nom);

% Exact for the piecewise-linear SPS waveform, integrated over a half cycle.
DABDesign.rmsInductorCurrent = localRmsInductorCurrent(V1nom, n * V2nom, Dnom, fsw, L);

% ---- STEP 7: soft-switching floor, per bridge and per power direction -------
% Each bridge turns a device on only after the charge on its own node has been moved, and
% the current already flowing at that instant is what moves it. Below some power that
% current is too small, and that power is the floor. Four numbers, because the two bridges
% see different inductance and capacitance, and reversing the power swaps which bridge
% commutates first. Each is the worst case over the four V1 and V2 combinations.
voltageCorners = [ ...
    V1min V2min; ...
    V1min V2max; ...
    V1max V2min; ...
    V1max V2max];
[floorMatrix, criticalCase] = localBridgeFloors(sps, voltageCorners);
DABDesign.primaryZVSFloorForward   = floorMatrix(1, 1);
DABDesign.secondaryZVSFloorForward = floorMatrix(2, 1);
DABDesign.primaryZVSFloorReverse   = floorMatrix(1, 2);
DABDesign.secondaryZVSFloorReverse = floorMatrix(2, 2);
% Worse of the two power directions for each bridge, and the overall floor: above it the
% converter soft switches and below it hard switches.
DABDesign.primaryZVSFloor   = max(floorMatrix(1, :));
DABDesign.secondaryZVSFloor = max(floorMatrix(2, :));
DABDesign.achievedMinSoftSwitchPower = max(floorMatrix(:));
DABDesign.criticalSoftSwitchingCase = criticalCase;

% Smallest L that brings the floor down to Pmin, by inverting the same model. A larger L
% transfers less power for the same phase shift, so the floor falls as L grows. This is the
% counterpart of inductanceForRatedPeak (the largest L that still delivers rated power) -
% when this minimum exceeds that maximum, the two requirements cannot both be met. The trial
% inductance is the search variable and the dead time follows it, so each trial builds its
% own physics object.
trialFloor = @(Ltest) max(reshape(localBridgeFloors( ...
    localPhysicsFor(n, fsw, Ltest, Coss, CossSec, primarySideFraction, Lm, ...
    min(max(pi * sqrt(legNodeCapacitance * Ltest), TdMin), TdMax)), ...
    voltageCorners), [], 1));
DABDesign.minInductanceForSoftSwitching = localSolveMinInductance(trialFloor, Pmin);

% ---- STEP 8: output capacitor by hold-up (discharge) thumb rule -------------
% The minimum output voltage is the worst case twice over: the load current is highest
% there and the same absolute sag is the largest fraction of the voltage. From Co*dV = I*dt
% over an unreplenished window of outputDischargeCycles.
outputLoadCurrent   = Prated / V2min;
dischargeInterval   = outputDischargeCycles / fsw;
allowedVoltageDrop  = outputVoltageRippleFraction * V2min;
Co = outputLoadCurrent * dischargeInterval / allowedVoltageDrop;
DABDesign.outputCapacitance = Co;
DABDesign.outputDischargeCycles = outputDischargeCycles;
DABDesign.outputVoltageRippleFraction = outputVoltageRippleFraction;

% ---- Store remaining design values (SI base units) --------------------------
DABDesign.turnsRatio = n;
DABDesign.seriesInductance = L;                 % total primary-referred series L
DABDesign.inductanceForRatedPeak = LpeakRated;  % L whose pi/2 peak equals rated
DABDesign.Lm = Lm;
DABDesign.switchingFrequency = fsw;
DABDesign.mosfetOutputCapacitance = Coss;
DABDesign.mosfetOutputCapacitanceSecondary = CossSec;
DABDesign.ratedPower = Prated;
DABDesign.minSoftSwitchPower = Pmin;
DABDesign.V1min = V1min;  DABDesign.V1max = V1max;  DABDesign.V1nom = V1nom;
DABDesign.V2min = V2min;  DABDesign.V2max = V2max;  DABDesign.V2nom = V2nom;
DABDesign.RLr  = DABSpec.seriesInductorESR;
DABDesign.R1   = DABSpec.primaryWindingR;
DABDesign.R2   = DABSpec.secondaryWindingR;

% Feasibility flags, reported and not tuned. The rated-power phase shift is below pi/2 by
% construction, so phaseShiftHasMargin adds a comfort band on top of merely being below it.
DABDesign.zvsMeetsSpec = DABDesign.achievedMinSoftSwitchPower <= Pmin;
DABDesign.dutyWithinCeiling = DABDesign.dutyRatedAtLowestVoltages < 0.5;
DABDesign.phaseShiftHasMargin = DABDesign.dutyRatedAtLowestVoltages < 0.45;   % < 0.9 * (pi/2)

% ---- Build display table ----------------------------------------------------
ComponentName = { ...
    'Transformer turns ratio (n = N1/N2)'; ...
    'Total series inductance (L)'; ...
    'External series inductance (Lr)'; ...
    'Primary leakage inductance (Llk1)'; ...
    'Secondary leakage inductance (Llk2)'; ...
    'Magnetizing inductance (Lm)'; ...
    'Output capacitance (Co)'; ...
    'Switching frequency (Fsw)'; ...
    'Dead time (Td)'; ...
    'Peak inductor current (rated, nom)'; ...
    'RMS inductor current (rated, nom)'; ...
    'Rated-power phase shift at nominal (D)'; ...
    'Rated-power phase shift at V1min, V2min (D)'; ...
    'Achieved min soft-switching power'};
Value = [ ...
    round(n, 3); ...
    L * 1e6; ...
    DABDesign.Lr   * 1e6; ...
    DABDesign.Llk1 * 1e6; ...
    DABDesign.Llk2 * 1e6; ...
    Lm * 1e3; ...
    Co * 1e6; ...
    fsw * 1e-3; ...
    DABDesign.deadTime * 1e9; ...
    DABDesign.peakInductorCurrent; ...
    DABDesign.rmsInductorCurrent; ...
    DABDesign.dutyRatedNominal; ...
    DABDesign.dutyRatedAtLowestVoltages; ...
    DABDesign.achievedMinSoftSwitchPower];
Unit = {'-'; 'uH'; 'uH'; 'uH'; 'uH'; 'mH'; 'uF'; 'kHz'; 'ns'; 'A'; 'A'; '-'; '-'; 'W'};

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(ComponentName), Value, char(Unit), 'VariableNames', tableHeaderNames);

% ---- Build the soft-switching summary table ---------------------------------
% Its own function, so the live script's Soft-Switching Region section can display it
% alone. Built here from the plain-double intermediates, before the seal below.
DABDesign.softSwitchingTable = computeDABSoftSwitchingLimit(DABDesign, ...
    'DisplayTableFlag', options.DisplaySoftSwitchingTable);

if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', "DAB Converter Estimated Design Parameters"));
    if ~DABDesign.phaseShiftHasMargin
        warning("designDABConverter:PhaseShiftMarginLow", ...
            "Rated-power phase shift at V1min and V2min (phi = %.2f x pi/2) is close " + ...
            "to the pi/2 ceiling. Increase peakPowerHeadroom to move it away from the " + ...
            "flat maximum-power region.", 2 * DABDesign.dutyRatedAtLowestVoltages);
    end
    if ~DABDesign.zvsMeetsSpec
        warning("designDABConverter:ZVSFloorAboveSpec", ...
            "Achieved minimum soft-switching power (%.0f W, %.0f%% of rated) is above the " + ...
            "spec (%.0f W). The worst case is the %s. Four ways to lower it: raise the " + ...
            "series inductance to at least %.2f uH (now %.2f uH), narrow the output-voltage " + ...
            "range so the conversion ratio M stays closer to 1 (now %.3f..%.3f), lower the " + ...
            "magnetizing inductance so more current circulates, or accept hard switching " + ...
            "below the achieved floor.", ...
            DABDesign.achievedMinSoftSwitchPower, ...
            100 * DABDesign.achievedMinSoftSwitchPower / Prated, Pmin, ...
            DABDesign.criticalSoftSwitchingCase, ...
            DABDesign.minInductanceForSoftSwitching * 1e6, L * 1e6, ...
            DABDesign.minConversionRatio, DABDesign.maxConversionRatio);
    end
    if DABDesign.deadTimeBelowMin
        warning("designDABConverter:DeadTimeBelowMin", ...
            "Computed dead time (%.1f ns) is below the minimum allowed dead time " + ...
            "(%.1f ns) and has been clamped up to it. The hardware floor (processor " + ...
            "timer resolution and gate-driver delay) then sets the dead time rather " + ...
            "than the resonant transition; verify soft switching still holds at the " + ...
            "longer dead time, or lower the minimum allowed dead time if the hardware " + ...
            "permits.", deadTimeComputed * 1e9, TdMin * 1e9);
    end
    if DABDesign.deadTimeExceedsMax
        warning("designDABConverter:DeadTimeExceedsMax", ...
            "Computed dead time (%.1f ns) exceeds the maximum allowed dead time " + ...
            "(%.1f ns) and has been clamped down to it. A dead time this large is a " + ...
            "big fraction of the switching period and steals from the power-transfer " + ...
            "window; reduce the series inductance L or the device output capacitance " + ...
            "Coss, or raise the maximum allowed dead time.", ...
            deadTimeComputed * 1e9, TdMax * 1e9);
    end
end

% ---- Seal physical quantities as simscape.Value in SI base units ------------
% The mask reads an SI magnitude directly, as DABDesign.Lr.value with its unit popup on the
% matching SI base unit, so the seal is what keeps a unit from being assumed. Dimensionless
% quantities stay plain doubles, and the display table above was already built from the
% plain-double intermediates in engineering units.
DABDesign.seriesInductance          = simscape.Value(DABDesign.seriesInductance, "H");
DABDesign.inductanceForRatedPeak     = simscape.Value(DABDesign.inductanceForRatedPeak, "H");
DABDesign.minInductanceForSoftSwitching = simscape.Value(DABDesign.minInductanceForSoftSwitching, "H");
DABDesign.Lr                         = simscape.Value(DABDesign.Lr, "H");
DABDesign.Llk1                       = simscape.Value(DABDesign.Llk1, "H");
DABDesign.Llk2                       = simscape.Value(DABDesign.Llk2, "H");
DABDesign.Lm                         = simscape.Value(DABDesign.Lm, "H");
DABDesign.deadTime                   = simscape.Value(DABDesign.deadTime, "s");
DABDesign.deadTimeComputed           = simscape.Value(DABDesign.deadTimeComputed, "s");
DABDesign.outputCapacitance          = simscape.Value(DABDesign.outputCapacitance, "F");
DABDesign.mosfetOutputCapacitance    = simscape.Value(DABDesign.mosfetOutputCapacitance, "F");
DABDesign.mosfetOutputCapacitanceSecondary = ...
    simscape.Value(DABDesign.mosfetOutputCapacitanceSecondary, "F");
DABDesign.switchingFrequency         = simscape.Value(DABDesign.switchingFrequency, "Hz");
DABDesign.ratedPower                 = simscape.Value(DABDesign.ratedPower, "W");
DABDesign.minSoftSwitchPower         = simscape.Value(DABDesign.minSoftSwitchPower, "W");
DABDesign.peakPowerAtHalfPi          = simscape.Value(DABDesign.peakPowerAtHalfPi, "W");
DABDesign.primaryZVSFloor            = simscape.Value(DABDesign.primaryZVSFloor, "W");
DABDesign.secondaryZVSFloor          = simscape.Value(DABDesign.secondaryZVSFloor, "W");
DABDesign.primaryZVSFloorForward     = simscape.Value(DABDesign.primaryZVSFloorForward, "W");
DABDesign.secondaryZVSFloorForward   = simscape.Value(DABDesign.secondaryZVSFloorForward, "W");
DABDesign.primaryZVSFloorReverse     = simscape.Value(DABDesign.primaryZVSFloorReverse, "W");
DABDesign.secondaryZVSFloorReverse   = simscape.Value(DABDesign.secondaryZVSFloorReverse, "W");
DABDesign.achievedMinSoftSwitchPower = simscape.Value(DABDesign.achievedMinSoftSwitchPower, "W");
DABDesign.V1min                      = simscape.Value(DABDesign.V1min, "V");
DABDesign.V1max                      = simscape.Value(DABDesign.V1max, "V");
DABDesign.V1nom                      = simscape.Value(DABDesign.V1nom, "V");
DABDesign.V2min                      = simscape.Value(DABDesign.V2min, "V");
DABDesign.V2max                      = simscape.Value(DABDesign.V2max, "V");
DABDesign.V2nom                      = simscape.Value(DABDesign.V2nom, "V");
DABDesign.RLr                        = simscape.Value(DABDesign.RLr, "Ohm");
DABDesign.R1                         = simscape.Value(DABDesign.R1, "Ohm");
DABDesign.R2                         = simscape.Value(DABDesign.R2, "Ohm");
DABDesign.magnetizingCurrentPeak     = simscape.Value(DABDesign.magnetizingCurrentPeak, "A");
DABDesign.peakInductorCurrent        = simscape.Value(DABDesign.peakInductorCurrent, "A");
DABDesign.rmsInductorCurrent         = simscape.Value(DABDesign.rmsInductorCurrent, "A");

end

% =============================================================================
function Irms = localRmsInductorCurrent(V1, V2ref, D, fsw, L)
% RMS of the piecewise-linear SPS inductor current over a half cycle. theta = w*t in [0,pi],
% the primary applying +V1 and the referred secondary lagging by phi = pi*D. Odd half-wave
% symmetry sets the DC offset through i(pi) = -i(0).
w = 2 * pi * fsw;
phi = pi * D;
numHalfCycleSamples = 20000;   % half-cycle grid resolution for the RMS trapezoidal integral
theta = linspace(0, pi, numHalfCycleSamples);
inductorVoltage = (theta < phi) .* (V1 + V2ref) + (theta >= phi) .* (V1 - V2ref);
increment = cumtrapz(theta, inductorVoltage) / (w * L);
i0 = -increment(end) / 2;                        % from i(pi) = -i(0)
inductorCurrent = i0 + increment;
Irms = sqrt(trapz(theta, inductorCurrent.^2) / pi);
end

% =============================================================================
function sps = localPhysicsFor(n, fsw, L, Coss, CossSec, primarySideFraction, Lm, Td)
% One place that builds the physics object, so the design values and the trial inductances
% inside the root solve are described the same way.
sps = DABSPSPhysics(n, fsw, L, Coss, ...
    SecondaryOutputCapacitance = CossSec, ...
    PrimarySideFraction = primarySideFraction, ...
    MagnetizingInductance = Lm, ...
    DeadTime = Td);
end

% =============================================================================
function [floorMatrix, criticalCase] = localBridgeFloors(sps, voltageCorners)
% Soft-switching floor of each bridge in each power direction, worst case over the V1 and V2
% combinations. Rows are the primary and the secondary bridge, columns are forward and
% reverse power. criticalCase names where the largest of the four sits.
%
% A voltage pair the bridge cannot commutate at any phase shift returns Inf, so it shows up
% as infeasible rather than quietly dropping out of the maximum.
bridgeNames = ["primary", "secondary"];
directionSigns = [1, -1];
directionNames = ["forward", "reverse"];
floorMatrix = zeros(2, 2);
criticalCase = "";
worstFloor = -Inf;
for bridgeIndex = 1:2
    for directionIndex = 1:2
        for cornerIndex = 1:size(voltageCorners, 1)
            cornerInputVoltage  = voltageCorners(cornerIndex, 1);
            cornerOutputVoltage = voltageCorners(cornerIndex, 2);
            dutyBoundary = sps.bridgeZvsDutyBoundary(bridgeNames(bridgeIndex), ...
                cornerInputVoltage, cornerOutputVoltage, directionSigns(directionIndex));
            if isnan(dutyBoundary)
                cornerFloor = Inf;
            else
                [~, ~, transferredPower] = sps.bridgeCommutationCurrents( ...
                    dutyBoundary, cornerInputVoltage, cornerOutputVoltage);
                cornerFloor = abs(transferredPower);
            end
            if cornerFloor > floorMatrix(bridgeIndex, directionIndex)
                floorMatrix(bridgeIndex, directionIndex) = cornerFloor;
            end
            if cornerFloor > worstFloor
                worstFloor = cornerFloor;
                criticalCase = sprintf('%s bridge, %s power, %g V / %g V', ...
                    bridgeNames(bridgeIndex), directionNames(directionIndex), ...
                    cornerInputVoltage, cornerOutputVoltage);
            end
        end
    end
end
end

% =============================================================================
function Lmin = localSolveMinInductance(floorFcn, targetPower)
% Smallest inductance at which the soft-switching floor comes down to the target power.
%
% The floor falls as L grows, but only while a commutation current large enough to move the
% node charge is still reachable. Past some inductance no phase shift produces one and the
% floor is infinite, so the search finds that feasible edge first and looks for the crossing
% below it. NaN means the target is out of reach, which is more useful than a number from an
% unbracketed solve.
lowerInductance = 1e-9;     % 1 nH: floor far above any practical target
upperInductance = 1e-1;     % 100 mH: no commutation reaches its minimum current here
if ~isfinite(floorFcn(lowerInductance))
    Lmin = NaN;
    return;
end
if isfinite(floorFcn(upperInductance))
    largestFeasible = upperInductance;
else
    feasibleEnd = lowerInductance;
    infeasibleEnd = upperInductance;
    for iteration = 1:30                     % bisect on log L over eight decades
        middleInductance = sqrt(feasibleEnd * infeasibleEnd);
        if isfinite(floorFcn(middleInductance))
            feasibleEnd = middleInductance;
        else
            infeasibleEnd = middleInductance;
        end
    end
    largestFeasible = feasibleEnd;
end
if floorFcn(largestFeasible) > targetPower
    Lmin = NaN;
    return;
end
Lmin = fzero(@(Ltest) floorFcn(Ltest) - targetPower, [lowerInductance, largestFeasible]);
end
