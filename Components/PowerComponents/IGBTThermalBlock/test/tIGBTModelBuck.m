classdef tIGBTModelBuck < matlab.unittest.TestCase
    %TIGBTMODELBUCK Compare the IGBT Model block with the Simscape IGBT in a buck converter.
    %
    %   Simulates IGBTBuckSimulinkDevice (ConverterLibrary IGBT Model) and
    %   IGBTBuckSimscapeDevice (Simscape IGBT with a thermal port, same
    %   datasheet data, junction-to-case resistance and junction thermal mass), and checks that
    %   the conduction, switching and total loss and the junction temperature rise agree, and
    %   that the IGBT Model's heat into the thermal network equals the energy it computed.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        DeviceKind = "IGBT"
    end

    properties
        Comparison
    end

    methods (TestClassSetup)
        function simulateBothModels(testCase)
            testCase.Comparison = test.compareBuckDeviceModels(testCase.DeviceKind, ...
                fileparts(mfilename("fullpath")));
        end
    end

    methods (Test)
        function totalLossMatches(testCase)
            test.assertBuckTotalLoss(testCase, testCase.Comparison);
        end

        function lossTermsMatch(testCase)
            test.assertBuckLossTerms(testCase, testCase.Comparison);
        end

        function junctionRiseMatches(testCase)
            test.assertBuckJunctionRise(testCase, testCase.Comparison);
        end

        function heatEqualsComputedEnergy(testCase)
            test.assertBuckEnergyBalance(testCase, testCase.Comparison);
        end
    end
end
