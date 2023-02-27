function frameInfo = initializeFrameInfo(numFrames)

    frameInfo = struct;
    frameInfo.bidirOffset = zeros(numFrames, 1);
    frameInfo.cLimMinMax = nan(numFrames, 2);
    frameInfo.cLimDoubleZero5 = nan(numFrames, 2);
    frameInfo.cLimTripleZero5 = nan(numFrames, 2);
    frameInfo.angularPosition = zeros(numFrames, 1);
    frameInfo.isFrameRotating = false(numFrames, 1);
    frameInfo.rigidShifts = zeros(numFrames, 2);
    frameInfo.rmsMovement = zeros(numFrames, 1);
    frameInfo.angularCorrections = zeros(numFrames, 1);
    frameInfo.rotationOffset = zeros(numFrames, 1);
    frameInfo.shiftsNcRigid = struct('shifts', [], 'shifts_up', [], 'diff', []);
    frameInfo.shiftsNcNonrigid = struct('shifts', [], 'shifts_up', [], 'diff', []);
    frameInfo.isFrameSavedTemp = false(numFrames, 1);
    frameInfo.isFrameSavedCorr = false(numFrames, 1);
    frameInfo.isFrameSavedMavg = false(numFrames, 1);

end