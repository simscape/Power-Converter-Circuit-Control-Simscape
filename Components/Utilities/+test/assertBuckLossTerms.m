function assertBuckLossTerms(testCase, comparison)
%ASSERTBUCKLOSSTERMS Verify every loss term of the device block matches the Simscape device.
%
%   test.assertBuckLossTerms(testCase, comparison) verifies each loss term (conduction,
%   turn-on and turn-off, or conduction and recovery) within 5 % of the Simscape device's,
%   or within 0.05 W where the term is close to zero.
%
%   Inputs:
%     testCase    matlab.unittest.TestCase.
%     comparison  Result of test.compareBuckDeviceModels.

% Copyright 2026 The MathWorks, Inc.

terms = comparison.Terms;
for termIndex = 1:height(terms)
    tolerance = max(0.05, 0.05 * abs(terms.Simscape(termIndex)));
    testCase.verifyEqual(terms.Simulink(termIndex), terms.Simscape(termIndex), "AbsTol", tolerance, ...
        sprintf("%s %s loss: device block %.4f W, Simscape device %.4f W.", comparison.DeviceKind, ...
        terms.Term(termIndex), terms.Simulink(termIndex), terms.Simscape(termIndex)));
end
end
