function magL = estimateMaximumMagInductance(LLCDesign,options)
%   This function estimates the maximum allowable magnetizing inductance (Lm)
%   to ensure soft-switching operation in an LLC resonant converter. The selected
%   Lm should be less than or equal to the estimated maximum value.
%
%   Inputs:
%     LLCDesign   Struct with LLC design parameters:
%                   - Lm: Magnetizing inductance (H)
%                   - L:  Resonant inductor (H)
%                   - C:  Resonant capacitor (F)
%                   - Cparasitic: Parasitic capacitance (F)
%                   - resonantFreq: Resonant frequency (simscape.Value or numeric, Hz)
%                   - deadTime: Dead time (s)
%
%     options     Name-value structure with fields:
%                   - SwitchingFrequency: Switching frequency (simscape.Value or numeric, Hz)
%                                         (default: 0.5 * resonantFreq)
%                   - DisplayTableFlag:   true/false to display summary table (default: true)
%
%   Output:
%     magL        Struct with fields:
%                   - FsAwayFromFr: Max Lm when Fs << Fr (H)
%                   - FsCloseToFr:  Max Lm when Fs ~ Fr (H)
%                   - FsbyFr:       Lm/L ratio
%                   - selectedLm:   User-selected Lm (H)
%                   - fr2:          Resonant frequency due to Lm (Hz)
%
%   Method:
%     - Calculates max Lm for two frequency scenarios: Fs << Fr and Fs ~ Fr.
%     - Compares selected Lm with max value for soft switching.
%     - Optionally displays a summary table with results.
%
%   Example:
%     LLCDesign.Lm = 120e-6;
%     LLCDesign.L = 40e-6;
%     LLCDesign.C = 100e-9;
%     LLCDesign.Cparasitic = 10e-12;
%     LLCDesign.resonantFreq = simscape.Value(100e3,"Hz");
%     LLCDesign.deadTime = 200e-9;
%     options.SwitchingFrequency = simscape.Value(60e3,"Hz");
%     options.DisplayTableFlag = true;
%     magL = estimateMaximumMagInductance(LLCDesign, options);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCDesign struct
    options.SwitchingFrequency = simscape.Value(0.5*LLCDesign.resonantFreq.value,"Hz"); % Switching Frequency
    options.DisplayTableFlag = true; % Display summary table
end

% Assuming 50% of resonant frequency in the capacitive region+
Fs = options.SwitchingFrequency.value;
Fr = LLCDesign.resonantFreq;
x = Fs/Fr;

k = LLCDesign.Lm/LLCDesign.L;
Ts = 1/Fs; Tr = 1/LLCDesign.resonantFreq;
count = 1;
if Fs<Fr
    tempVal1 = 1-(Ts-Tr)/((sqrt(k+1)-1)*Tr);
    tempVal2 = LLCDesign.deadTime*(1+2*k*sqrt(k+1)-k)/(16*(k+1)*LLCDesign.resonantFreq*...
        LLCDesign.Cparasitic);
    magL.FsAwayFromFr = tempVal1*tempVal2;
    ComponentName{count} = 'Maximum Lm assuming Fs is far away from Fr';
    Value(count) = magL.FsAwayFromFr*1e6;
    Unit{count} = 'uH';
end
magL.FsCloseToFr = LLCDesign.deadTime*(0.5*(k+1)+k/x-k)/(8*Fr*(k+1)*LLCDesign.Cparasitic);
magL.FsbyFr = k;
magL.selectedLm = LLCDesign.Lm;
magL.fr2 = 1/(2*pi*sqrt((LLCDesign.Lm+LLCDesign.L)*LLCDesign.C));

count = count+1;
ComponentName{count} = 'Maximum Lm assuming Fs is close to Fr';
Value(count) = magL.FsCloseToFr*1e6;
Unit{count} = 'uH';
count = count+1;
ComponentName{count} = 'Resonant frequency Fr2 due to Lm';
Value(count) = magL.fr2;
Unit{count} = 'Hz';

if Fs<Fr
    maxLm = min([ magL.FsAwayFromFr,magL.FsCloseToFr]);
else
    maxLm =magL.FsCloseToFr;
end

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
count = count+1;
ComponentName{count} = 'Selected Lm';
Value(count) = magL.selectedLm*1e6;
Unit{count} = 'uH';



designTable = table(char(ComponentName'),Value', char(Unit'),'VariableNames',tableHeaderNames);
if options.DisplayTableFlag == true
    if maxLm>magL.selectedLm
        fprintf("       Maximum Magnetizing Inductance for Soft Switching \n (The selected magnetizing inductance is within the soft-switching limit)");
        disp(table(designTable,'VariableNames'," "));
    else
        fprintf("       Maximum Magnetizing Inductance for Soft Switching \n (The selected magnetizing inductance is out of the soft-switching limit)");
        disp(table(designTable,'VariableNames'," "));
    end
end
end


