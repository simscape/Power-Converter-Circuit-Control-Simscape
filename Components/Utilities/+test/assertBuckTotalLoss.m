function assertBuckTotalLoss(testCase, comparison)
%ASSERTBUCKTOTALLOSS Verify the device block's total loss matches the Simscape device.
%
%   test.assertBuckTotalLoss(testCase, comparison) verifies the total loss of the
%   ConverterLibrary device within 3 % of the Simscape device's.
%
%   Inputs:
%     testCase    matlab.unittest.TestCase.
%     comparison  Result of test.compareBuckDeviceModels.

% Copyright 2026 The MathWorks, Inc.

testCase.verifyEqual(comparison.TotalSimulink, comparison.TotalSimscape, "RelTol", 0.03, ...
    sprintf("%s total loss: device block %.4f W, Simscape device %.4f W.", ...
    comparison.DeviceKind, comparison.TotalSimulink, comparison.TotalSimscape));
end
