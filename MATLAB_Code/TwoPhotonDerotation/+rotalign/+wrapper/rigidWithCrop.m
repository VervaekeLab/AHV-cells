function [imArray, frameShifts] = rigidWithCrop(imArray, referenceImage, frameSize)

% OUTPUTS:
%   imArray     : Image array corrected rigidly based on cropped versions
%   frameShifts : Vector of shifts (nx2) where each row is [dx, dy]
    
    imArrayCropped = rotalign.utility.stack.imcropcenter(imArray, frameSize);
    referenceCropped = rotalign.utility.stack.imcropcenter(referenceImage, frameSize);

    % Crop center to make a small stack and do rigid aligning
    [~, ~, ncShifts] = rotalign.wrapper.rigid( imArrayCropped, referenceCropped);
    frameShifts = fliplr(squeeze(cat(1, ncShifts.shifts))); % yx -> xy
    
    imArray = rotalign.utility.stack.applyFrameShifts(imArray, round(frameShifts));
end
