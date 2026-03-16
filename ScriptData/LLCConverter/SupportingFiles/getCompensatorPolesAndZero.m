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

compensatorPoles(1) = plantTF.zeros(1);
compensatorPoles(2) = 0;
compensatorZeros = plantTF.poles;
llcCompensator.wn = abs(imag(compensatorZeros(1)));

[b,a] = zp2tf(compensatorZeros,compensatorPoles,1);

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


