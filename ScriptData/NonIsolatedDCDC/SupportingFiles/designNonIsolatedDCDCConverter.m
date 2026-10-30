function [designTable, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(nonIsolatedDCDCSpec, options)
%DESIGNNONISOLATEDDCDCCONVERTER Size a non-isolated DC-DC converter power stage.
%
%   [designTable, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(
%   nonIsolatedDCDCSpec, Name=Value) sizes the inductance and output capacitance of a
%   non-isolated DC-DC converter in continuous conduction mode. It then reports the device
%   and magnetics rating, the conduction-mode margin and the feasibility of the design
%   across the whole input range. One code path covers all six topologies of the plant
%   block. Every voltage-dependent quantity is evaluated at all three input voltages
%   and the worst one named. Power stage only: the loops, the dead time and the gate
%   drive belong to designNonIsolatedDCDCController.
%
%   Inputs:
%     nonIsolatedDCDCSpec  Converter specification structure, holding the required and
%                          optional fields listed below.
%
%   Required nonIsolatedDCDCSpec fields:
%     topology                          One of the plant block's six dropdown names.
%     minInputVoltage                   Input voltage range (V).
%     nomInputVoltage
%     maxInputVoltage
%     outputVoltage                     Regulated output voltage (V), a magnitude for
%                                       the inverting buck-boost.
%     ratedPower                        Rated output power (W). The inductor current is
%                                       sized on this value, at each input voltage.
%     switchingFrequency                Switching frequency (Hz).
%     inductorCurrentRippleFraction     Peak-to-peak inductor ripple over average
%                                       current.
%     outputVoltageRippleFraction       Allowed switching ripple, as a fraction of the
%                                       output voltage.
%     loadStepFraction                  Load step the capacitor must ride out, as a
%                                       fraction of rated power.
%     loadStepVoltageDeviationFraction  Output deviation allowed during that step.
%     voltageLoopCrossoverFrequency     Voltage loop crossover (Hz), which fixes how
%                                       long the capacitor holds the output up alone.
%     inductorESR                       Inductor series resistance (Ohm).
%     capacitorESR                      Output capacitor series resistance (Ohm).
%
%   Optional nonIsolatedDCDCSpec fields:
%     initialCapacitorVoltage  Output capacitor voltage at t = 0 (V). Default: the input
%                              voltage for a boost, zero otherwise.
%     conversionRatioMargin    How far the conversion ratio must clear unity at the
%                              worst input voltage. Default 1.05.
%     deviceVoltageMargin      Blocking-voltage derating factor. Default 1.30.
%
%   Name-value options:
%     DisplayTableFlag    Display the design table and the design notes. Default true.
%
%   Outputs:
%     designTable             Table summarizing the sized power stage.
%     nonIsolatedDCDCDesign   Structure the plant block mask reads. Physical quantities
%                             are simscape.Value in SI base units, ratios and flags
%                             plain doubles.
%
%   Example:
%     nonIsolatedDCDCSpec.topology         = "Synchronous Boost";
%     nonIsolatedDCDCSpec.minInputVoltage  = simscape.Value(180,"V");
%     nonIsolatedDCDCSpec.nomInputVoltage  = simscape.Value(200,"V");
%     nonIsolatedDCDCSpec.maxInputVoltage  = simscape.Value(220,"V");
%     nonIsolatedDCDCSpec.outputVoltage    = simscape.Value(400,"V");
%     nonIsolatedDCDCSpec.ratedPower       = simscape.Value(1500,"W");
%     [designTable, nonIsolatedDCDCDesign] = ...
%         designNonIsolatedDCDCConverter(nonIsolatedDCDCSpec);
%
%   See also designNonIsolatedDCDCController,
%   EstimateNonIsolatedDCDCParameters, NonIsolatedDCDCDefaultInputParameters.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCSpec (1,1) struct
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

% ---- Validate that every required specification field is present ------------
% The optional fields below have defaults, but the rating, ripple and parasitic fields have
% none. Checked up front so a missing field errors by name rather than failing deep in the
% sizing math.
requiredSpecFields = [ ...
    "topology", "minInputVoltage", "nomInputVoltage", "maxInputVoltage", ...
    "outputVoltage", "ratedPower", "switchingFrequency", ...
    "inductorCurrentRippleFraction", "outputVoltageRippleFraction", ...
    "loadStepFraction", "loadStepVoltageDeviationFraction", ...
    "voltageLoopCrossoverFrequency", "inductorESR", "capacitorESR"];
missingSpecFields = requiredSpecFields(~isfield(nonIsolatedDCDCSpec, requiredSpecFields));
if ~isempty(missingSpecFields)
    error("designNonIsolatedDCDCConverter:MissingSpecField", ...
        "nonIsolatedDCDCSpec is missing required field(s): %s.", ...
        strjoin(missingSpecFields, ", "));
end

% ---- Resolve the topology --------------------------------------------------
% One name from the plant block's dropdown, split into the family that sets the equations
% and the flag that says whether the second device is controlled.
supportedTopologies = ["Buck", "Synchronous Buck", "Boost", "Synchronous Boost", ...
    "Buck-Boost", "Synchronous Buck-Boost"];
topologyName = string(nonIsolatedDCDCSpec.topology);
if ~ismember(topologyName, supportedTopologies)
    error("designNonIsolatedDCDCConverter:UnknownTopology", ...
        "topology must be one of: %s. Got ""%s"".", ...
        strjoin(supportedTopologies, ", "), topologyName);
end
isSynchronous = startsWith(topologyName, "Synchronous");
topologyFamily = erase(topologyName, "Synchronous ");

% Used throughout the report, so no row leaves the reader guessing which device it means.
if isSynchronous
    secondDeviceName = "synchronous switch";
else
    secondDeviceName = "freewheeling diode";
end

% ---- Extract specification to plain doubles in SI base units ----------------
inputVoltageMin = value(nonIsolatedDCDCSpec.minInputVoltage, "V");
inputVoltageNom = value(nonIsolatedDCDCSpec.nomInputVoltage, "V");
inputVoltageMax = value(nonIsolatedDCDCSpec.maxInputVoltage, "V");
outputVoltage = value(nonIsolatedDCDCSpec.outputVoltage, "V");
ratedPower = value(nonIsolatedDCDCSpec.ratedPower, "W");
switchingFrequency = value(nonIsolatedDCDCSpec.switchingFrequency, "Hz");
voltageLoopCrossoverFrequency = value(nonIsolatedDCDCSpec.voltageLoopCrossoverFrequency, "Hz");
inductorESR = value(nonIsolatedDCDCSpec.inductorESR, "Ohm");
capacitorESR = value(nonIsolatedDCDCSpec.capacitorESR, "Ohm");

inductorCurrentRippleFraction = nonIsolatedDCDCSpec.inductorCurrentRippleFraction;
outputVoltageRippleFraction = nonIsolatedDCDCSpec.outputVoltageRippleFraction;
loadStepFraction = nonIsolatedDCDCSpec.loadStepFraction;
loadStepVoltageDeviationFraction = nonIsolatedDCDCSpec.loadStepVoltageDeviationFraction;

% ---- Validate the specification values -------------------------------------
if ~(inputVoltageMin <= inputVoltageNom && inputVoltageNom <= inputVoltageMax)
    error("designNonIsolatedDCDCConverter:InputRangeNotOrdered", ...
        "Input voltages must satisfy min <= nom <= max. Got %.4g / %.4g / %.4g V.", ...
        inputVoltageMin, inputVoltageNom, inputVoltageMax);
end
if inputVoltageMin <= 0 || outputVoltage <= 0 || ratedPower <= 0 || switchingFrequency <= 0
    error("designNonIsolatedDCDCConverter:NonPositiveRating", ...
        "Input voltage, output voltage, rated power and switching frequency must be positive.");
end
if inductorCurrentRippleFraction <= 0 || outputVoltageRippleFraction <= 0
    error("designNonIsolatedDCDCConverter:NonPositiveRipple", ...
        "Ripple fractions must be positive.");
end
if voltageLoopCrossoverFrequency <= 0
    error("designNonIsolatedDCDCConverter:NonPositiveCrossover", ...
        "voltageLoopCrossoverFrequency must be positive: it sets how long the output " + ...
        "capacitor must hold the output up on its own during a load step.");
end

% ---- Optional specification fields, with documented defaults ---------------
if isfield(nonIsolatedDCDCSpec, "conversionRatioMargin")
    conversionRatioMargin = nonIsolatedDCDCSpec.conversionRatioMargin;
else
    conversionRatioMargin = 1.05;
end
if isfield(nonIsolatedDCDCSpec, "deviceVoltageMargin")
    deviceVoltageMargin = nonIsolatedDCDCSpec.deviceVoltageMargin;
else
    deviceVoltageMargin = 1.30;
end

% The natural starting voltage differs by topology, and matters most on a
% boost: its output capacitor charges to the input voltage through the high-side body diode
% before switching begins, and below that point a boost has NO control authority - the
% inductor sees a positive volt-second product in both subintervals, so the current rises at
% any duty. A buck and an inverting buck-boost start at zero.
if isfield(nonIsolatedDCDCSpec, "initialCapacitorVoltage")
    initialCapacitorVoltage = value(nonIsolatedDCDCSpec.initialCapacitorVoltage, "V");
elseif topologyFamily == "Boost"
    initialCapacitorVoltage = inputVoltageNom;
else
    initialCapacitorVoltage = 0;
end

%% ---- Step 0: feasibility ---------------------------------------------------
% Every voltage-dependent quantity is computed at all three input voltages and the
% worst one reported: the limits are not all reached at the same voltage, and which
% wins is topology-dependent.
cornerVoltages = [inputVoltageMin, inputVoltageNom, inputVoltageMax];
cornerNames = ["minimum input", "nominal input", "maximum input"];

% Duty comes first and alone, because it decides whether there is a design to report at
% all. Impossible (a duty outside (0, 1)) errors; under-margined (achievable but closer to
% a duty limit than conversionRatioMargin allows) warns and sets a flag. Collapsing the
% two would either reject usable designs or return nonsense.
switch topologyFamily
    case "Buck"
        cornerDuties = outputVoltage./cornerVoltages;
    case "Boost"
        cornerDuties = 1 - cornerVoltages/outputVoltage;
    otherwise
        cornerDuties = outputVoltage./(cornerVoltages + outputVoltage);
end

if any(cornerDuties <= 0) || any(cornerDuties >= 1)
    [~, worstCornerIndex] = max(abs(cornerDuties - 0.5));
    worstDuty = cornerDuties(worstCornerIndex);
    if topologyFamily == "Buck"
        error("designNonIsolatedDCDCConverter:BuckCannotBoost", ...
            "A buck cannot boost. At the %s voltage of %.4g V the duty required to " + ...
            "reach %.4g V is %.4g, outside the achievable range (0, 1). Lower the " + ...
            "output voltage below %.4g V, raise the input voltage, or use a " + ...
            "buck-boost, whose duty covers both directions.", ...
            cornerNames(worstCornerIndex), cornerVoltages(worstCornerIndex), ...
            outputVoltage, worstDuty, inputVoltageMin);
    else
        error("designNonIsolatedDCDCConverter:BoostCannotBuck", ...
            "A boost cannot buck. At the %s voltage of %.4g V the duty required to " + ...
            "reach %.4g V is %.4g, outside the achievable range (0, 1). Raise the " + ...
            "output voltage above %.4g V, lower the input voltage, or use a " + ...
            "buck-boost, whose duty covers both directions.", ...
            cornerNames(worstCornerIndex), cornerVoltages(worstCornerIndex), ...
            outputVoltage, worstDuty, inputVoltageMax);
    end
end

% The conversion ratio must clear unity by the requested factor at the WORST input, not
% only at the nominal one.
switch topologyFamily
    case "Buck"
        maximumFeasibleOutputVoltage = inputVoltageMin/conversionRatioMargin;
        minimumFeasibleOutputVoltage = 0;
        conversionIsFeasible = outputVoltage <= maximumFeasibleOutputVoltage;
    case "Boost"
        minimumFeasibleOutputVoltage = inputVoltageMax*conversionRatioMargin;
        maximumFeasibleOutputVoltage = Inf;
        conversionIsFeasible = outputVoltage >= minimumFeasibleOutputVoltage;
    otherwise
        % Both directions are reachable, so any output voltage is; only the duty widens.
        minimumFeasibleOutputVoltage = 0;
        maximumFeasibleOutputVoltage = Inf;
        conversionIsFeasible = true;
end

% For a buck-boost, which side of unity the input range sits on decides how wide the duty
% range has to be, so it is reported.
if outputVoltage <= inputVoltageMin
    conversionDirection = "step-down over the whole input range";
elseif outputVoltage >= inputVoltageMax
    conversionDirection = "step-up over the whole input range";
else
    conversionDirection = "crosses unity within the input range";
end

%% ---- Step 1 to 3: operating point, inductance and CCM per input voltage ---

corners = struct("name", {}, "inputVoltage", {}, "duty", {}, ...
    "inductorCurrentAverage", {}, "onTimeVoltSeconds", {}, ...
    "requiredInductance", {}, "outputCurrent", {}, ...
    "requiredCapacitanceForRipple", {});

for cornerIndex = 1:numel(cornerVoltages)
    inputVoltage = cornerVoltages(cornerIndex);
    duty = cornerDuties(cornerIndex);

    % Average inductor current per watt: the output current in a buck, the input
    % current in a boost, both in turn in a buck-boost - which is why a buck-boost is
    % hardest on its magnetics for the same throughput. Step 0 has already guaranteed
    % a duty inside (0, 1), so both come out positive.
    switch topologyFamily
        case "Buck"
            inductorCurrentAverage = ratedPower/outputVoltage;
            % The switch ties Vin to the inductor while the output holds the far end
            % at Vout, so the inductor sees the difference.
            onTimeVoltSeconds = (inputVoltage - outputVoltage)*duty/switchingFrequency;
        case "Boost"
            inductorCurrentAverage = ratedPower/inputVoltage;
            % During the on-time the inductor is across the input.
            onTimeVoltSeconds = inputVoltage*duty/switchingFrequency;
        otherwise
            inductorCurrentAverage = ratedPower/inputVoltage + ...
                ratedPower/outputVoltage;
            onTimeVoltSeconds = inputVoltage*duty/switchingFrequency;
    end

    % Inductance needed to hold the ripple fraction at this input voltage.
    allowedRipple = inductorCurrentRippleFraction*inductorCurrentAverage;
    requiredInductance = onTimeVoltSeconds/allowedRipple;

    % Set by the load, not the input voltage, but carried here so the capacitor sizing
    % below reads from one place.
    outputCurrent = ratedPower/outputVoltage;

    % A buck's inductor feeds the output continuously so the capacitor absorbs only the
    % triangular ripple; a boost or buck-boost feeds it in pulses, so the capacitor
    % carries the whole load current for the on-time.
    allowedOutputRipple = outputVoltageRippleFraction*outputVoltage;
    if topologyFamily == "Buck"
        requiredCapacitanceForRipple = allowedRipple/(8*switchingFrequency*allowedOutputRipple);
    else
        requiredCapacitanceForRipple = outputCurrent*duty/ ...
            (switchingFrequency*allowedOutputRipple);
    end

    corners(cornerIndex).name = cornerNames(cornerIndex);
    corners(cornerIndex).inputVoltage = inputVoltage;
    corners(cornerIndex).duty = duty;
    corners(cornerIndex).inductorCurrentAverage = inductorCurrentAverage;
    corners(cornerIndex).onTimeVoltSeconds = onTimeVoltSeconds;
    corners(cornerIndex).requiredInductance = requiredInductance;
    corners(cornerIndex).outputCurrent = outputCurrent;
    corners(cornerIndex).requiredCapacitanceForRipple = requiredCapacitanceForRipple;
end

% The inductance is the largest requirement over the range.
[inductance, inductanceCornerIndex] = max([corners.requiredInductance]);

% With L fixed, work back through every input voltage for what is realized there.
for cornerIndex = 1:numel(corners)
    ripple = corners(cornerIndex).onTimeVoltSeconds/inductance;
    averageCurrent = corners(cornerIndex).inductorCurrentAverage;
    duty = corners(cornerIndex).duty;

    corners(cornerIndex).inductorCurrentRipple = ripple;
    corners(cornerIndex).realizedRippleFraction = ripple/averageCurrent;
    corners(cornerIndex).peakInductorCurrent = averageCurrent + ripple/2;
    corners(cornerIndex).valleyInductorCurrent = averageCurrent - ripple/2;

    % RMS of a triangular ripple on a DC level, exactly.
    corners(cornerIndex).inductorCurrentRms = sqrt(averageCurrent^2 + ripple^2/12);

    % Sharing the inductor current by duty. The ripple is left out of the RMS integrals:
    % at these ripple fractions it moves the result well under a percent and would
    % obscure the sqrt(d) scaling that sizes the device.
    corners(cornerIndex).mainSwitchCurrentRms = averageCurrent*sqrt(duty);
    corners(cornerIndex).mainSwitchCurrentAvg = averageCurrent*duty;
    corners(cornerIndex).secondDeviceCurrentRms = averageCurrent*sqrt(1 - duty);
    corners(cornerIndex).secondDeviceCurrentAvg = averageCurrent*(1 - duty);

    % How far the average current sits above half the ripple, where the valley reaches zero.
    corners(cornerIndex).ccmMargin = 2*averageCurrent/ripple;
    corners(cornerIndex).ccmPowerThreshold = ratedPower*ripple/(2*averageCurrent);

    % A buck's capacitor sees only the inductor ripple; a boost or buck-boost capacitor
    % carries the load current for the on-time and the inductor current for the rest,
    % which is a far larger RMS.
    if topologyFamily == "Buck"
        corners(cornerIndex).capacitorCurrentRms = ripple/(2*sqrt(3));
        corners(cornerIndex).capacitorCurrentPeakToPeak = ripple;
    else
        corners(cornerIndex).capacitorCurrentRms = ...
            corners(cornerIndex).outputCurrent*sqrt(duty/(1 - duty));
        % It steps from -Iout during the on-time to IL_peak - Iout at turn-off, so the
        % excursion is the peak inductor current - what the ESR turns into output ripple.
        corners(cornerIndex).capacitorCurrentPeakToPeak = ...
            corners(cornerIndex).peakInductorCurrent;
    end
end

% The input voltages that set the two things a designer sizes hardware against.
[~, stressCornerIndex] = max([corners.peakInductorCurrent]);
[minimumCCMMargin, ccmMarginCornerIndex] = min([corners.ccmMargin]);
[maximumCCMPowerThreshold, ccmPowerCornerIndex] = max([corners.ccmPowerThreshold]);
stressCorner = corners(stressCornerIndex);

%% ---- Step 4: output capacitance -------------------------------------------
loadResistance = outputVoltage^2/ratedPower;
outputCurrentRated = ratedPower/outputVoltage;

% Switching-ripple requirement, worst input voltage.
[capacitanceForRipple, rippleCapacitanceCornerIndex] = ...
    max([corners.requiredCapacitanceForRipple]);

% The capacitor alone supplies the step until the voltage loop responds, which takes
% roughly one radian at the crossover frequency.
loadStepCurrent = loadStepFraction*outputCurrentRated;
loadStepVoltageDeviation = loadStepVoltageDeviationFraction*outputVoltage;
capacitanceForLoadStep = loadStepCurrent/ ...
    (loadStepVoltageDeviation*2*pi*voltageLoopCrossoverFrequency);

outputCapacitance = max(capacitanceForRipple, capacitanceForLoadStep);
loadStepSizesCapacitor = capacitanceForLoadStep > capacitanceForRipple;
if loadStepSizesCapacitor
    capacitanceSetByRequirement = "load step";
else
    capacitanceSetByRequirement = "switching ripple";
end

%% ---- Step 5: realized output ripple, including ESR ------------------------
% At the worst input voltage with the capacitance chosen. The two terms peak at
% different instants, so their sum is an upper bound, not what a simulation shows.
if topologyFamily == "Buck"
    outputRippleCapacitive = stressCorner.inductorCurrentRipple/ ...
        (8*outputCapacitance*switchingFrequency);
else
    outputRippleCapacitive = outputCurrentRated*stressCorner.duty/ ...
        (outputCapacitance*switchingFrequency);
end
outputRippleResistive = capacitorESR*stressCorner.capacitorCurrentPeakToPeak;
outputVoltageRipplePeakToPeak = outputRippleCapacitive + outputRippleResistive;
esrDominatesOutputRipple = outputRippleResistive > outputRippleCapacitive;

%% ---- Step 6: device ratings ----------------------------------------------
switch topologyFamily
    case "Buck"
        deviceBlockingVoltage = inputVoltageMax;
    case "Boost"
        deviceBlockingVoltage = outputVoltage;
    otherwise
        % A buck-boost covers both conversion directions, so its device blocks the sum.
        deviceBlockingVoltage = inputVoltageMax + outputVoltage;
end
deviceVoltageRating = deviceVoltageMargin*deviceBlockingVoltage;

%% ---- Collect the design outputs ------------------------------------------
nonIsolatedDCDCDesign = struct();

% Topology.
nonIsolatedDCDCDesign.topology = topologyName;
nonIsolatedDCDCDesign.topologyFamily = topologyFamily;
nonIsolatedDCDCDesign.isSynchronous = isSynchronous;
nonIsolatedDCDCDesign.secondDeviceName = secondDeviceName;

% Feasibility.
nonIsolatedDCDCDesign.conversionIsFeasible = conversionIsFeasible;
nonIsolatedDCDCDesign.conversionDirection = conversionDirection;
nonIsolatedDCDCDesign.minimumFeasibleOutputVoltage = minimumFeasibleOutputVoltage;
nonIsolatedDCDCDesign.maximumFeasibleOutputVoltage = maximumFeasibleOutputVoltage;

% Power stage, the values the plant block mask reads.
nonIsolatedDCDCDesign.inductance = inductance;
nonIsolatedDCDCDesign.inductorESR = inductorESR;
nonIsolatedDCDCDesign.outputCapacitance = outputCapacitance;
nonIsolatedDCDCDesign.capacitorESR = capacitorESR;
nonIsolatedDCDCDesign.initialCapacitorVoltage = initialCapacitorVoltage;
nonIsolatedDCDCDesign.switchingFrequency = switchingFrequency;
nonIsolatedDCDCDesign.inputVoltage = inputVoltageNom;
nonIsolatedDCDCDesign.minInputVoltage = inputVoltageMin;
nonIsolatedDCDCDesign.maxInputVoltage = inputVoltageMax;
nonIsolatedDCDCDesign.outputVoltage = outputVoltage;
nonIsolatedDCDCDesign.ratedPower = ratedPower;
nonIsolatedDCDCDesign.loadResistance = loadResistance;
nonIsolatedDCDCDesign.outputCurrent = outputCurrentRated;

% The nominal input voltage, which the controller is tuned against and the duty
% feedforward reproduces.
nonIsolatedDCDCDesign.nominalDuty = corners(2).duty;
nonIsolatedDCDCDesign.minimumDuty = min([corners.duty]);
nonIsolatedDCDCDesign.maximumDuty = max([corners.duty]);
nonIsolatedDCDCDesign.inductorCurrentAverage = corners(2).inductorCurrentAverage;

% Inductance and conduction mode.
nonIsolatedDCDCDesign.requestedRippleFraction = inductorCurrentRippleFraction;
nonIsolatedDCDCDesign.inductanceSetByInputVoltage = corners(inductanceCornerIndex).name;
nonIsolatedDCDCDesign.realizedRippleFraction = ...
    corners(inductanceCornerIndex).realizedRippleFraction;
nonIsolatedDCDCDesign.rippleSpecMetAtAllInputVoltages = ...
    all([corners.realizedRippleFraction] <= inductorCurrentRippleFraction*(1 + 1e-9));
nonIsolatedDCDCDesign.minimumCCMMargin = minimumCCMMargin;
nonIsolatedDCDCDesign.minimumCCMMarginInputVoltage = corners(ccmMarginCornerIndex).name;
nonIsolatedDCDCDesign.ccmPowerThreshold = maximumCCMPowerThreshold;
nonIsolatedDCDCDesign.ccmPowerThresholdFraction = maximumCCMPowerThreshold/ratedPower;
nonIsolatedDCDCDesign.ccmPowerThresholdInputVoltage = corners(ccmPowerCornerIndex).name;
nonIsolatedDCDCDesign.ccmHoldsAtRatedPower = minimumCCMMargin > 1;

% Capacitance.
nonIsolatedDCDCDesign.capacitanceForRipple = capacitanceForRipple;
nonIsolatedDCDCDesign.capacitanceForLoadStep = capacitanceForLoadStep;
nonIsolatedDCDCDesign.capacitanceSetByRequirement = capacitanceSetByRequirement;
nonIsolatedDCDCDesign.loadStepSizesCapacitor = loadStepSizesCapacitor;
nonIsolatedDCDCDesign.capacitanceRippleInputVoltage = corners(rippleCapacitanceCornerIndex).name;
nonIsolatedDCDCDesign.loadStepCurrent = loadStepCurrent;
nonIsolatedDCDCDesign.loadStepVoltageDeviation = loadStepVoltageDeviation;
nonIsolatedDCDCDesign.voltageLoopCrossoverFrequency = voltageLoopCrossoverFrequency;

% Output ripple.
nonIsolatedDCDCDesign.outputVoltageRipplePeakToPeak = outputVoltageRipplePeakToPeak;
nonIsolatedDCDCDesign.outputVoltageRippleCapacitive = outputRippleCapacitive;
nonIsolatedDCDCDesign.outputVoltageRippleResistive = outputRippleResistive;
nonIsolatedDCDCDesign.esrDominatesOutputRipple = esrDominatesOutputRipple;

% Current rating at the worst input voltage, which is what the hardware is sized to.
nonIsolatedDCDCDesign.ratingSetByInputVoltage = stressCorner.name;
nonIsolatedDCDCDesign.peakInductorCurrent = stressCorner.peakInductorCurrent;
nonIsolatedDCDCDesign.rmsInductorCurrent = stressCorner.inductorCurrentRms;
nonIsolatedDCDCDesign.worstCaseInductorCurrentRipple = stressCorner.inductorCurrentRipple;
nonIsolatedDCDCDesign.mainSwitchCurrentRms = stressCorner.mainSwitchCurrentRms;
nonIsolatedDCDCDesign.mainSwitchCurrentAvg = stressCorner.mainSwitchCurrentAvg;
nonIsolatedDCDCDesign.secondDeviceCurrentRms = stressCorner.secondDeviceCurrentRms;
nonIsolatedDCDCDesign.secondDeviceCurrentAvg = stressCorner.secondDeviceCurrentAvg;
nonIsolatedDCDCDesign.capacitorCurrentRms = stressCorner.capacitorCurrentRms;
nonIsolatedDCDCDesign.deviceBlockingVoltage = deviceBlockingVoltage;
nonIsolatedDCDCDesign.deviceVoltageRating = deviceVoltageRating;
nonIsolatedDCDCDesign.deviceVoltageMargin = deviceVoltageMargin;
nonIsolatedDCDCDesign.conversionRatioMargin = conversionRatioMargin;

nonIsolatedDCDCDesign.operatingPoints = corners;

%% ---- Build display table -------------------------------------------------
% Component values, then the results the design is checked against. Device voltage and
% current ratings belong to selectNonIsolatedDCDCDeviceRating, not here, and the intermediate
% terms behind each value stay on nonIsolatedDCDCDesign.
componentName = { ...
    'Inductance (L)'; ...
    'Inductor resistance (RL)'; ...
    'Output capacitance (C)'; ...
    'Output capacitor ESR (Rco)'; ...
    'Switching frequency (Fsw)'; ...
    'Duty range over input range'; ...
    'Peak inductor current (worst case)'; ...
    'RMS inductor current (worst case)'; ...
    'Realized ripple fraction (worst case)'; ...
    'CCM margin (L/L_CCM, worst case)'; ...
    'CCM power threshold (worst case)'; ...
    'Output ripple, peak-to-peak bound'};
tableValue = [ ...
    inductance*1e6; ...
    inductorESR; ...
    outputCapacitance*1e6; ...
    capacitorESR; ...
    switchingFrequency*1e-3; ...
    nonIsolatedDCDCDesign.maximumDuty - nonIsolatedDCDCDesign.minimumDuty; ...
    nonIsolatedDCDCDesign.peakInductorCurrent; ...
    nonIsolatedDCDCDesign.rmsInductorCurrent; ...
    nonIsolatedDCDCDesign.realizedRippleFraction; ...
    minimumCCMMargin; ...
    maximumCCMPowerThreshold; ...
    outputVoltageRipplePeakToPeak];
tableUnit = {'uH'; 'Ohm'; 'uF'; 'Ohm'; 'kHz'; '-'; 'A'; 'A'; '-'; '-'; 'W'; 'V'};

designTable = table(char(componentName), tableValue, char(tableUnit), ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});

%% ---- Report --------------------------------------------------------------
if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', ...
        sprintf("%s Estimated Design Parameters", topologyName)));

    % The design is achievable - step 0 errors outright if not - but it may sit too close
    % to a duty limit to regulate there, so this comes first.
    if ~conversionIsFeasible
        if topologyFamily == "Buck"
            warning("designNonIsolatedDCDCConverter:BuckMarginShort", ...
                "The conversion ratio margin is not met. The requested output " + ...
                "voltage of %.4g V exceeds the %.4g V that the minimum input " + ...
                "voltage of %.4g V allows with a margin of %.4g, so the duty runs " + ...
                "to %.4g and leaves the modulator little room. The design below is " + ...
                "achievable but will regulate poorly at low input. Lower the output " + ...
                "voltage, raise the minimum input voltage, or use a buck-boost.", ...
                outputVoltage, maximumFeasibleOutputVoltage, inputVoltageMin, ...
                conversionRatioMargin, max(cornerDuties));
        else
            warning("designNonIsolatedDCDCConverter:BoostMarginShort", ...
                "The conversion ratio margin is not met. The requested output " + ...
                "voltage of %.4g V is below the %.4g V that the maximum input " + ...
                "voltage of %.4g V allows with a margin of %.4g, so the duty falls " + ...
                "to %.4g and leaves the modulator little room. The design below is " + ...
                "achievable but will regulate poorly at high input. Raise the output " + ...
                "voltage, lower the maximum input voltage, or use a buck-boost.", ...
                outputVoltage, minimumFeasibleOutputVoltage, inputVoltageMax, ...
                conversionRatioMargin, min(cornerDuties));
        end
    end

    fprintf("\n%s, %s.\n", topologyName, conversionDirection);
    fprintf("  Inductance %.4g uH, set at %s: ripple fraction %.4g requested, " + ...
        "%.4g realized.\n", inductance*1e6, ...
        nonIsolatedDCDCDesign.inductanceSetByInputVoltage, ...
        inductorCurrentRippleFraction, nonIsolatedDCDCDesign.realizedRippleFraction);
    fprintf("  Peak inductor current %.4g A, at %s.\n", ...
        stressCorner.peakInductorCurrent, stressCorner.name);

    fprintf("  Output capacitance %.4g uF set by the %s requirement: " + ...
        "%.4g uF for switching ripple, %.4g uF for a %.0f%% load step " + ...
        "within %.4g V at a %.4g Hz loop crossover.\n", ...
        outputCapacitance*1e6, capacitanceSetByRequirement, ...
        capacitanceForRipple*1e6, capacitanceForLoadStep*1e6, ...
        100*loadStepFraction, loadStepVoltageDeviation, voltageLoopCrossoverFrequency);
    if loadStepSizesCapacitor
        fprintf("    The load step governs by a factor of %.4g.\n", ...
            capacitanceForLoadStep/capacitanceForRipple);
    end

    if esrDominatesOutputRipple
        fprintf("  Output ripple is ESR-dominated: %.4g V from the %.4g Ohm ESR " + ...
            "against %.4g V from the capacitance, %.4g V total bound (%.3g%% of " + ...
            "Vout).\n", ...
            outputRippleResistive, capacitorESR, outputRippleCapacitive, ...
            outputVoltageRipplePeakToPeak, 100*outputVoltageRipplePeakToPeak/outputVoltage);
    end

    if ~nonIsolatedDCDCDesign.ccmHoldsAtRatedPower
        warning("designNonIsolatedDCDCConverter:DCMAtRatedPower", ...
            "Conduction is discontinuous at rated power: the CCM margin at %s is " + ...
            "%.4g, below 1. Reduce the ripple fraction below 2.", ...
            nonIsolatedDCDCDesign.minimumCCMMarginInputVoltage, minimumCCMMargin);
    else
        fprintf("  Continuous conduction above %.4g W (%.3g%% of rated), at %s.\n", ...
            maximumCCMPowerThreshold, ...
            100*nonIsolatedDCDCDesign.ccmPowerThresholdFraction, ...
            nonIsolatedDCDCDesign.ccmPowerThresholdInputVoltage);
    end

    if isSynchronous
        fprintf("  Synchronous: the second device is a controlled switch carrying " + ...
            "%.4g A RMS, with a dead-timed complementary gate.\n", ...
            nonIsolatedDCDCDesign.secondDeviceCurrentRms);
    else
        fprintf("  Single-switch: the second device is a freewheeling diode " + ...
            "carrying %.4g A RMS and %.4g A average.\n", ...
            nonIsolatedDCDCDesign.secondDeviceCurrentRms, ...
            nonIsolatedDCDCDesign.secondDeviceCurrentAvg);
    end

    if topologyFamily == "Boost" && initialCapacitorVoltage < inputVoltageNom
        warning("designNonIsolatedDCDCConverter:BoostStartsBelowInput", ...
            "The initial output capacitor voltage of %.4g V is below the nominal " + ...
            "input voltage of %.4g V. A boost has no control authority there, so " + ...
            "the startup current is an uncontrolled charging transient that neither " + ...
            "the soft start nor the current limit can hold down.", ...
            initialCapacitorVoltage, inputVoltageNom);
    end
end

%% ---- Seal physical quantities as simscape.Value in SI base units ---------
% Everything above works in plain doubles. The mask reads an SI magnitude directly, as
% nonIsolatedDCDCDesign.inductance.value with its unit popup on the matching SI base unit,
% so the seal is what keeps a unit from being assumed. Ratios, duty, margins, flags, names
% and the tables stay plain.
nonIsolatedDCDCDesign.inductance = simscape.Value(nonIsolatedDCDCDesign.inductance, "H");
nonIsolatedDCDCDesign.inductorESR = simscape.Value(nonIsolatedDCDCDesign.inductorESR, "Ohm");
nonIsolatedDCDCDesign.outputCapacitance = simscape.Value(nonIsolatedDCDCDesign.outputCapacitance, "F");
nonIsolatedDCDCDesign.capacitorESR = simscape.Value(nonIsolatedDCDCDesign.capacitorESR, "Ohm");
nonIsolatedDCDCDesign.initialCapacitorVoltage = simscape.Value(nonIsolatedDCDCDesign.initialCapacitorVoltage, "V");
nonIsolatedDCDCDesign.switchingFrequency = simscape.Value(nonIsolatedDCDCDesign.switchingFrequency, "Hz");
nonIsolatedDCDCDesign.inputVoltage = simscape.Value(nonIsolatedDCDCDesign.inputVoltage, "V");
nonIsolatedDCDCDesign.minInputVoltage = simscape.Value(nonIsolatedDCDCDesign.minInputVoltage, "V");
nonIsolatedDCDCDesign.maxInputVoltage = simscape.Value(nonIsolatedDCDCDesign.maxInputVoltage, "V");
nonIsolatedDCDCDesign.outputVoltage = simscape.Value(nonIsolatedDCDCDesign.outputVoltage, "V");
nonIsolatedDCDCDesign.ratedPower = simscape.Value(nonIsolatedDCDCDesign.ratedPower, "W");
nonIsolatedDCDCDesign.loadResistance = simscape.Value(nonIsolatedDCDCDesign.loadResistance, "Ohm");
nonIsolatedDCDCDesign.outputCurrent = simscape.Value(nonIsolatedDCDCDesign.outputCurrent, "A");

nonIsolatedDCDCDesign.minimumFeasibleOutputVoltage = ...
    simscape.Value(nonIsolatedDCDCDesign.minimumFeasibleOutputVoltage, "V");
nonIsolatedDCDCDesign.maximumFeasibleOutputVoltage = ...
    simscape.Value(nonIsolatedDCDCDesign.maximumFeasibleOutputVoltage, "V");

nonIsolatedDCDCDesign.inductorCurrentAverage = simscape.Value(nonIsolatedDCDCDesign.inductorCurrentAverage, "A");
nonIsolatedDCDCDesign.peakInductorCurrent = simscape.Value(nonIsolatedDCDCDesign.peakInductorCurrent, "A");
nonIsolatedDCDCDesign.rmsInductorCurrent = simscape.Value(nonIsolatedDCDCDesign.rmsInductorCurrent, "A");
nonIsolatedDCDCDesign.worstCaseInductorCurrentRipple = ...
    simscape.Value(nonIsolatedDCDCDesign.worstCaseInductorCurrentRipple, "A");

nonIsolatedDCDCDesign.ccmPowerThreshold = simscape.Value(nonIsolatedDCDCDesign.ccmPowerThreshold, "W");
nonIsolatedDCDCDesign.capacitanceForRipple = simscape.Value(nonIsolatedDCDCDesign.capacitanceForRipple, "F");
nonIsolatedDCDCDesign.capacitanceForLoadStep = simscape.Value(nonIsolatedDCDCDesign.capacitanceForLoadStep, "F");
nonIsolatedDCDCDesign.loadStepCurrent = simscape.Value(nonIsolatedDCDCDesign.loadStepCurrent, "A");
nonIsolatedDCDCDesign.loadStepVoltageDeviation = simscape.Value(nonIsolatedDCDCDesign.loadStepVoltageDeviation, "V");
nonIsolatedDCDCDesign.voltageLoopCrossoverFrequency = ...
    simscape.Value(nonIsolatedDCDCDesign.voltageLoopCrossoverFrequency, "Hz");

nonIsolatedDCDCDesign.outputVoltageRipplePeakToPeak = ...
    simscape.Value(nonIsolatedDCDCDesign.outputVoltageRipplePeakToPeak, "V");
nonIsolatedDCDCDesign.outputVoltageRippleCapacitive = ...
    simscape.Value(nonIsolatedDCDCDesign.outputVoltageRippleCapacitive, "V");
nonIsolatedDCDCDesign.outputVoltageRippleResistive = ...
    simscape.Value(nonIsolatedDCDCDesign.outputVoltageRippleResistive, "V");

nonIsolatedDCDCDesign.mainSwitchCurrentRms = simscape.Value(nonIsolatedDCDCDesign.mainSwitchCurrentRms, "A");
nonIsolatedDCDCDesign.mainSwitchCurrentAvg = simscape.Value(nonIsolatedDCDCDesign.mainSwitchCurrentAvg, "A");
nonIsolatedDCDCDesign.secondDeviceCurrentRms = simscape.Value(nonIsolatedDCDCDesign.secondDeviceCurrentRms, "A");
nonIsolatedDCDCDesign.secondDeviceCurrentAvg = simscape.Value(nonIsolatedDCDCDesign.secondDeviceCurrentAvg, "A");
nonIsolatedDCDCDesign.capacitorCurrentRms = simscape.Value(nonIsolatedDCDCDesign.capacitorCurrentRms, "A");
nonIsolatedDCDCDesign.deviceBlockingVoltage = simscape.Value(nonIsolatedDCDCDesign.deviceBlockingVoltage, "V");
nonIsolatedDCDCDesign.deviceVoltageRating = simscape.Value(nonIsolatedDCDCDesign.deviceVoltageRating, "V");

end
