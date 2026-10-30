function magL = estimateCLLCMaximumMagnetizingInductance(CLLCDesign,options)
%   This function estimates the maximum magnetizing inductance (Lm) that keeps a CLLC
%   resonant converter zero-voltage switching at a given switching frequency. Select an Lm
%   at or below the estimated maximum.
%
%   Zero-voltage switching requires two conditions at the same time:
%
%     Charge - the peak magnetizing current must move the charge stored on the device output
%     capacitances of one bridge leg pair within the dead time. The transformer voltage is
%     clamped for half a resonant period at or below resonance and for half a switching
%     period above it, so with fclamp = max(fr,fs) the peak current is Vin/(4*Lm*fclamp) and
%     the charge to move is 2*Cparasitic*Vin. The input voltage cancels, which leaves
%
%         Tdead >= 8*Cparasitic*Lm*fclamp        Lm <= Tdead/(8*Cparasitic*fclamp)
%
%     Phase - the tank must be inductive at the switching frequency, which requires
%     fs > fr2, the no-load lower resonance set by Lm.
%
%   Inputs:
%     CLLCDesign   Struct with CLLC design parameters:
%                   - Lm: Magnetizing inductance (H)
%                   - L1: Primary series resonant inductance (H)
%                   - C1: Primary resonant capacitance (F)
%                   - Cparasitic: Device output capacitance of one switch, entered as the
%                                 charge-equivalent value Qoss/Vds (F)
%                   - resonantFreq: Resonant frequency (simscape.Value or numeric, Hz)
%                   - deadTime: Dead time (s)
%
%     options     Name-value structure with fields:
%                   - SwitchingFrequency: Switching frequency (simscape.Value or numeric, Hz)
%                                         (default: resonantFreq)
%                   - DisplayTableFlag:   true/false to display summary table (default: true)
%
%   Output:
%     magL        Struct with fields:
%                   - maximumLm:          Maximum Lm for zero-voltage switching (H)
%                   - selectedLm:         Lm in CLLCDesign (H)
%                   - marginRatio:        maximumLm/selectedLm, 1 or more to soft switch (-)
%                   - requiredDeadTime:   Dead time the selected Lm needs (s)
%                   - availableDeadTime:  Dead time in CLLCDesign (s)
%                   - switchingFrequency: Switching frequency used (Hz)
%                   - clampFrequency:     max(fr,fs), which sets the peak current (Hz)
%                   - inductanceRatio:    Lm/L1 (-)
%                   - fr2:                Lower (no-load) resonant frequency set by Lm (Hz)
%                   - isInductive:        true when fs > fr2
%                   - isSoftSwitching:    true when both conditions hold
%
%   Method:
%     - Applies the charge condition at fclamp = max(fr,fs) to bound Lm.
%     - Applies the phase condition fs > fr2.
%     - Reports the verdict in magL.isSoftSwitching, warns when either condition fails, and
%       optionally displays a summary table.
%
%   Example:
%     CLLCDesign.Lm = 120e-6;
%     CLLCDesign.L1 = 40e-6;
%     CLLCDesign.C1 = 100e-9;
%     CLLCDesign.Cparasitic = 10e-12;
%     CLLCDesign.resonantFreq = simscape.Value(100e3,"Hz");
%     CLLCDesign.deadTime = 200e-9;
%     magL = estimateCLLCMaximumMagnetizingInductance(CLLCDesign, ...
%         SwitchingFrequency = simscape.Value(60e3,"Hz"), DisplayTableFlag = true);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    CLLCDesign struct
    % Empty means the resonant frequency, which CLLCDesign.resonantFreq supplies below. The
    % default cannot be written here because resonantFreq is a simscape.Value in some
    % callers and a plain double in others.
    options.SwitchingFrequency = []; % Switching frequency
    options.DisplayTableFlag = true; % Display summary table
end

Fr = frequencyInHz(CLLCDesign.resonantFreq);
if isempty(options.SwitchingFrequency)
    Fs = Fr;
else
    Fs = frequencyInHz(options.SwitchingFrequency);
end
if Fs <= 0 || Fr <= 0 || CLLCDesign.Cparasitic <= 0 || CLLCDesign.deadTime <= 0
    error("estimateCLLCMaximumMagnetizingInductance:NonPositiveInput", ...
        "The switching frequency, resonant frequency, Cparasitic and deadTime must all be positive.");
end

% The magnetizing current ramps while the transformer voltage is clamped, which lasts half a
% resonant period at or below resonance and half a switching period above it. The shorter
% ramp gives the smaller peak current, so the higher of the two frequencies is the worst case
% for zero-voltage switching.
clampFrequency = max(Fr, Fs);

magL.maximumLm = CLLCDesign.deadTime/(8*CLLCDesign.Cparasitic*clampFrequency);
magL.selectedLm = CLLCDesign.Lm;
magL.marginRatio = magL.maximumLm/magL.selectedLm;
magL.requiredDeadTime = 8*CLLCDesign.Cparasitic*CLLCDesign.Lm*clampFrequency;
magL.availableDeadTime = CLLCDesign.deadTime;
magL.switchingFrequency = Fs;
magL.clampFrequency = clampFrequency;
magL.inductanceRatio = CLLCDesign.Lm/CLLCDesign.L1;

% Lower resonance set by Lm. At no load the FHA load resistance goes to infinity, so the
% secondary L2/C2 arm drops out of the tank and the resonant loop is C1 - L1 - Lm. Below fr2
% the tank is capacitive and the leg commutates into a hard turn-on whatever the dead time.
magL.fr2 = 1/(2*pi*sqrt((CLLCDesign.Lm+CLLCDesign.L1)*CLLCDesign.C1));
magL.isInductive = Fs > magL.fr2;
magL.isSoftSwitching = magL.isInductive && magL.marginRatio >= 1;

if ~magL.isInductive
    verdictText = sprintf("The switching frequency %.1f kHz is at or below Fr2 %.1f kHz, " + ...
        "so the tank is capacitive", Fs*1e-3, magL.fr2*1e-3);
elseif magL.marginRatio < 1
    verdictText = sprintf("The selected magnetizing inductance is %.2f times the " + ...
        "soft-switching limit", 1/magL.marginRatio);
else
    verdictText = "The selected magnetizing inductance is within the soft-switching limit";
end

ComponentName = { ...
    'Maximum Lm for zero-voltage switching'; ...
    'Selected Lm'; ...
    'Margin (maximum Lm / selected Lm)'; ...
    'Dead time required by the selected Lm'; ...
    'Dead time available'; ...
    'Switching frequency'; ...
    'Resonant frequency Fr2 due to Lm'};
Value = [ ...
    magL.maximumLm*1e6; ...
    magL.selectedLm*1e6; ...
    magL.marginRatio; ...
    magL.requiredDeadTime*1e9; ...
    magL.availableDeadTime*1e9; ...
    Fs*1e-3; ...
    magL.fr2*1e-3];
Unit = {'uH'; 'uH'; '-'; 'ns'; 'ns'; 'kHz'; 'kHz'};

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(ComponentName), Value, char(Unit), 'VariableNames', tableHeaderNames);
if options.DisplayTableFlag == true
    fprintf("       Maximum Magnetizing Inductance for Soft Switching \n (%s)", verdictText);
    disp(table(designTable,'VariableNames'," "));
end

if ~magL.isSoftSwitching
    warning("estimateCLLCMaximumMagnetizingInductance:NoSoftSwitching", ...
        "%s. Reduce the magnetizing inductance to %.2f uH, raise the dead time to %.1f ns, " + ...
        "or keep the switching frequency above Fr2 (%.1f kHz).", verdictText, ...
        magL.maximumLm*1e6, magL.requiredDeadTime*1e9, magL.fr2*1e-3);
end
end


% Accept a frequency as either a simscape.Value in Hz or a plain number in Hz, which is what
% the help documents and what the callers in this repo mix.
function frequencyHz = frequencyInHz(frequencyValue)
    if isa(frequencyValue, "simscape.Value")
        frequencyHz = value(frequencyValue, "Hz");
    else
        frequencyHz = frequencyValue;
    end
end
