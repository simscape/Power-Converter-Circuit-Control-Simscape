function [controllerTable, nonIsolatedDCDCController] = designNonIsolatedDCDCController( ...
    nonIsolatedDCDCDesign, nonIsolatedDCDCControllerSpec, options)
%DESIGNNONISOLATEDDCDCCONTROLLER Tune the cascaded controller of a non-isolated DC-DC converter.
%
%   [controllerTable, nonIsolatedDCDCController] = designNonIsolatedDCDCController(
%   nonIsolatedDCDCDesign, nonIsolatedDCDCControllerSpec, Name=Value) returns the
%   gains, sample times, limits and modulator settings the controller block mask
%   reads, for all six topologies through one code path. The controller is a cascade:
%   an inner inductor current loop in per-unit follows a reference from an outer
%   output-voltage loop, and both loops are PI with anti-windup. A duty feedforward
%   carries the nominal operating point. Every gain is a closed-form match to a
%   small-signal model of the stage its loop sees.
%
%   Inputs:
%     nonIsolatedDCDCDesign          Design structure from designNonIsolatedDCDCConverter.
%     nonIsolatedDCDCControllerSpec  Controller specification. Every field is optional.
%
%   Controller specification fields:
%     currentLoopBandwidthRatio    Current loop crossover, as a fraction of the
%                                  switching frequency. Default 1/20.
%     currentLoopZeroRatio         Current loop PI zero, as a fraction of that
%                                  crossover. Default 1/10.
%     voltageLoopDampingRatio      Damping ratio asked of the voltage loop. Default 0.8.
%     currentSampleTimeRatio       Current loop sample time, in switching periods.
%                                  Default 1.
%     voltageToCurrentSampleRatio  Voltage samples per current sample. Default 10.
%     currentLimitPu               Upper current reference limit (pu). Default 1.5.
%     currentLimitMinPu            Lower current reference limit (pu). Default 0.
%     softStartTime                Reference ramp duration (s). Default 4e-3.
%     deadTime                     Dead time between complementary gates (s), used by a
%                                  synchronous topology. Default 100e-9.
%     dutyMax                      Upper duty limit. Default 0.95.
%     dutyMin                      Lower duty limit. Default 0.02.
%     modulatorSampleTime          Modulator carrier sample time (s). Default 1e-8.
%     gateVoltageOn                Gate drive on level (V). Default 15.
%     gateVoltageOff               Gate drive off level (V). Default 0.
%
%   Name-value options:
%     DisplayTableFlag  Display the controller table and the design notes. Default true.
%
%   Outputs:
%     controllerTable            Table of the gains, the limits and the achieved response.
%     nonIsolatedDCDCController  Structure the controller block mask reads. Gains,
%                                ratios and per-unit quantities are plain doubles, times,
%                                voltages, currents and frequencies simscape.Value in SI
%                                base units.
%
%   See also designNonIsolatedDCDCConverter, EstimateNonIsolatedDCDCParameters.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCDesign (1,1) struct
    nonIsolatedDCDCControllerSpec (1,1) struct = struct()
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

% ---- Read the power-stage design -------------------------------------------
% A missing field means the caller passed something else: name it rather than
% failing obscurely further down.
requiredDesignFields = [ ...
    "topology", "topologyFamily", "isSynchronous", "inductance", ...
    "outputCapacitance", "inputVoltage", "outputVoltage", "ratedPower", ...
    "loadResistance", "initialCapacitorVoltage", "switchingFrequency", ...
    "voltageLoopCrossoverFrequency", "nominalDuty", ...
    "minimumDuty", "maximumDuty"];
missingDesignFields = requiredDesignFields(~isfield(nonIsolatedDCDCDesign, requiredDesignFields));
if ~isempty(missingDesignFields)
    error("designNonIsolatedDCDCController:MissingDesignField", ...
        "nonIsolatedDCDCDesign is missing required field(s): %s. Pass the " + ...
        "structure returned by designNonIsolatedDCDCConverter.", ...
        strjoin(missingDesignFields, ", "));
end

topologyName = string(nonIsolatedDCDCDesign.topology);
topologyFamily = string(nonIsolatedDCDCDesign.topologyFamily);
isSynchronous = nonIsolatedDCDCDesign.isSynchronous;

inductance = value(nonIsolatedDCDCDesign.inductance, "H");
outputCapacitance = value(nonIsolatedDCDCDesign.outputCapacitance, "F");
inputVoltage = value(nonIsolatedDCDCDesign.inputVoltage, "V");
outputVoltage = value(nonIsolatedDCDCDesign.outputVoltage, "V");
ratedPower = value(nonIsolatedDCDCDesign.ratedPower, "W");
loadResistance = value(nonIsolatedDCDCDesign.loadResistance, "Ohm");
initialCapacitorVoltage = value(nonIsolatedDCDCDesign.initialCapacitorVoltage, "V");
switchingFrequency = value(nonIsolatedDCDCDesign.switchingFrequency, "Hz");
voltageLoopCrossoverFrequency = value(nonIsolatedDCDCDesign.voltageLoopCrossoverFrequency, "Hz");

% ---- Controller specification, with documented defaults --------------------
% Read through a local function so each default appears exactly once.
currentLoopBandwidthRatio = specValue(nonIsolatedDCDCControllerSpec, ...
    "currentLoopBandwidthRatio", 1/20);
currentLoopZeroRatio = specValue(nonIsolatedDCDCControllerSpec, ...
    "currentLoopZeroRatio", 1/10);
voltageLoopDampingRatio = specValue(nonIsolatedDCDCControllerSpec, ...
    "voltageLoopDampingRatio", 0.8);
currentSampleTimeRatio = specValue(nonIsolatedDCDCControllerSpec, ...
    "currentSampleTimeRatio", 1);
voltageToCurrentSampleRatio = specValue(nonIsolatedDCDCControllerSpec, ...
    "voltageToCurrentSampleRatio", 10);
currentLimitPu = specValue(nonIsolatedDCDCControllerSpec, "currentLimitPu", 1.5);
currentLimitMinPu = specValue(nonIsolatedDCDCControllerSpec, "currentLimitMinPu", 0);
softStartTime = specValue(nonIsolatedDCDCControllerSpec, "softStartTime", 4e-3, "s");
deadTime = specValue(nonIsolatedDCDCControllerSpec, "deadTime", 100e-9, "s");
dutyMax = specValue(nonIsolatedDCDCControllerSpec, "dutyMax", 0.95);
dutyMin = specValue(nonIsolatedDCDCControllerSpec, "dutyMin", 0.02);
modulatorSampleTime = specValue(nonIsolatedDCDCControllerSpec, ...
    "modulatorSampleTime", 1e-8, "s");
gateVoltageOn = specValue(nonIsolatedDCDCControllerSpec, "gateVoltageOn", 15, "V");
gateVoltageOff = specValue(nonIsolatedDCDCControllerSpec, "gateVoltageOff", 0, "V");

if currentLoopBandwidthRatio <= 0 || currentLoopZeroRatio <= 0
    error("designNonIsolatedDCDCController:NonPositiveLoopRatio", ...
        "currentLoopBandwidthRatio and currentLoopZeroRatio must be positive.");
end
if voltageLoopDampingRatio <= 0
    error("designNonIsolatedDCDCController:NonPositiveDamping", ...
        "voltageLoopDampingRatio must be positive.");
end
if dutyMin >= dutyMax
    error("designNonIsolatedDCDCController:DutyLimitsCrossed", ...
        "dutyMin (%.4g) must be below dutyMax (%.4g).", dutyMin, dutyMax);
end
if currentLimitMinPu >= currentLimitPu
    error("designNonIsolatedDCDCController:CurrentLimitsCrossed", ...
        "currentLimitMinPu (%.4g) must be below currentLimitPu (%.4g).", ...
        currentLimitMinPu, currentLimitPu);
end

%% ---- Per-unit bases -------------------------------------------------------
% These must match the controller mask's initialization exactly - it recomputes them
% from the three base quantities. The inductor carries the output current in a buck,
% the input current in a boost, and both in a buck-boost.
voltageBaseInput = inputVoltage;
voltageBaseOutput = outputVoltage;
powerBase = ratedPower;

switch topologyFamily
    case "Buck"
        inductorCurrentBase = powerBase/voltageBaseOutput;
    case "Boost"
        inductorCurrentBase = powerBase/voltageBaseInput;
    otherwise
        inductorCurrentBase = powerBase/voltageBaseInput + powerBase/voltageBaseOutput;
end

%% ---- Sample times --------------------------------------------------------
% The current loop runs at the switching rate, the fastest rate at which a duty
% command can take effect. The voltage loop runs slower by an INTEGER factor, so
% every voltage update lands on a current update.
switchingPeriod = 1/switchingFrequency;
currentSampleTime = currentSampleTimeRatio*switchingPeriod;
voltageSampleTime = voltageToCurrentSampleRatio*currentSampleTime;

sampleRatioIsInteger = abs(voltageToCurrentSampleRatio - ...
    round(voltageToCurrentSampleRatio)) < 1e-9;

%% ---- Inner current loop --------------------------------------------------
% Voltage the inductor sees per unit of duty. This is the only place the topology
% enters the inner loop.
switch topologyFamily
    case "Buck"
        dutyToInductorVoltage = inputVoltage;
    case "Boost"
        dutyToInductorVoltage = outputVoltage;
    otherwise
        dutyToInductorVoltage = inputVoltage + outputVoltage;
end

currentLoopCrossoverFrequency = currentLoopBandwidthRatio*switchingFrequency;
currentLoopCrossover = 2*pi*currentLoopCrossoverFrequency;

% Unity loop gain at the crossover, against the pure integrator the per-unit
% plant reduces to.
KpCurrent = currentLoopCrossover*inductance*inductorCurrentBase/dutyToInductorVoltage;

% PI zero placed a fixed fraction of the crossover below it.
currentLoopZeroFrequency = currentLoopZeroRatio*currentLoopCrossoverFrequency;
KiCurrent = KpCurrent*2*pi*currentLoopZeroFrequency;

% Against a pure integrator the PI contributes the whole margin through its zero.
currentLoopPhaseMarginIdeal = atand(1/currentLoopZeroRatio);

% Phase lost to delay: one current sample of computation and transport, plus half a
% switching period of modulator delay.
currentLoopDelay = currentSampleTime + 0.5*switchingPeriod;
currentLoopDelayPhase = rad2deg(currentLoopCrossover*currentLoopDelay);
currentLoopPhaseMargin = currentLoopPhaseMarginIdeal - currentLoopDelayPhase;

% Samples per crossover period. Twenty is the usual floor for a sampled loop.
currentLoopSamplesPerPeriod = 1/(currentSampleTime*currentLoopCrossoverFrequency);

%% ---- Outer voltage loop --------------------------------------------------
% Load-sensitivity exponent m: normalized change in delivered output power with
% output voltage at fixed inductor current. m alone separates
% a current-fed output from a power-fed one.
switch topologyFamily
    case "Buck"
        inductorToOutputPower = outputVoltage;
        loadSensitivityExponent = 1;
    case "Boost"
        inductorToOutputPower = inputVoltage;
        loadSensitivityExponent = 0;
    otherwise
        inductorToOutputPower = inputVoltage*outputVoltage/(inputVoltage + outputVoltage);
        loadSensitivityExponent = inputVoltage/(inputVoltage + outputVoltage);
end

% First-order plant seen by the outer loop, in per-unit of the output voltage base
% per per-unit of inductor current.
voltagePlantPoleFactor = 2 - loadSensitivityExponent;
voltagePlantGain = inductorToOutputPower*loadResistance*inductorCurrentBase/ ...
    (outputVoltage*voltageBaseOutput*voltagePlantPoleFactor);
voltagePlantTimeConstant = loadResistance*outputCapacitance/voltagePlantPoleFactor;
voltagePlantPoleFrequency = 1/(2*pi*voltagePlantTimeConstant);

% Place both closed-loop roots by inverting the second-order match. The natural
% frequency is the DESIGN's voltage-loop crossover, not a separate controller
% specification: that frequency is what sized the output capacitor.
voltageLoopNatural = 2*pi*voltageLoopCrossoverFrequency;
KpVoltage = (2*voltageLoopDampingRatio*voltageLoopNatural*voltagePlantTimeConstant - 1)/ ...
    voltagePlantGain;
KiVoltage = voltageLoopNatural^2*voltagePlantTimeConstant/voltagePlantGain;

% A negative Kp means the requested bandwidth is below the plant pole, where a PI
% cannot place the roots as asked. Drop the term rather than ship a negative gain:
% the loop stays stable and comes out better damped than requested.
voltageLoopBandwidthBelowPlantPole = KpVoltage < 0;
if voltageLoopBandwidthBelowPlantPole
    KpVoltage = 0;
end

% What the final gains achieve, so the table is self-checking rather than a
% restatement of the request.
voltageLoopNaturalAchieved = sqrt(voltagePlantGain*KiVoltage/voltagePlantTimeConstant);
voltageLoopDampingAchieved = (1 + voltagePlantGain*KpVoltage)/ ...
    (2*sqrt(voltagePlantGain*KiVoltage*voltagePlantTimeConstant));

% Second-order settling to within 1%, excluding the soft-start ramp, which runs
% before the loop is asked to do anything.
voltageLoopSettlingTime = 4.6/(voltageLoopDampingAchieved*voltageLoopNaturalAchieved);

% Cascade checks: the outer loop must sit well inside the inner one, and its own
% sample rate must be fast against its bandwidth.
loopSeparationRatio = currentLoopCrossoverFrequency/voltageLoopCrossoverFrequency;
voltageLoopSamplesPerPeriod = 1/(voltageSampleTime*voltageLoopCrossoverFrequency);

%% ---- Current limit, in amps ----------------------------------------------
currentLimit = currentLimitPu*inductorCurrentBase;
currentLimitMin = currentLimitMinPu*inductorCurrentBase;

%% ---- Soft start ----------------------------------------------------------
% Charging the output capacitor draws current on top of the load current. This is
% the shortest ramp for which the total stays inside the current limit.
capacitorChargeEnergyRate = outputCapacitance*outputVoltage* ...
    (outputVoltage - initialCapacitorVoltage);
currentLimitPowerHeadroom = inputVoltage*currentLimit - ratedPower;
if currentLimitPowerHeadroom > 0
    softStartTimeForUnlimitedCharging = capacitorChargeEnergyRate/currentLimitPowerHeadroom;
else
    % The limit cannot even carry the load, so no ramp length avoids limiting.
    softStartTimeForUnlimitedCharging = Inf;
end
softStartReliesOnCurrentLimit = softStartTime < softStartTimeForUnlimitedCharging;

% Where the ramp starts, recomputed the same way in the mask. A boost precharges its
% output to the input through the high-side body diode; the others start at zero.
if topologyFamily == "Boost"
    referenceStartPu = voltageBaseInput/voltageBaseOutput;
else
    referenceStartPu = 0;
end
referenceSlewRatePu = (1 - referenceStartPu)/max(softStartTime, eps);

% A boost starting below the input has an uncontrolled charging transient that no
% controller setting reaches.
boostStartsBelowInput = topologyFamily == "Boost" && ...
    initialCapacitorVoltage < inputVoltage;

%% ---- Modulator ----------------------------------------------------------
% Dead time only exists where there is a second switch to hand over to.
effectiveDeadTime = deadTime*isSynchronous;
deadTimeFractionOfPeriod = effectiveDeadTime/switchingPeriod;

% Duty headroom either side of the range the input voltage range demands.
dutyHeadroomUpper = dutyMax - nonIsolatedDCDCDesign.maximumDuty;
dutyHeadroomLower = nonIsolatedDCDCDesign.minimumDuty - dutyMin;
dutyLimitsBracketRange = dutyHeadroomUpper > 0 && dutyHeadroomLower > 0;

%% ---- Collect the controller outputs -------------------------------------
nonIsolatedDCDCController = struct();

nonIsolatedDCDCController.topology = topologyName;
nonIsolatedDCDCController.topologyFamily = topologyFamily;
nonIsolatedDCDCController.isSynchronous = isSynchronous;

% Per-unit bases, which the mask reads directly.
nonIsolatedDCDCController.VbaseIn = voltageBaseInput;
nonIsolatedDCDCController.VbaseOut = voltageBaseOutput;
nonIsolatedDCDCController.Pbase = powerBase;
nonIsolatedDCDCController.IbaseL = inductorCurrentBase;

% Voltage loop.
nonIsolatedDCDCController.KpVoltage = KpVoltage;
nonIsolatedDCDCController.KiVoltage = KiVoltage;
nonIsolatedDCDCController.TsVoltage = voltageSampleTime;
nonIsolatedDCDCController.iRefMaxPu = currentLimitPu;
nonIsolatedDCDCController.iRefMinPu = currentLimitMinPu;
nonIsolatedDCDCController.softStartTime = softStartTime;

% Current loop.
nonIsolatedDCDCController.KpCurrent = KpCurrent;
nonIsolatedDCDCController.KiCurrent = KiCurrent;
nonIsolatedDCDCController.TsCurrent = currentSampleTime;

% Modulator and gate drive.
nonIsolatedDCDCController.Fsw = switchingFrequency;
nonIsolatedDCDCController.Tdead = deadTime;
nonIsolatedDCDCController.dutyMax = dutyMax;
nonIsolatedDCDCController.dutyMin = dutyMin;
nonIsolatedDCDCController.Ts = modulatorSampleTime;
nonIsolatedDCDCController.gateVoltageOn = gateVoltageOn;
nonIsolatedDCDCController.gateVoltageOff = gateVoltageOff;

% Reporting: the loop models, and what the gains achieve.
nonIsolatedDCDCController.dutyToInductorVoltage = dutyToInductorVoltage;
nonIsolatedDCDCController.currentLoopCrossoverFrequency = currentLoopCrossoverFrequency;
nonIsolatedDCDCController.currentLoopZeroFrequency = currentLoopZeroFrequency;
nonIsolatedDCDCController.currentLoopPhaseMarginIdeal = currentLoopPhaseMarginIdeal;
nonIsolatedDCDCController.currentLoopDelayPhase = currentLoopDelayPhase;
nonIsolatedDCDCController.currentLoopPhaseMargin = currentLoopPhaseMargin;
nonIsolatedDCDCController.currentLoopSamplesPerPeriod = currentLoopSamplesPerPeriod;

nonIsolatedDCDCController.loadSensitivityExponent = loadSensitivityExponent;
nonIsolatedDCDCController.voltagePlantGain = voltagePlantGain;
nonIsolatedDCDCController.voltagePlantTimeConstant = voltagePlantTimeConstant;
nonIsolatedDCDCController.voltagePlantPoleFrequency = voltagePlantPoleFrequency;
nonIsolatedDCDCController.voltageLoopCrossoverFrequency = voltageLoopCrossoverFrequency;
nonIsolatedDCDCController.voltageLoopDampingRatio = voltageLoopDampingRatio;
nonIsolatedDCDCController.voltageLoopNaturalAchieved = voltageLoopNaturalAchieved/(2*pi);
nonIsolatedDCDCController.voltageLoopDampingAchieved = voltageLoopDampingAchieved;
nonIsolatedDCDCController.voltageLoopSettlingTime = voltageLoopSettlingTime;
nonIsolatedDCDCController.voltageLoopBandwidthBelowPlantPole = voltageLoopBandwidthBelowPlantPole;
nonIsolatedDCDCController.loopSeparationRatio = loopSeparationRatio;
nonIsolatedDCDCController.voltageLoopSamplesPerPeriod = voltageLoopSamplesPerPeriod;
nonIsolatedDCDCController.sampleRatioIsInteger = sampleRatioIsInteger;

nonIsolatedDCDCController.currentLimit = currentLimit;
nonIsolatedDCDCController.currentLimitMin = currentLimitMin;
nonIsolatedDCDCController.softStartTimeForUnlimitedCharging = softStartTimeForUnlimitedCharging;
nonIsolatedDCDCController.softStartReliesOnCurrentLimit = softStartReliesOnCurrentLimit;
nonIsolatedDCDCController.referenceStartPu = referenceStartPu;
nonIsolatedDCDCController.referenceSlewRatePu = referenceSlewRatePu;
nonIsolatedDCDCController.boostStartsBelowInput = boostStartsBelowInput;

nonIsolatedDCDCController.effectiveDeadTime = effectiveDeadTime;
nonIsolatedDCDCController.deadTimeFractionOfPeriod = deadTimeFractionOfPeriod;
nonIsolatedDCDCController.dutyHeadroomUpper = dutyHeadroomUpper;
nonIsolatedDCDCController.dutyHeadroomLower = dutyHeadroomLower;
nonIsolatedDCDCController.dutyLimitsBracketRange = dutyLimitsBracketRange;

%% ---- Build display table ------------------------------------------------
% Ordered as the mask dialog is: voltage loop, current loop, modulator, bases.
parameterName = { ...
    'Voltage loop Kp (KpVoltage)'; ...
    'Voltage loop Ki (KiVoltage)'; ...
    'Voltage loop sample time (TsVoltage)'; ...
    'Voltage loop crossover (requested)'; ...
    'Voltage loop natural frequency (achieved)'; ...
    'Voltage loop damping ratio (achieved)'; ...
    'Voltage loop settling to 1% (no soft start)'; ...
    'Output plant DC gain (per-unit)'; ...
    'Output plant pole frequency'; ...
    'Load sensitivity exponent m'; ...
    'Current reference upper limit (iRefMaxPu)'; ...
    'Current reference lower limit (iRefMinPu)'; ...
    'Current reference upper limit, in amps'; ...
    'Soft-start time'; ...
    'Soft-start time for unlimited charging'; ...
    'Current loop Kp (KpCurrent)'; ...
    'Current loop Ki (KiCurrent)'; ...
    'Current loop sample time (TsCurrent)'; ...
    'Current loop crossover'; ...
    'Current loop PI zero'; ...
    'Current loop phase margin (ideal)'; ...
    'Current loop phase lost to delay'; ...
    'Current loop phase margin (with delay)'; ...
    'Duty-to-inductor-voltage gain'; ...
    'Loop separation (current / voltage)'; ...
    'Switching frequency (Fsw)'; ...
    'Dead time (Tdead)'; ...
    'Dead time as fraction of period'; ...
    'Maximum duty (dutyMax)'; ...
    'Minimum duty (dutyMin)'; ...
    'Duty headroom above operating range'; ...
    'Duty headroom below operating range'; ...
    'Modulator sample time (Ts)'; ...
    'Gate drive on voltage'; ...
    'Gate drive off voltage'; ...
    'Input voltage base (VbaseIn)'; ...
    'Output voltage base (VbaseOut)'; ...
    'Power base (Pbase)'; ...
    'Inductor current base (IbaseL)'};
parameterValue = [ ...
    KpVoltage; ...
    KiVoltage; ...
    voltageSampleTime*1e6; ...
    voltageLoopCrossoverFrequency; ...
    voltageLoopNaturalAchieved/(2*pi); ...
    voltageLoopDampingAchieved; ...
    voltageLoopSettlingTime*1e3; ...
    voltagePlantGain; ...
    voltagePlantPoleFrequency; ...
    loadSensitivityExponent; ...
    currentLimitPu; ...
    currentLimitMinPu; ...
    currentLimit; ...
    softStartTime*1e3; ...
    softStartTimeForUnlimitedCharging*1e3; ...
    KpCurrent; ...
    KiCurrent; ...
    currentSampleTime*1e6; ...
    currentLoopCrossoverFrequency; ...
    currentLoopZeroFrequency; ...
    currentLoopPhaseMarginIdeal; ...
    currentLoopDelayPhase; ...
    currentLoopPhaseMargin; ...
    dutyToInductorVoltage; ...
    loopSeparationRatio; ...
    switchingFrequency*1e-3; ...
    effectiveDeadTime*1e9; ...
    deadTimeFractionOfPeriod; ...
    dutyMax; ...
    dutyMin; ...
    dutyHeadroomUpper; ...
    dutyHeadroomLower; ...
    modulatorSampleTime*1e9; ...
    gateVoltageOn; ...
    gateVoltageOff; ...
    voltageBaseInput; ...
    voltageBaseOutput; ...
    powerBase; ...
    inductorCurrentBase];
parameterUnit = {'-'; '-'; 'us'; 'Hz'; 'Hz'; '-'; 'ms'; '-'; 'Hz'; '-'; ...
    'pu'; 'pu'; 'A'; 'ms'; 'ms'; ...
    '-'; '-'; 'us'; 'Hz'; 'Hz'; 'deg'; 'deg'; 'deg'; 'V'; '-'; ...
    'kHz'; 'ns'; '-'; '-'; '-'; '-'; '-'; 'ns'; 'V'; 'V'; ...
    'V'; 'V'; 'W'; 'A'};

controllerTable = table(char(parameterName), parameterValue, char(parameterUnit), ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});

%% ---- Report ------------------------------------------------------------
if options.DisplayTableFlag
    disp(table(controllerTable, 'VariableNames', ...
        sprintf("%s Controller Design", topologyName)));

    fprintf("\n%s cascaded controller.\n", topologyName);

    % The inner loop first: the outer one is designed assuming it is closed.
    fprintf("  Current loop crosses at %.4g Hz, one %.4g of the switching " + ...
        "frequency. The per-unit plant is a pure integrator, so the ideal phase " + ...
        "margin is %.3g deg from the zero placement alone; sampling and the " + ...
        "modulator take %.3g deg of that, leaving %.3g deg.\n", ...
        currentLoopCrossoverFrequency, 1/currentLoopBandwidthRatio, ...
        currentLoopPhaseMarginIdeal, currentLoopDelayPhase, currentLoopPhaseMargin);
    if currentLoopPhaseMargin < 45
        warning("designNonIsolatedDCDCController:CurrentLoopMarginLow", ...
            "The current loop phase margin after delay is %.3g deg, below 45. " + ...
            "The %.4g deg lost to delay grows in proportion to the crossover, so " + ...
            "reduce currentLoopBandwidthRatio from %.4g.", ...
            currentLoopPhaseMargin, currentLoopDelayPhase, currentLoopBandwidthRatio);
    end
    if currentLoopSamplesPerPeriod < 20
        warning("designNonIsolatedDCDCController:CurrentLoopUndersampled", ...
            "The current loop gets only %.3g samples per crossover period, below " + ...
            "the usual floor of 20. Reduce currentSampleTimeRatio from %.4g or " + ...
            "lower the crossover.", currentLoopSamplesPerPeriod, currentSampleTimeRatio);
    end

    % The outer loop, and what m means for this topology.
    fprintf("  Output plant: DC gain %.4g pu, pole at %.4g Hz, from m = %.4g.\n", ...
        voltagePlantGain, voltagePlantPoleFrequency, loadSensitivityExponent);
    switch topologyFamily
        case "Buck"
            fprintf("    m = 1: the inductor IS the output current, so the stage is " + ...
                "a current source into the load and the pole sits at 1/(R*C).\n");
        case "Boost"
            fprintf("    m = 0: throughput is set by the input alone, so the stage " + ...
                "is a power source and the pole sits at 2/(R*C) - twice as fast as " + ...
                "a buck's, with half the DC gain.\n");
        otherwise
            fprintf("    m = %.4g, between a buck's 1 and a boost's 0, so the pole " + ...
                "sits at %.4g/(R*C).\n", loadSensitivityExponent, voltagePlantPoleFactor);
    end

    if voltageLoopBandwidthBelowPlantPole
        warning("designNonIsolatedDCDCController:VoltageLoopBelowPlantPole", ...
            "The requested voltage loop crossover of %.4g Hz is below what a PI can " + ...
            "place against a plant pole at %.4g Hz with damping %.4g, which needs at " + ...
            "least %.4g Hz. The proportional term has been dropped to zero rather " + ...
            "than left negative: the loop is stable but comes out damped %.4g " + ...
            "instead of %.4g. Raise the crossover or the output capacitance.", ...
            voltageLoopCrossoverFrequency, voltagePlantPoleFrequency, ...
            voltageLoopDampingRatio, ...
            1/(2*pi*2*voltageLoopDampingRatio*voltagePlantTimeConstant), ...
            voltageLoopDampingAchieved, voltageLoopDampingRatio);
    else
        fprintf("  Voltage loop places both roots at %.4g Hz with damping %.4g, " + ...
            "settling inside 1%% in %.4g ms once the soft start has finished.\n", ...
            voltageLoopNaturalAchieved/(2*pi), voltageLoopDampingAchieved, ...
            voltageLoopSettlingTime*1e3);
    end

    fprintf("  Loop separation %.4g, and %.4g voltage samples per closed-loop " + ...
        "period.\n", loopSeparationRatio, voltageLoopSamplesPerPeriod);
    if loopSeparationRatio < 5
        warning("designNonIsolatedDCDCController:LoopsNotSeparated", ...
            "The current loop crosses only %.4g times above the voltage loop. The " + ...
            "outer loop is designed assuming the inner one is already settled, " + ...
            "which needs a factor of at least 5.", loopSeparationRatio);
    end
    if voltageLoopSamplesPerPeriod < 20
        warning("designNonIsolatedDCDCController:VoltageLoopUndersampled", ...
            "The voltage loop gets only %.4g samples per closed-loop period, below " + ...
            "the usual floor of 20. Reduce voltageToCurrentSampleRatio from %.4g.", ...
            voltageLoopSamplesPerPeriod, voltageToCurrentSampleRatio);
    end
    if ~sampleRatioIsInteger
        warning("designNonIsolatedDCDCController:SampleRatioNotInteger", ...
            "voltageToCurrentSampleRatio is %.4g, not an integer, so voltage " + ...
            "updates will not land on current updates and the cascade will beat " + ...
            "against itself.", voltageToCurrentSampleRatio);
    end

    % Soft start, and which of the two regimes the shipped ramp is in.
    fprintf("  Current limit %.4g pu = %.4g A. Charging the %.4g uF output " + ...
        "capacitor from %.4g V to %.4g V within that limit alone would take " + ...
        "%.4g ms.\n", currentLimitPu, currentLimit, outputCapacitance*1e6, ...
        initialCapacitorVoltage, outputVoltage, softStartTimeForUnlimitedCharging*1e3);
    if softStartReliesOnCurrentLimit
        fprintf("    The %.4g ms soft start is shorter than that, so the current " + ...
            "limit shapes the charging profile. That is what the limit is for; the " + ...
            "ramp's job here is to remove the initial inrush, not to do the " + ...
            "charging.\n", softStartTime*1e3);
    else
        fprintf("    The %.4g ms soft start is longer than that, so the ramp alone " + ...
            "shapes the charging and the current limit stays inactive.\n", ...
            softStartTime*1e3);
    end

    if boostStartsBelowInput
        warning("designNonIsolatedDCDCController:BoostStartsBelowInput", ...
            "The output capacitor starts at %.4g V, below the %.4g V input. A boost " + ...
            "has no control authority there - the inductor sees a positive " + ...
            "volt-second product in both subintervals - so the startup current is " + ...
            "set by an uncontrolled charging transient and no soft-start time or " + ...
            "current limit reaches it. Set the power stage's initial capacitor " + ...
            "voltage to the input voltage.", initialCapacitorVoltage, inputVoltage);
    end

    % Modulator.
    if isSynchronous
        fprintf("  Dead time %.4g ns, %.3g%% of the switching period, on the " + ...
            "complementary gate pair.\n", effectiveDeadTime*1e9, ...
            100*deadTimeFractionOfPeriod);
        if deadTimeFractionOfPeriod > 0.05
            warning("designNonIsolatedDCDCController:DeadTimeLarge", ...
                "The dead time is %.3g%% of the switching period, above 5%%. It " + ...
                "costs that much of the duty range and forces body-diode " + ...
                "conduction for the same fraction of every cycle.", ...
                100*deadTimeFractionOfPeriod);
        end
    else
        fprintf("  Single-switch topology, so no dead time is applied: there is no " + ...
            "second gate to hand over to.\n");
    end

    if ~dutyLimitsBracketRange
        warning("designNonIsolatedDCDCController:DutyLimitsTooTight", ...
            "The duty limits [%.4g, %.4g] do not bracket the %.4g to %.4g range " + ...
            "the input voltage range demands, so the converter cannot regulate at " + ...
            "every input voltage. Headroom is %.4g above and %.4g below.", ...
            dutyMin, dutyMax, nonIsolatedDCDCDesign.minimumDuty, ...
            nonIsolatedDCDCDesign.maximumDuty, dutyHeadroomUpper, dutyHeadroomLower);
    end
end

%% ---- Seal physical quantities as simscape.Value in SI base units --------
% Gains, per-unit limits, duty limits and ratios are dimensionless by construction
% and stay plain. The mask reads an SI magnitude directly, as
% nonIsolatedDCDCController.TsVoltage.value with its unit popup on the matching SI
% base unit, so the seal is what keeps a unit from being assumed.
nonIsolatedDCDCController.VbaseIn = simscape.Value(nonIsolatedDCDCController.VbaseIn, "V");
nonIsolatedDCDCController.VbaseOut = simscape.Value(nonIsolatedDCDCController.VbaseOut, "V");
nonIsolatedDCDCController.Pbase = simscape.Value(nonIsolatedDCDCController.Pbase, "W");
nonIsolatedDCDCController.IbaseL = simscape.Value(nonIsolatedDCDCController.IbaseL, "A");

nonIsolatedDCDCController.TsVoltage = simscape.Value(nonIsolatedDCDCController.TsVoltage, "s");
nonIsolatedDCDCController.TsCurrent = simscape.Value(nonIsolatedDCDCController.TsCurrent, "s");
nonIsolatedDCDCController.softStartTime = simscape.Value(nonIsolatedDCDCController.softStartTime, "s");
nonIsolatedDCDCController.Tdead = simscape.Value(nonIsolatedDCDCController.Tdead, "s");
nonIsolatedDCDCController.Ts = simscape.Value(nonIsolatedDCDCController.Ts, "s");
nonIsolatedDCDCController.Fsw = simscape.Value(nonIsolatedDCDCController.Fsw, "Hz");
nonIsolatedDCDCController.gateVoltageOn = simscape.Value(nonIsolatedDCDCController.gateVoltageOn, "V");
nonIsolatedDCDCController.gateVoltageOff = simscape.Value(nonIsolatedDCDCController.gateVoltageOff, "V");

nonIsolatedDCDCController.dutyToInductorVoltage = simscape.Value(nonIsolatedDCDCController.dutyToInductorVoltage, "V");
nonIsolatedDCDCController.currentLimit = simscape.Value(nonIsolatedDCDCController.currentLimit, "A");
nonIsolatedDCDCController.currentLimitMin = simscape.Value(nonIsolatedDCDCController.currentLimitMin, "A");
nonIsolatedDCDCController.effectiveDeadTime = simscape.Value(nonIsolatedDCDCController.effectiveDeadTime, "s");
nonIsolatedDCDCController.voltageLoopSettlingTime = ...
    simscape.Value(nonIsolatedDCDCController.voltageLoopSettlingTime, "s");
nonIsolatedDCDCController.softStartTimeForUnlimitedCharging = ...
    simscape.Value(nonIsolatedDCDCController.softStartTimeForUnlimitedCharging, "s");

nonIsolatedDCDCController.currentLoopCrossoverFrequency = ...
    simscape.Value(nonIsolatedDCDCController.currentLoopCrossoverFrequency, "Hz");
nonIsolatedDCDCController.currentLoopZeroFrequency = ...
    simscape.Value(nonIsolatedDCDCController.currentLoopZeroFrequency, "Hz");
nonIsolatedDCDCController.voltagePlantPoleFrequency = ...
    simscape.Value(nonIsolatedDCDCController.voltagePlantPoleFrequency, "Hz");
nonIsolatedDCDCController.voltageLoopCrossoverFrequency = ...
    simscape.Value(nonIsolatedDCDCController.voltageLoopCrossoverFrequency, "Hz");
nonIsolatedDCDCController.voltageLoopNaturalAchieved = ...
    simscape.Value(nonIsolatedDCDCController.voltageLoopNaturalAchieved, "Hz");
nonIsolatedDCDCController.voltagePlantTimeConstant = ...
    simscape.Value(nonIsolatedDCDCController.voltagePlantTimeConstant, "s");

end

% ---------------------------------------------------------------------------
function resolvedValue = specValue(specStruct, fieldName, defaultValue, unitName)
%SPECVALUE Read an optional specification field, unwrapping simscape.Value.
%   A caller may write either a plain double or a simscape.Value for any field that
%   has a unit, and each default lives in exactly one place.
if ~isfield(specStruct, fieldName)
    resolvedValue = defaultValue;
    return
end
resolvedValue = specStruct.(fieldName);
if isa(resolvedValue, "simscape.Value")
    if nargin < 4
        error("designNonIsolatedDCDCController:UnexpectedUnit", ...
            "Field ""%s"" is dimensionless, so pass a plain number rather than a " + ...
            "simscape.Value.", fieldName);
    end
    resolvedValue = value(resolvedValue, unitName);
end
end
