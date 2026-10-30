function operatingPoint = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, ...
    inputVoltage, outputPower)
%NONISOLATEDDCDCOPERATINGPOINT CCM operating point of a non-isolated DC-DC converter.
%
%   operatingPoint = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, inputVoltage,
%   outputPower) evaluates the continuous-conduction-mode operating point of a buck,
%   boost or buck-boost converter at an arbitrary input voltage and output power. It uses
%   the inductance and switching frequency the design already fixed. The peak-to-peak
%   inductor ripple carries no load term, while the average inductor current is
%   proportional to the load.
%
%   Inputs:
%     nonIsolatedDCDCDesign  Design structure with the fields topologyFamily,
%                            inductance, switchingFrequency and outputVoltage.
%     inputVoltage           Input voltage, scalar or vector (V).
%     outputPower            Output power, scalar or the size of inputVoltage (W).
%
%   Outputs:
%     operatingPoint  Structure of plain doubles in SI base units:
%       duty                    CCM duty cycle.
%       inductorCurrentAverage  Average inductor current (A).
%       inductorCurrentRipple   Peak-to-peak inductor current ripple (A).
%       realizedRippleFraction  Ripple over average current.
%       peakInductorCurrent     Peak inductor current, which sizes the core and the
%                               devices (A).
%       valleyInductorCurrent   Valley inductor current (A), negative in DCM or under
%                               synchronous reverse conduction.
%       ccmPowerThreshold       Power below which conduction goes discontinuous at this
%                               input voltage (W).
%
%   See also designNonIsolatedDCDCConverter, plotNonIsolatedDCDCCCMBoundary,
%   plotNonIsolatedDCDCInductorCurrentRipple.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCDesign struct
    inputVoltage (1,:) double {mustBePositive}
    outputPower double {mustBePositive}
end

% The design stores physical quantities as simscape.Value in SI base units.
topologyFamily     = nonIsolatedDCDCDesign.topologyFamily;
inductance         = value(nonIsolatedDCDCDesign.inductance, "H");
switchingFrequency = value(nonIsolatedDCDCDesign.switchingFrequency, "Hz");
outputVoltage      = value(nonIsolatedDCDCDesign.outputVoltage, "V");

% Duty from the CCM volt-second balance, the on-time volt-second product the ripple comes
% from, and the average inductor current per watt. The last one carries the topology: a
% buck's inductor is on the output side, a boost's on the input side, a buck-boost's on
% both in turn.
switch topologyFamily
    case "Buck"
        duty = outputVoltage./inputVoltage;
        % The switch ties Vin to the inductor while the output holds the far end at
        % Vout, so the inductor sees the difference.
        onTimeVoltSeconds = (inputVoltage - outputVoltage).*duty/switchingFrequency;
        averageCurrentPerWatt = ones(size(inputVoltage))/outputVoltage;
    case "Boost"
        duty = 1 - inputVoltage/outputVoltage;
        % During the on-time the inductor is across the input.
        onTimeVoltSeconds = inputVoltage.*duty/switchingFrequency;
        averageCurrentPerWatt = 1./inputVoltage;
    otherwise
        duty = outputVoltage./(inputVoltage + outputVoltage);
        onTimeVoltSeconds = inputVoltage.*duty/switchingFrequency;
        averageCurrentPerWatt = 1./inputVoltage + 1/outputVoltage;
end

operatingPoint.duty = duty;
operatingPoint.inductorCurrentRipple = onTimeVoltSeconds/inductance;
operatingPoint.inductorCurrentAverage = outputPower.*averageCurrentPerWatt;
operatingPoint.realizedRippleFraction = ...
    operatingPoint.inductorCurrentRipple./operatingPoint.inductorCurrentAverage;
operatingPoint.peakInductorCurrent = operatingPoint.inductorCurrentAverage + ...
    operatingPoint.inductorCurrentRipple/2;
operatingPoint.valleyInductorCurrent = operatingPoint.inductorCurrentAverage - ...
    operatingPoint.inductorCurrentRipple/2;

% The valley reaches zero when the average equals half the ripple. The average is
% proportional to power and the ripple is not, so that inverts in one step.
operatingPoint.ccmPowerThreshold = ...
    operatingPoint.inductorCurrentRipple./(2*averageCurrentPerWatt);
end
