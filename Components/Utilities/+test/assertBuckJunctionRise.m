function assertBuckJunctionRise(testCase, comparison)
%ASSERTBUCKJUNCTIONRISE Verify the device block's junction rise matches the Simscape device.
%
%   test.assertBuckJunctionRise(testCase, comparison) verifies the junction temperature
%   rise at the end of the run within 5 % of the Simscape device's.
%
%   Inputs:
%     testCase    matlab.unittest.TestCase.
%     comparison  Result of test.compareBuckDeviceModels.

% Copyright 2026 The MathWorks, Inc.

testCase.verifyEqual(comparison.RiseSimulink, comparison.RiseSimscape, "RelTol", 0.05, ...
    sprintf("%s junction rise: device block %.4f K, Simscape device %.4f K.", ...
    comparison.DeviceKind, comparison.RiseSimulink, comparison.RiseSimscape));
end
