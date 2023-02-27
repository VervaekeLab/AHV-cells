function offset = estimateAngularSamplingOffset(imArray, angles, refIm)
%estimateAngularSamplingOffset Estimate offset in sampled angles
%   offset = estimateAngularSamplingOffset(imArray, angles, refIm) estimate
%   the offset between sampled angles and the angular position of images in
%   imArray by iteratively rotating the mean of imArray over different
%   offsets and then calculate the summed pixel correlation between the
%   rotated mean image and a reference image.
%
%   Note: This will work best for images where the rotation speed is near
%   constant. If the rotation speed is very variable, it will be better to
%   derotate all images first and then calculate a mean for comparison with
%   the reference image (see line 44-45).

%   Written by Eivind Hennestad | Vervaeke Lab
  
options = struct;
options.NumBorderPixelsToCrop = 25; % Arbitrary, should depend on center of rotation offset
options.AlignRigid = false;

method = 'rotate all'; % 'rotate mean' | 'rotate all'

if ~isa(refIm, 'single'); refIm = single(refIm); end

stackSize = size(imArray);
frameSize = stackSize(1:2);
frameSizeSmall = repmat( floor( sqrt(min(frameSize).^2 / 2) ), 1, 2);


% Set the offsets to to iterate over.
thetaRange = 1.5;
thetaStep = 0.1;
offsets = -thetaRange:thetaStep:thetaRange;



if options.AlignRigid
    % Crop center to make a small stack and do rigid aligning
    [~, ~, ncShifts] = rotalign.wrapper.rigid( imcropcenter(imDerot, frameSizeSmall), sessionRefSmall);
    frameShifts = fliplr(squeeze(cat(1, ncShifts.shifts)));
    imrig1 = applyFrameShifts(imDerot, round(frameShifts));
end


plotResults = false; % For debugging...

% Start with applying a circular crop to the images and the ref.
imArray = rotalign.utility.stack.imcropcircle(imArray(25:end-25, 25:end-24, :), [], true);
refIm = rotalign.utility.stack.imcropcircle(refIm(25:end-25, 25:end-24), [], true);

imSize = size(imArray);
newSize = repmat(floor (sqrt( size(imArray, 2).^2 / 2 )), 1, 2);


% Initialize variables
errmean = zeros(numel(offsets),1);
referenceImageSmall = rotalign.utility.stack.imcropcenter(refIm, newSize);
rotatedImages = zeros([imSize(1:2),numel(offsets)]);

% Rotate images with each value in othe offset vector
for i = 1:numel(offsets)

    thetashifted = rotalign.utility.shiftvector(angles, offsets(i));
    thetacorrection = angles-thetashifted;

    switch method
        case 'rotate all'
            rotImsDerot = rotalign.rotateStack(imArray, thetacorrection, true);    
            testIm = mean(rotImsDerot, 3);
        case 'rotate mean'
            testIm = imrotate(mean(imArray, 3), mean(thetacorrection), 'bicubic', 'crop');
    end
    
    rotatedImages(:, :, i) = testIm;

end

% Crop rotated images and align them to the reference
rotatedImagesSmall = rotalign.utility.stack.imcropcenter(rotatedImages, newSize);
[~, ~, ncShifts] = rotalign.wrapper.rigid(rotatedImagesSmall, referenceImageSmall);

% Apply shifts to the original full size images
frameShifts = fliplr(squeeze(cat(1, ncShifts.shifts)));
rotatedImagesAligned = rotalign.utility.stack.applyFrameShifts(rotatedImages, round(frameShifts));

% Crop again, making sure to not have any black borders
newSize2 = newSize - max(abs(frameShifts(:)))*2;

rotatedImagesAligned = rotalign.utility.stack.imcropcenter(rotatedImagesAligned, newSize2);
referenceImageSmall = rotalign.utility.stack.imcropcenter(referenceImageSmall, newSize2);

% Note: A second alignment might make a difference in some cases. Woulld
% have to be tested.
% rotatedImagesAligned2 = rigid(rotatedImagesAligned, refImSmall, 'fft');


% Calculate error between reference image and each of the rotated images.
for i = 1:numel(offsets)
    errmean(i) = corr2(referenceImageSmall, rotatedImagesAligned(:, :, i));
end


% Find the best offset
[~, bestInd] = max(errmean);
bestOffset = offsets(bestInd);
%     figure; plot(offsets, errmean, 'o')
offset = bestOffset; return

%%%%% Remaining code was use for getting a more precise estimate if running
%%%%% fewer iteration to get a result faster when all images have to be
%%%%% derotated.

% %     % Remove outliers
% %     errmean(isoutlier(diff(errmean))) = NaN;
% %     errmean = filloutlier(errmean, 'pchip');

% Do a gaussian fit to get an upsampled shift. This has been tested and
% seem to be quite reliable.
f = fit(offsets', errmean, 'gauss2');
offsetsUp = -thetaRange:0.1:thetaRange;
[~, bestIndUp] = max(f(offsetsUp));
bestOffsetUp = offsetsUp(bestIndUp);

% Check that upsampled is within expected range. Saw some examples
% where this was not the case. This happens if there are leftovers of
% borderpixels which are not quite zero due to interpolation effects.
if abs(bestOffsetUp - bestOffset) > thetaStep/2
    % Do a polyfit on five values instead.
    try
        errmeanB = errmean(bestInd-2:bestInd+2);
        offsetsB = offsets(bestInd-2:bestInd+2);
        P = polyfit(offsetsB', errmeanB, 2);

        offsetsUpB = offsetsB(1):0.1:offsetsB(end);
        f2 = polyval(P, offsetsUpB);

        [~, bestIndUp] = max(f2);
        offset = offsetsUpB(bestIndUp);

    catch
        offset = bestOffset;
    end

else
    % Return the best offset.
    offset = offsetsUp(bestIndUp);

end


if plotResults
    try
        figure; plot(offsets, errmean, 'o')
        hold on
        plot(offsetsUp, f(offsetsUp))
        if abs(bestOffsetUp - bestOffset) > thetaStep/2
            plot(offsetsUpB, f2)
            plot(offset, f2(bestIndUp), '*');
        else
            plot(offsetsUp(bestIndUp), f(offset), '*');
        end
    end
end



end