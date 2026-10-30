function marginFactor = cllcZVSDeadTimeMarginFactor
%   This function returns the safety margin applied to the theoretical dead time
%   required for zero-voltage switching in a CLLC resonant converter.
%
%   The theoretical dead time that lets the peak magnetizing current move the charge on
%   the device output capacitances of one bridge leg pair is 8*Cparasitic*Lm*max(fr,fsMax),
%   where Cparasitic is the charge-equivalent capacitance Qoss/Vds of one switch. The design
%   adds a margin on top of that so that component tolerance and temperature drift do not
%   take the converter out of soft switching.
%
%   This value is shared by designCLLCFullBridgeConverter, which sizes the dead time
%   from a chosen Lm, and computeCLLCMagnetizingCurrentLimit, which inverts the same
%   relation to bound Lm from the allowed dead-time window.
%   estimateCLLCMaximumMagnetizingInductance holds the
%   derivation and checks a finished design against the same relation.
%
%   Output:
%     marginFactor   Dimensionless dead-time margin (1.2, that is, 20 % margin).
%
%   Example:
%     deadTime = cllcZVSDeadTimeMarginFactor * 8 * Cparasitic * Lm * maxSwitchingFrequency;

% Copyright 2025-2026 The MathWorks, Inc.

marginFactor = 1.2;

end
