function llcCompensator = getCompensatorPolesAndZero(plantTF,options)
%   This function constructs a 2P2Z (two-pole, two-zero) compensator transfer function
%   for an LLC converter based on the plant poles and zeros. The compensator includes
%   two zeros (placed at the plant poles) and two poles (one at the plant zero, one at s=0).
%   The transfer function can be returned in continuous (s-domain), discrete (z-domain),
%   or both domains.
%
%   Inputs:
%     plantTF   Struct containing plant poles and zeros (fields: poles, zeros)
%
%     options   Name-value structure with fields:
%                 - Domain:        'Continuous', 'Discrete', or 'All'
%                                  (default: 'All')
%                 - SamplingTime:  Sampling time for discrete compensator
%                                  (default: simscape.Value(1e-6,"s"))
%
%   Output:
%     llcCompensator   Struct with fields:
%                        - numSDomain:   Numerator coefficients (s-domain)
%                        - denSDomain:   Denominator coefficients (s-domain)
%                        - numZDomain:   Numerator coefficients (z-domain)
%                        - denZDomain:   Denominator coefficients (z-domain)
%                        - wn:           Natural frequency (rad/s) of dominant pole
%
%   Method:
%     - Compensator zeros are placed at the plant poles.
%     - Compensator poles: one at the plant zero, one at s=0 (integrator).
%     - Transfer function is constructed with zp2tf.
%     - If 'Discrete' or 'All' is specified, transfer function is discretized with c2d.
%     - Prints the transfer function(s) to the command window.
%
%   Example:
%     plantTF.poles = [-1000+1i*50000, -1000-1i*50000];
%     plantTF.zeros = [-5000];
%     options.Domain = 'All';
%     options.SamplingTime = simscape.Value(2e-6,"s");
%     llcCompensator = getCompensatorPolesAndZero(plantTF, options);

% Copyright 2025-2026 The MathWorks, Inc.
arguments
    plantTF struct
    options.Domain (1,:) char {mustBeMember(options.Domain,{'Continuous','Discrete','All'})} = 'All';
    options.SamplingTime (1,1) = simscape.Value(1e-6,"s"); % Sampling time for discrete compensator
end

% Find Compensator Poles from the Plant poles
% Step 1: Filter elements with negative real parts only (left hand side poles)
negRealMask = real(plantTF.poles) < 0;
filteredPoles = plantTF.poles(negRealMask);

if ~isempty(plantTF.poles(real(plantTF.poles) >= 0))
fprintf('Poles with positive real parts:\n');
disp(plantTF.poles(real(plantTF.poles) >= 0));
end

% Step 2: Sort by absolute value of real parts (ascending)
[~, sortIdx] = sort(abs(real(filteredPoles)));
sortedPoles = filteredPoles(sortIdx);

% Step 3: Identify complex conjugate pairs and real-only elements
numComplexPole = sum(imag(sortedPoles)~=0);
complexConjugatePairs = zeros(1,numComplexPole);
realOnlyElements = zeros(1,length(sortedPoles)-numComplexPole);
usedIndices = false(size(sortedPoles));
imagIdx = 1;
realIdx = 0;

for i = 1:length(sortedPoles)
    if usedIndices(i)
        continue;
    end

    currentPole = sortedPoles(i);

    if imag(currentPole) == 0
        % Real-only element
        realIdx = realIdx+1;
        realOnlyElements(realIdx) = currentPole;
        usedIndices(i) = true;
    else
        % Look for complex conjugate
        for j = i+1:length(sortedPoles)
            if ~usedIndices(j) && ...
               real(sortedPoles(j)) == real(currentPole) && ...
               imag(sortedPoles(j)) == -imag(currentPole)
                % Found a conjugate pair
                complexConjugatePairs(imagIdx) = currentPole;
                complexConjugatePairs(imagIdx+1) = sortedPoles(j);
                usedIndices(i) = true;
                usedIndices(j) = true;
                imagIdx = imagIdx+2;
                break;
            end
        end
        % If no conjugate found, treat as unpaired complex
        if ~usedIndices(i)
            realIdx = realIdx+1;
            realOnlyElements(realIdx) = currentPole;
            usedIndices(i) = true;
        end
    end
end


% Step 4: Select the two dominant poles with preference for conjugate pairs
selectedPoles = [];

if ~isempty(complexConjugatePairs)
    % Prefer complex conjugate pair with smallest |Re|
    % complexConjugatePairs are stored as sequential pairs: [p1, conj(p1), p2, conj(p2), ...]
    % Find the pair with smallest |Re|
    selectedPoles = complexConjugatePairs(1:2);

    % Check if any real-only element has a smaller |Re| than the selected pair
    selectedAbsRe = abs(real(selectedPoles(1)));
    smallerRealPoles = realOnlyElements(abs(real(realOnlyElements)) < selectedAbsRe);

    if ~isempty(smallerRealPoles)
        fprintf('\n--- NOTE ---\n');
        fprintf('Complex conjugate pole pair is selected over the following poles\n');
        fprintf('that have a smaller |Re| part:\n');
        for k = 1:length(smallerRealPoles)
            disp(smallerRealPoles(k));
        end
    end

else
    % No complex conjugate pairs — fall back to real-only elements
    fprintf('\nNo complex conjugate pairs found. Selecting from real-only elements.\n');
    [~, sortRealIdx] = sort(abs(real(realOnlyElements)));
    sortedReal = realOnlyElements(sortRealIdx);
    selectedPoles = sortedReal(1:min(2, end));
end

% Select Zeros
negativeZero = plantTF.zeros(plantTF.zeros<0);
[~,sortIdx] = sort(abs(negativeZero));
negativeZero = negativeZero(sortIdx);

% Compensator poles and zeros
compensatorPoles(1) = negativeZero(1);
compensatorPoles(2) = 0;
compensatorZeros = selectedPoles;
llcCompensator.wn = abs(imag(compensatorZeros(1)));

[b,a] = zp2tf(compensatorZeros',compensatorPoles',1);

switch options.Domain
    case "Continuous"
        llcCompensator.numSDomain = b;
        llcCompensator.denSDomain = a;
        fprintf(" \n Continuous S-Domain transfer function \n");
        tf(b,a)
    case "Discrete"
        fprintf("\n Discrete Z-Domain transfer function \n");
        sysd = c2d(tf(b,a),1e-6) %#ok<*NOPRT>
        llcCompensator.numZDomain = sysd.Numerator;
        llcCompensator.denZDomain = sysd.Denominator;
    case "All"
        llcCompensator.numSDomain = b;
        llcCompensator.denSDomain = a;
        fprintf("\n Continuous S Domain transfer function \n");
        tf(b,a)
        fprintf("\n Discrete Z-Domain transfer function \n");
        sysd = c2d(tf(b,a),1e-6)
        llcCompensator.numZDomain = cell2mat(sysd.Numerator);
        llcCompensator.denZDomain = cell2mat(sysd.Denominator);
    otherwise
        error("Invalid value for Domain name-value argument. " + ...
            "Specify the argument value as Continuous, Discrete, or All");
end


