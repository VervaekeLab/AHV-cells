function options = registerImagesRotation(recordingPath, options)
%registerImagesRotation Registers images from a recording with rotation.
%   registerImagesRotation(recordingPath, options) register images from 
%   recording saved in recordingPath. recordingPath is the full 
%   pathstring. Options is a struct containing (at the moment) number of 
%   frames per part (when splitting images into smaller parts when running 
%   image registration and datapath (a path string where to save results 
%   from image registration.

% TODO: 
%  - crop final images based on 95th percentile of black pixels - doneish.
%  - fix downsampling when creating derotation displacement field - done.
%  - update session reference. Always use 0 deg, but use the latest - done.
%  - Handle edge effects better. Crop images a bit for nonrigid. Interpolate
%    shifts to fit with original image pos. Eg. when shifts are calculated
%    for smaller grids, those shifts will be missplaced when applying to
%    the original images. - Not important, not urgent.
%  - Use consistent brightness limits for average and max projections - done
%  - Save session reference orig size as tiff - done
%  - Save session reference square size as tiff. No crop! - done
%  - create rotation avg stack. - done
%
%  - implement switcher for rigid/nonrigid
%  - use imerode to remove whiteish edges due to imrotate interpolation


% Options: 
%   RecDirPath
%   SaveDirPath
%   MovingAvgBinsize
%   BidirBatchSize
%   nFlybackLines
%   redoAliging
%   partsToAlign            (array of parts)
%   regMethod               (rigid | nonrigid)


% Set default inputs if none are given
if nargin < 1 || isempty(recordingPath); recordingPath = uigetdir(); end
if nargin < 2; options = struct(); end

if isequal(recordingPath, 0); return; end

% Create parallel pool on cluster if necessary
if isempty(gcp('nocreate')); parpool(); end


% Start clock 
tBegin = tic;

% Get default options.
options = getAllOptions(options, recordingPath);

options.selectedRegMethod = 'nonrigid';

% Find sessionID. Use foldername if not found.
sid = strfindsid(recordingPath);
if isempty(sid); [~, sid] = fileparts(recordingPath); end

% Create anonymous function for creating filepaths
pathfun = @(subfolder, filename) ...
    fullfile(options.saveDirPath, subfolder, strcat(sid, '_', filename));

% Load session info/protocol.

% Check that files are not in parts
L = dir(fullfile(recordingPath, '*part*.raw'));
if ~isempty(L)
    joinRawFiles(recordingPath)
end


% Create a virtual SciScan stack object.
rawstack = virtualSciScanStack(recordingPath);
CH = 2; % For now, this is always true...

% Load an image to get the size when images are destretched.
lineInd = options.nFlybackLines+1 : size(rawstack, 1);
dummyIm = rawstack(lineInd, :, 1);
scanParam = getSciScanVariables(recordingPath, {'ZOOM', 'x.correct'});
dummyIm = correctResonanceStretch(dummyIm, scanParam, 'imwarp');

% Set and calculate image sizes.
imSize = size(dummyIm);
imSizeSquare = repmat(min(imSize), 1, 2);
% % % imSizeSquare = imSize;

% Calculate expanded image size (diagonal of original, result of rotation)
imSizeLarge = repmat(ceil(sqrt(sum(imSize.^2))), 1, 2);

% Calculate reduced image size (common square of all derotated images)
imSizeSmall = repmat(floor(sqrt( imSize(2).^2 / 2)), 1, 2);

% Load metadata
meta2P = getSciScanMetaData(recordingPath);
nFrames = meta2P.nFrames;
%save(pathfun('metadata', 'meta2P.mat'), 'meta2P') % Todo: uncomment!

% Get all relevant filepaths
filePaths = getFilePaths(options);

% Prepare files for saving data 
tempStack = createbinary(filePaths.Temp, [imSize, nFrames], 'uint16');
% tempStack = allocateRawFile(filePaths.Temp, [imSize, nFrames], 'uint16');

stackSize = [imSizeSquare, floor(nFrames/options.MovingAvgBinsize)];
mavgStack = allocateRawFile(filePaths.Mavg, stackSize, 'uint8');

% Load angular frame positions
[angles, rotating] = loadFrameRotations(recordingPath);
rotating = imdilate(rotating, ones(5,1));

% Check that there are frames with rotation. Otherwise, run registerImages 
% instead and cancel/return from this function.

if all(rotating == 0)

% Todo: registerImages should be implementated like this function

% % %     registerImages(recordingPath, options) 
% % %     return
    
    batchSize = 2000;
    trialStart = 1:batchSize:nFrames;
    trialStop = cat(2, trialStart(2:end)-1, nFrames);
    isTrialRotating = false(size(trialStart));
    statPositions = zeros(size(trialStart));
    
else

    batchSize = nan;
    % % % Based on experience, the angles should be shifted 0.5 samples.
    angles = shiftvector(angles, 0.5);
%     angles = shiftvector(angles, -2);
    
    % Prepare order of processing. Do stationary first, and then rotations
    [rotStart, rotStop] = findTransitions(rotating);
    [statStart, statStop] = findTransitions(~rotating);

    statCenterInd = round(mean([statStart'; statStop']));
    statPositions = mod(round(angles(statCenterInd)), 360);

    % Use first zero position trial when the baseline trial is very short...
    if statStop(1)-statStart(1) < 100
        firstZeroTrial = find(statPositions(2:end)==0, 1, 'first') + 1;
        statStart([1,firstZeroTrial]) = statStart([firstZeroTrial,1]);
        statStop([1,firstZeroTrial]) = statStop([firstZeroTrial,1]);
    end

    trialStart = cat(1, statStart, rotStart);
    trialStop = cat(1, statStop, rotStop);
    isTrialRotating = cat(1, false(size(statStart)), true(size(rotStart)));
    
    [~, trialInd] = sort(trialStart);

    assert(all(trialStart(trialInd(2:2:end))==rotStart), 'Session reference image update requires all rotation trial numbers to be even')

end

nParts = numel(trialStart);

% Save image size to fileinfo
% Todo: uncomment!
%save(filePaths.fileInfo, 'imSizeSmall', 'imSize', 'imSizeLarge', 'nFrames', 'nParts');
%save(filePaths.options, 'options');

% Prepare imreg results. Struct of vectors.
imregVars = initializeImregVariables(meta2P.nFrames, nParts);

imregVars.trialStart = trialStart;
imregVars.trialStop = trialStop;

imregVars.angularPosition(:) = angles;
imregVars.isFrameRotating(:) = rotating;

bidirBatchSize = options.BidirBatchSize;
pLevels = [0.05, 0.005];
pLevels = [pLevels, 100-pLevels];

% Set up indices for binning frames to create a moving average stack
binSize = options.MovingAvgBinsize;
binInd = reshape(1:floor(meta2P.nFrames/binSize)*binSize, binSize, []);

% Load and overwrite initialized imregvars if they exist on file.
if exist(filePaths.RegVar, 'file')
    S = load(filePaths.RegVar, 'imregVars'); imregVars = S.imregVars;
end
% angles = imregVars.angularPosition;
% rotating = imregVars.isFrameRotating;

% Initialize reference images (large and normal size)
refImagesPre = allocateRawFile(filePaths.RefImages1, [imSize, nParts], 'uint16');
refImagesPost = allocateRawFile(filePaths.RefImages2, [imSize, nParts], 'uint16');
darkPixelCount = allocateRawFile(filePaths.DarkPixel, [imSize, nParts], 'single');

% Initialize average and max projections of each part.
avgProj = allocateRawFile(filePaths.AvgProj, [imSizeSquare, nParts], 'uint8');
maxProj = allocateRawFile(filePaths.MaxProj, [imSizeSquare, nParts], 'uint8');

housekeeper = onCleanup(@() fclose('all'));
prevStr = [];

if ~isfield(options, 'partsToAlign') || isempty(options.partsToAlign)
    partsToAlign = 1:nParts;
else
    partsToAlign = options.partsToAlign;
end

% Only rotation trials (If realigning rotation trials):
if true % For debugging...
    partsToAlign = find(isTrialRotating)'; options.redoAligning = true;
    %dbstop in registerImagesRotation at 486
end

% Start looping.
for i = partsToAlign

    if imregVars.isPartFinished(i) && ~options.redoAligning
        continue
    end

    elapsedTime = toc(tBegin);
    timestr = sprintf('%02d:%02d:%02d', floor(elapsedTime/3600), floor(mod(elapsedTime, 3600) / 60), floor(mod(elapsedTime, 60)));
    newStr = sprintf('Registering part %d out of %d, Elapsed Time: %s', i, nParts, timestr);
    refreshdisp(newStr, prevStr, i)
    prevStr = newStr;

    % Assign the first and last frame number to process.
    ii = trialStart(i);
    ie = trialStop(i);
    isRotating = isTrialRotating(i);
            
    % Load data
    im = single(rawstack(lineInd, :, ii:ie));
    
% %     im = correctLineByLineBrightnessDifference(im);
    
    % Save brightness limits
    bLims = prctile(reshape(im, [], size(im,3)), pLevels)';
    if iscolumn(bLims); bLims = bLims'; end % If size(im,3)==1. 
    
    imregVars.cLimMinMax(ii:ie, 1) = min(reshape(im, [], size(im,3)));
    imregVars.cLimMinMax(ii:ie, 2) = max(reshape(im, [], size(im,3)));
    imregVars.cLimDoubleZero5(ii:ie, :) = bLims(:, [1,3]);
    imregVars.cLimTripleZero5(ii:ie, :) = bLims(:, [2,4]);
    
    % Correct resonance stretch
    scanParam = getSciScanVariables(recordingPath, {'ZOOM', 'x.correct'});
    im = correctResonanceStretch(im, scanParam, 'imwarp');
    
% %     im2 = correctFovBrightnessAsymmetry(im, 1);
% %     im3 = correctFovBrightnessAsymmetry(im2, 2);
    
    % Do the bidirectional offset correction.
    if ~isRotating
        [im, bidirBatchSize, colShifts] = correctLineOffsets(im, bidirBatchSize);
        imregVars.bidirOffset(ii:ie) = colShifts;
    else
        colShift = ceil(mean(imregVars.bidirOffset([ii-1, ie+1]))*10)./10;
        im = apply_bidirectional_offset(im, colShift);
    end
    
    
    % % Update session reference image.
    
    % Find the previous trial which was recorded at 0 degrees. Align it
    % non-rigidly to the first trial of the session (which was also 0 deg).
    if i <= numel(statPositions)
        prevZeroTrial = find(statPositions(1:i-1)==0, 1, 'last');
    else
        currentTrial = find(trialInd == i);
        prevZeroTrial = find(statPositions(1:currentTrial/2)==0, 1, 'last');
    end
    
    
    % The sessionref is used for alignment of frames undergoing rotation,
    % and updating the sessionref should reduce misalignment effects due to
    % drift of recording and warping of tissue during recording. That is
    % why nonrigid alignment is used. Still not sure if this is the best
    % way...
    if i > 1
        prevRef = refImagesPost.Data.yxn(:, :, prevZeroTrial);
        if prevZeroTrial ~= 1
            prevRefSqr = imcropcenter(prevRef, imSizeSquare);
            firstRefSqr = imcropcenter(refImagesPost.Data.yxn(:, :, 1), imSizeSquare);
            [~, ~, nrShifts, nrOpts] = nonrigid(prevRefSqr, firstRefSqr, 'finetune');
            nrOpts.d1 = size(prevRef,1); nrOpts.d2 = size(prevRef,2);
            sessionRef = apply_shifts(prevRef, nrShifts, nrOpts);
        else
            sessionRef = prevRef;
        end
    end

    
    % % Align images from stationary segments at 0 degrees.
    if ~isRotating && statPositions(i) == 0 
        
% % %         if all(rotating == 0)
% %             if i == 1
% %                 [imrig, ~, ncShifts, ncOptions] = nonrigid(imtmp, [], '8x1d');
% %             else
% %                 [imrig, ~, ncShifts, ncOptions] = nonrigid(imtmp, [], '8x1b');
% % 
% % % % %                 [imrig, refOut, ncShifts, ncOptions] = nonrigid(imtmp, refOut, '8x1c');
% %             end
% % %             [imrig, ~, ncShifts, ncOptions] = nonrigid(im, [], '8x1d');
    
% % % % Use movement vector to create a better reference and rerun reg.            
% %             rmsmov = cellfun(@(shifts) sqrt(sum(shifts(:).^2)), {ncShifts(:).shifts} );
% %             rmsmov = prctfilt(rmsmov, 20, 100);
% %             [~, ind] = sort(rmsmov);
% %             
% %             nInds = round( numel(ind) * 0.5 );
% %             imref = mean(imrig(:,:,ind(1:nInds)), 3);
% %             imrig =  nonrigid(imrig, imref, '8x1d');
            
% % %         else
            
        switch options.selectedRegMethod

            case 'rigid'
                [imrig, ~, ncShifts, ncOptions] = rigid(im);
            case 'nonrigid'
                [imrig, ~, ncShifts, ncOptions] = nonrigid(im, [], '8x1d');
        end

% % %         end
        
        imrig = removeDarkPixels(imrig, mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        refImagesPre.Data.yxn(:, :, i) = uint16(mean(imrig, 3));

        
        % Find substack drift
        if i == 1
            imregVars.imageDrift(1, :) = [0, 0];
        else
            subRefSmall = imcropcenter(refImagesPre.Data.yxn(:, :, i), imSizeSmall);
            sessionRefSmall = imcropcenter(refImagesPre.Data.yxn(:, :, 1), imSizeSmall);
            [~, ~, ncShiftsSubStack, ~] = rigid(subRefSmall, sessionRefSmall);
            
            imregVars.imageDrift(i, :) = fliplr(squeeze(ncShiftsSubStack.shifts)');
            
            % Add together individual frame shifts and substack frame shifts.
            ncShifts = addShifts(ncShifts, ncShiftsSubStack);
            
        end
        
        % Call normcorres apply_shift function do subpixel shifts.
        ncOptions.shifts_method = 'cubic';
        ncOptions.d1 = size(im,1); ncOptions.d2 = size(im,2);
        im = apply_shifts(im, ncShifts, ncOptions);
        
        

        
% % %         if i ~= 1
% % %             % Remove dark pixels because they will screw up the phase
% % %             % correlation
% % %             
% % % %             tempRef = imcropcircle(imcropcenter(mean(im, 3), imSizeSquare));
% % %             tempRef = removeDarkPixels(mean(im, 3), mean(imregVars.cLimDoubleZero5(ii:ie, :)));
% % % 
% % %             % Align mean image non-rigidly to session reference and apply
% % %             % shifts to all frames.
% % %             [~, ~, nrShifts, nrOpts] = nonrigid(tempRef, sessionRef, 'finetune2');
% % % 
% % %             % Remove shifts in corners and replace with interpolated values.
% % % % %             updatedShifts = replaceGridCornerShifts(nrShifts); Dont
% % % % need to do that in this case, because corners are not affected...
% % %             updatedShifts = repmat(nrShifts, size(im,3), 1);
% % % 
% % %             nrOpts.shifts_method = 'cubic';
% % %             nrOpts.d1 = size(im,1); nrOpts.d2 = size(im,2);
% % % 
% % %             % Apply non rigid shifts to the whole stack
% % %             im = apply_shifts(im, updatedShifts, nrOpts);
% % %         end
        
        trialRef = removeDarkPixels(mean(im, 3), mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        refImagesPost.Data.yxn(:, :, i) = uint16(trialRef);
        
        % Save individual frame shifts.
        switch options.selectedRegMethod
            case 'rigid'
                imregVars.shiftsNcRigid(ii:ie) = ncShifts;
                imregVars.rigidShifts(ii:ie, :) = fliplr(squeeze(cat(1, ncShifts.shifts)));
            case 'nonrigid'
                imregVars.shiftsNcNonrigid(ii:ie) = ncShifts;
        end
        
        % Save root mean square movement of frames.
        rmsmov = cellfun(@(shifts) sqrt(sum(shifts(:).^2)), {ncShifts(:).shifts} );
%         rmsmov = prctfilt(rmsmov, 20, 100);
        imregVars.rmsMovement(ii:ie) = rmsmov;

        
    % % Align images from stationary segments NOT at 0 degrees.
    elseif ~isRotating && statPositions(i) ~= 0 && i > 1
        
        switch options.selectedRegMethod
            case 'rigid'
                [imrig, ~, ncShifts, ncOptions] = rigid(im);
            case 'nonrigid'
                [imrig, ~, ncShifts, ncOptions] = nonrigid(im, [], '8x1d');
        end

        % Remove dark pixels.
        imrig = removeDarkPixels(imrig, mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        refImagesPre.Data.yxn(:, :, i) = uint16(mean(imrig, 3));
        
        
        % Find rotation offset (only for segments not at 0 degrees)
        if i == 1 
            offsetCorrection = [0, 0];
        elseif statPositions(i-1) ~= statPositions(i) 
            imregVars.rotationCenterOffset(i, :) = findCenterOfRotationOffset(refImagesPre.Data.yxn(:, :, i-1), ...
                refImagesPre.Data.yxn(:, :, i), statPositions(i-1), statPositions(i));
            offsetCorrection = imregVars.rotationCenterOffset(i, :);
        else
            % Use the mean of previous values.
            offsetCorrection = nanmean(imregVars.rotationCenterOffset(1:i, :));
        end
%         offsetCorrection = [0, 0];
        im = shiftStack(imrig, -round(offsetCorrection));
        im = imrotate(im, statPositions(i), 'bicubic', 'crop');
        
        % Remove edges because they are whitened by the bicubic interp.
        tmpmask = mean(im, 3) ~= 0;
        tmpmask = imerode(tmpmask, ones(5,5));
        im = cast(tmpmask, 'like', im) .* im;
        
        im = shiftStack(im, round(offsetCorrection));
        im = removeDarkPixels(im, mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        
% % %         % Crop center and redo the rigid...
% % %         tmpImSmall = imcropcenter(im, imSizeSmall);
% % %         
% % %         % Align rigidly
% % %         [imrig, ~, ncShifts, ncOptions] = rigid(tmpImSmall);
% % %         imregVars.rigidShifts(ii:ie, :) = fliplr(squeeze(cat(1, ncShifts.shifts)));
% % %         imrig = removeDarkPixels(imrig, mean(imregVars.cLimDoubleZero5(ii:ie, :)));

        % Find substack drift
        if i == 1
            imregVars.imageDrift(1, :) = [0, 0];
        else
            subRefSmall = imcropcenter(mean(im, 3), imSizeSmall);
            sessionRefSmall = imcropcenter(refImagesPre.Data.yxn(:, :, 1), imSizeSmall);
            
            [~, ~, ncShiftsSubStack, ~] = rigid(subRefSmall, sessionRefSmall);
            imregVars.imageDrift(i, :) = fliplr(squeeze(ncShiftsSubStack.shifts)');
            
%             % Add together individual frame shifts and substack frame shifts.
%             ncShifts = addShifts(ncShifts, ncShiftsSubStack);             
        end

        % Call normcorres apply_shift function do subpixel shifts.
        ncOptions.shifts_method = 'cubic';
        ncOptions.d1 = size(im,1); ncOptions.d2 = size(im,2);
        ncShiftsSubStack = repmat(ncShiftsSubStack, size(im, 3), 1);
        im = apply_shifts(im, ncShiftsSubStack, ncOptions);

% % %         % Remove dark pixels because they will screw up the phase
% % %         % correlation
% % %         tempRef = imcropcircle(imcropcenter(mean(im, 3), imSizeSquare));
% % %         tempRef = removeDarkPixels(tempRef, mean(imregVars.cLimDoubleZero5(ii:ie, :)));
% % %         
% % %         % Align mean image non-rigidly to session reference and apply
% % %         % shifts to all frames.
% % %         [~, ~, nrShifts, nrOpts] = nonrigid(tempRef, imcropcenter(sessionRef, imSizeSquare), 'finetune2');
% % %         
% % %         % Remove shifts in corners and replace with interpolated values.
% % %         updatedShifts = replaceGridCornerShifts(nrShifts);
% % %         updatedShifts = repmat(updatedShifts, size(im,3), 1);
% % %         nrOpts.shifts_method = 'cubic';
% % %         nrOpts.d1 = size(im,1); nrOpts.d2 = size(im,2);
% % %         
% % %         % Apply non rigid shifts to the whole stack
% % %         im = apply_shifts(im, updatedShifts, nrOpts);
        
        trialRef = removeDarkPixels(mean(im, 3), mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        refImagesPost.Data.yxn(:, :, i) = uint16(trialRef);
        
        imregVars.shiftsNcRigid(ii:ie) = ncShifts;
% % %         imregVars.shiftsNcNonrigid(ii:ie) = updatedShifts;
        
    else % Is rotating.
        
        % Shift stack based on average of rotation center offsets before 
        % derotation. Use the average of the rotationCenterOffset for all
        % stationary trials.
        rotationCenterOffsetTmp = nanmean(imregVars.rotationCenterOffset(1:i, :));
        
        if any(isnan(rotationCenterOffsetTmp)); rotationCenterOffsetTmp=[0, 0]; end
        
        im = shiftStack(im, -round(rotationCenterOffsetTmp)); %imtranslate.

        % Derotate images using a line by line derotation.
        imDerot = derotateLines(im, angles(ii:ie), meta2P.ypixels);
        sampleOffset = estimateAngularSamplingOffset(imDerot, angles(ii:ie), sessionRef);
        sampleOffset = 0;
        sessionRefSmall = imcropcenter(sessionRef, imSizeSmall);
        % Note: Sometimes, the rigid aligning before finding the
        % sampleOffset is good, other times it is not.
        
% % %         % Crop center to make a small stack and do rigid aligning
% % %         [~, ~, ncShifts] = rigid( imcropcenter(imDerot, imSizeSmall), sessionRefSmall);
% % %         frameShifts = fliplr(squeeze(cat(1, ncShifts.shifts)));
% % %         imrig1 = applyFrameShifts(imDerot, round(frameShifts));
                
        % Find angular delay. Sometimes there seems to be a variable offset
        % or delay between the angular samples and the actual angular
        % position of the image. Crop images and look for the delay.
% % %         imrig1 = imcropcenter(imrig1, imSize);
% % %         sampleOffset = estimateAngularSamplingOffset(imrig1, angles(ii:ie), sessionRef);
        imregVars.angularSamplingDelay(i) = sampleOffset;
         
        % Second rotation to correct for the angular offset 
        shiftedAngles = shiftvector(angles(ii:ie), sampleOffset);
        thetacorrection = angles(ii:ie) - shiftedAngles;
        imDerot = rotateStack(imDerot, thetacorrection, true);
        
        % Crop center again and redo the rigid...
        tmpImSmall = imcropcenter(imDerot, imSizeSmall);
        
        % Align rigidly
        [imrig, ~, ncShifts, ncOptions] = rigid(tmpImSmall, sessionRefSmall);
        imregVars.rigidShifts(ii:ie, :) = fliplr(squeeze(cat(1, ncShifts.shifts)));
        imrig = removeDarkPixels(imrig, mean(imregVars.cLimDoubleZero5(ii:ie, :)));

        % Find the drift.
        subRefSmall = mean(imrig, 3);
        [~, ~, ncShiftsSubStack, ~] = rigid(subRefSmall, sessionRefSmall);
        imregVars.imageDrift(i, :) = fliplr(squeeze(ncShiftsSubStack.shifts)');

        % Add together individual frame shifts and substack frame shifts.
        ncShifts = addShifts(ncShifts, ncShiftsSubStack);

        % Call normcorres apply_shift function do subpixel shifts.
        ncOptions.d1 = size(imDerot, 1); ncOptions.d2 = size(imDerot, 2);
        ncOptions.grid_size = [ncOptions.d1, ncOptions.d2, 1];
        imRigid = apply_shifts(imDerot, ncShifts, ncOptions);
        
        % Do a final step off fft rigid rotation correction.
        
        % Find size of maximum shifts and crop images based on this value
        % to avoid black borders jumping in and out of the frame.
        shifts = squeeze(cat(1, ncShifts.shifts));
        maxShift = max(abs(shifts(:))) + max(abs(rotationCenterOffsetTmp));
        cropSize = imSize - repmat(ceil(maxShift)*2, 1, 2);
        tmpcropped = imcropcenter(imRigid, cropSize);
        refcropped = imcropcenter(sessionRef, cropSize);
        
        if options.correctRotation
            % Find frame by frame rotation corrections.
            [ corrections ] = findRotationOffsetsFFT( tmpcropped, [], refcropped );
    %         imviewer(cat(3, tmpcropped, refcropped))
    %         corrections = sgolayfilt(corrections, 3, 11); % Should they be
    %         smoothed??

            tmpcropped = rotateStack(tmpcropped, corrections);
        else
            corrections = zeros(size(tmpcropped, 3), 1);
        end
        
        tmpcroppedMean = mean(tmpcropped, 3);
        clearvars tmpcropped
        [ subStackCorr ] = findRotationOffsetsFFT( tmpcroppedMean, [], refcropped );
        subStackCorr=0;
        corrections = thetacorrection + corrections + subStackCorr;
        imregVars.angularCorrections(ii:ie) = corrections;
        
%         im2 = rotateStack(im, corrections);
        
        % Derotate images using a line by line derotation, as a final step.
        imDerot = derotateLines(im, angles(ii:ie) + corrections, meta2P.ypixels, true, 2);  
        
        % Apply the rigid shifts.
        ncOptions.boundary = 0;
        im = apply_shifts(imDerot, ncShifts, ncOptions);
        
        % Align images non-rigidly to session reference
        imsquare = imcropcircle(imcropcenter(im, imSizeSquare));
        
        % Remove dark pixels because they will screw up the phase
        % correlation
        imsquare = removeDarkPixels(imsquare, mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        
        [~, ~, nrShifts, nrOpts] = nonrigid(imsquare, imcropcenter(sessionRef, imSizeSquare), 'finetune');
%         imviewer(cat(3, imsquare, imcropcenter(sessionRef, imSizeSquare)))
        updatedShifts = replaceGridCornerShifts(nrShifts);
        nrOpts.shifts_method = 'cubic';
        nrOpts.d1 = size(im,1); nrOpts.d2 = size(im,2);
        im = apply_shifts(im, updatedShifts, nrOpts);
        
% %         bLim = nanmean(imregVars.cLimTripleZero5);
% %         subStackFinished = imcropcircle(imcropcenter(im, imSizeSquare));
% %         
        
        trialRef = removeDarkPixels(mean(im, 3), mean(imregVars.cLimDoubleZero5(ii:ie, :)));
        refImagesPost.Data.yxn(:, :, i) = uint16(trialRef);
        
        imregVars.shiftsNcNonrigid(ii:ie) = updatedShifts;

    end
        
    tempStack.Data.yxt(:,:,ii:ie) = uint16(im);

        
    % Save dark pixel count
    darkPixels = im < min(imregVars.cLimMinMax(ii:ie, 1));
    darkPixelCount.Data.yxn(:,:,i) = single(sum(darkPixels, 3));
    
    % Save FOV image
    if i == 1
        fovImage = single(refImagesPost.Data.yxn(:, :, 1));
        bLims = prctile(fovImage(:), [0.05, 100-0.05]);
        fovImage = makeuint8(fovImage, bLims);
        imwrite(fovImage, filePaths.FovOrig, 'Tiff')
        imwrite(imcropcenter(fovImage, imSizeSquare), filePaths.FovSquare, 'Tiff')
    end
    
    if any(rotating ~= 0)
        subStackFinished = imcropcircle(imcropcenter(im, imSizeSquare));
    else
        subStackFinished = imcropcenter(im, imSizeSquare);
    end
    
%     clims = nanmean(imregVars.cLimDoubleZero5(1:ie, :));
%     corrStack.Data.yxn(:,:,ii:ie) = uint8((subStackFinished-clims(1))./diff(clims).*255);

    % Create binned average stack;
    
    % Ad hoc solution since last frame is not part of binInd...
    if ie > binInd(end); ie = binInd(end); end
    
    [firstI, firstJ] = find(binInd == ii);
    [lastI, lastJ] = find(binInd == ie);
    
    if firstJ == lastJ
        imIndHead = (binInd(firstI, firstJ):binInd(lastI, firstJ)) - ii+1;
        imIndBody = [];
        imIndTail = [];
    else    
        imIndHead = (binInd(firstI, firstJ):binInd(binSize, firstJ)) - ii+1;
        imIndBody = binInd(1:binSize, firstJ+1:lastJ-1) - ii+1;
        imIndTail = (binInd(1, lastJ):binInd(lastI, lastJ)) - ii+1;
    end
    

    if isempty(imIndBody) && ~isempty(imIndHead)
        bavgHead = makeuint8(mean(subStackFinished(:, :, imIndHead) , 3), binAvgBLim);
        mavgStack.Data.yxn(:, :, firstJ) = mavgStack.Data.yxn(:, :, firstJ) + uint8(single(bavgHead) .* numel(imIndHead) ./ binSize);
    elseif ~isempty(imIndBody) && ~isempty(imIndHead) && ~isempty(imIndTail)
        bavgBody = squeeze(mean(reshape(subStackFinished(:, :, imIndBody), imSizeSquare(1), imSizeSquare(2), binSize, []) , 3));

        % Update brightness limits
%         nFramesProcessed = sum(trialStop(1:i)-trialStart(1:i)) + i;
%         weight = (ie-ii+1) ./ nFramesProcessed;
%         binAvgBLim = binAvgBLim .* (1-weight) + findBrightnessLimits(bavgBody) .* weight;
        
        imregVars.bAvgBLim(i,:) = findBrightnessLimits(bavgBody);
        if i == 1
            binAvgBLim = imregVars.bAvgBLim(i,:);
        else
            binAvgBLim = mean(imregVars.bAvgBLim(1:i,:));
        end

        bavgHead = makeuint8(mean(subStackFinished(:, :, imIndHead) , 3), binAvgBLim);
        bavgTail = makeuint8(mean(subStackFinished(:, :, imIndTail) , 3), binAvgBLim);

        mavgStack.Data.yxn(:, :, firstJ) = mavgStack.Data.yxn(:, :, firstJ) + uint8(single(bavgHead) .* numel(imIndHead) ./ binSize);
        mavgStack.Data.yxn(:, :, firstJ+1:lastJ-1) = makeuint8(bavgBody, binAvgBLim);
        mavgStack.Data.yxn(:, :, lastJ) = mavgStack.Data.yxn(:, :, lastJ) + uint8(single(bavgTail) .* numel(imIndTail) ./ binSize);
    end
    
    % Save avg and max projection image
    meanTmp = imcropcenter(mean(subStackFinished, 3), [300,300]);
    minVal = min(meanTmp(:));
    maxVal = max(meanTmp(:));
    
    avgProj.Data.yxn(:,:,i) = uint8((mean(subStackFinished, 3)-minVal)./(maxVal-minVal).*255);
    subStackFinished = okada(subStackFinished, 3);
    if size(subStackFinished,3) > 3; subStackFinished = subStackFinished(:,:,2:end-1); end
    maxTmp = imcropcenter(max(subStackFinished, [], 3), [300,300]);
    minVal = min(maxTmp(:));
    maxVal = max(maxTmp(:));
    maxProj.Data.yxn(:,:,i) = uint8((max(subStackFinished, [], 3)-minVal)./(maxVal-minVal).*255);
        
    imregVars.isPartFinished(i) = true;
    save(filePaths.RegVar, 'imregVars')

end

fprintf('\n')

% Create a tiff file with max and avg for each part, sorted chronologically
[~, trialInd] = sort(trialStart);

avgProjIm = avgProj.Data.yxn(:,:,:);
avgProjIm = avgProjIm(:,:,trialInd);
maxProjIm = maxProj.Data.yxn(:,:,:);
maxProjIm = maxProjIm(:,:,trialInd);

avgProjTifPath = strrep(filePaths.AvgProj, '.raw', '.tif');
maxProjTifPath = strrep(filePaths.MaxProj, '.raw', '.tif');

mat2stack(avgProjIm, avgProjTifPath)
mat2stack(maxProjIm, maxProjTifPath)

% Get path to session folder and run the postprocessing of images.
% [mFolder, sFolder] = getMouseAndSessionFolderName(recordingPath);
% sessionFolder = getSessionFolder(options.saveDirPath, mFolder, sFolder);

fclose('all');

if ~nargout
    clearvars options
end

end


function filePaths = getFilePaths(options)

    % Assign output
    filePaths = struct;
    
    % Check if recordingpath contains the filename
    if ~contains(options.recordingPath, '.raw')
        listing = dir(fullfile(options.recordingPath, '*.raw'));
        rawfileName = listing(1).name;
        
        if numel(listing)>1
            warning(['Found more than one source file when allocating', ...
                  'raw files. Chose the first one to use for filenaming'])
        end
        
    else
        [recordingPath, rawfileName] = fileparts(options.recordingPath);
    end
    
    % Create folder for aligned images.
    savePath = options.saveDirPath;
    if ~exist(savePath, 'dir'); mkdir(savePath); end
    
    baseFileName = rawfileName(19:end);
    
    % Create filename for temp file
    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-temp.raw');
    filePaths.Temp = fullfile(savePath, 'calcium_images_temp', fileName);
    
%     % Create filename for corrected file.
    fileName = strrep(baseFileName, 'XYT.raw', 'imdata_corr.tif');
    filePaths.Corr = fullfile(savePath, 'calcium_images_aligned', fileName);
    
    % Create filename for moving average file.
    fileName = strrep(baseFileName, 'XYT.raw', 'imdata_binavg.raw');
    filePaths.Mavg = fullfile(savePath, 'calcium_images_temp', fileName);
    
    % Create filename for file containing variables from the aligning
    fileName = strrep(baseFileName, 'XYT.raw', 'imreg_variables.mat');
    filePaths.RegVar = fullfile(savePath, 'imreg_data', fileName);
    
    % Create filenames for referenceImages
    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-ref_images.raw');
    filePaths.RefImages1 = fullfile(savePath, 'imreg_data', fileName);
    
    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-ref_images_post.raw');
    filePaths.RefImages2 = fullfile(savePath, 'imreg_data', fileName);
    
    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-dark_pixel_count.raw');
    filePaths.DarkPixel = fullfile(savePath, 'imreg_data', fileName);
    
    fileName = strrep(baseFileName, 'XYT.raw', 'file_info.mat');
    filePaths.fileInfo = fullfile(savePath, 'metadata', fileName);
    
    fileName = strrep(baseFileName, 'XYT.raw', 'options.mat');
    filePaths.options = fullfile(savePath, 'imreg_data', fileName);
    
    % Create filenames for avg and max projections stacks
    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-avg_projections.raw');
    filePaths.AvgProj = fullfile(savePath, 'imreg_data', fileName);

    fileName = strrep(baseFileName, 'XYT.raw', 'XYT-max_projections.raw');
    filePaths.MaxProj = fullfile(savePath, 'imreg_data', fileName);
    
    % Create filenames for fov images
    fileName = strrep(baseFileName, 'XYT.raw', 'fov_orig.tif');
    filePaths.FovOrig = fullfile(savePath, 'fov_image', fileName);
    
    fileName = strrep(baseFileName, 'XYT.raw', 'fov_square.tif');
    filePaths.FovSquare = fullfile(savePath, 'fov_image', fileName);
    
end


function mmf = allocateRawFile(filePath, stackSize, className)
    
    % Create file if it does not exist
    if ~exist(filePath, 'file')
        fileId = fopen(filePath, 'w');
    
        nFrames = stackSize(3);
        
        % Write "empty" data to the file
        batchSize = 1000;
        for i = 1:batchSize:nFrames
            
            if i == 1
                mockdata = zeros([stackSize(1:2), batchSize], className);
            end
            
            if i + batchSize >= nFrames
                mockdata = mockdata(:, :, 1:(nFrames-i)+1);
            end

            fwrite(fileId, mockdata, className);
        end

        % Close the file
        status = fclose(fileId);
        if status == 0
            [~, fileName] = fileparts(filePath);
%             fprintf('File "%s" created successfully.\n', fileName )
        end
    end
    
    % Memory map the file (newly created or already existing)
    mmf = memmapfile( filePath, 'Writable', false, ...
                      'Format', {className, stackSize, 'yxn'} );
    % todo: Change writable to true!
end


function imregVars = initializeImregVariables(nFrames, nParts)

    imregVars = struct;
    imregVars.bidirOffset = zeros(nFrames, 1);
    imregVars.cLimMinMax = nan(nFrames, 2);
    imregVars.cLimDoubleZero5 = nan(nFrames, 2);
    imregVars.cLimTripleZero5 = nan(nFrames, 2);
    imregVars.angularPosition = zeros(nFrames, 1);
    imregVars.isFrameRotating = false(nFrames, 1);
    imregVars.rigidShifts = zeros(nFrames, 2);
    imregVars.rmsMovement = zeros(nFrames, 1);
    imregVars.angularCorrections = zeros(nFrames, 1);
    imregVars.rotationOffset = zeros(nFrames, 1);
    imregVars.shiftsNcRigid = struct('shifts', [], 'shifts_up', [], 'diff', []);
    imregVars.shiftsNcNonrigid = struct('shifts', [], 'shifts_up', [], 'diff', []);
    imregVars.isFrameSavedTemp = false(nFrames, 1);
    imregVars.isFrameSavedCorr = false(nFrames, 1);
    imregVars.isFrameSavedMavg = false(nFrames, 1);
    
    imregVars.imageDrift = nan(nParts, 2);
    imregVars.rotationCenterOffset = nan(nParts, 2);
    imregVars.angularSamplingDelay = nan(nParts, 1);
    imregVars.bAvgBLim = zeros(nParts, 2);
    imregVars.isPartFinished = false(nParts, 1);
    

end


function [angles, rotating] = loadFrameRotations(recordingPath)
    
    try
        tdmsListing = dir(fullfile(recordingPath, '*theta_frame.tdms'));
        tdmsLoadExpr = 'loadTDMSdata(fullfile(recordingPath, tdmsListing(1).name), {"Theta_Frame"})';
        [T, tdmsData] = evalc(tdmsLoadExpr);
        thetaFrames = tdmsData.ThetaFrame;
        angles = -thetaFrames;
        rotating = vertcat(0, abs(diff(thetaFrames)) > 0.1 );
        rotating = imdilate(rotating, [1;1;1]);
    catch
        [mFolder, sFolder] = getMouseAndSessionFolderName(recordingPath);
        propath = settings.getDefaultPaths('DropBox');
        propath = fullfile(propath, 'Eivind Hennestad', 'PROCESSED');
        sdatapath = fullfile(propath, mFolder, sFolder, 'timeseries');
        
        listing = dir(fullfile(sdatapath, '*carousel_data*'));
        S = load(fullfile(sdatapath, listing(1).name));
        angles = S.stageposition;
        rotating = S.rotating;
        
        warning('Loaded rig stageposition for recording @ %s', recordingPath)
%         [~, folder] = fileparts(recordingPath);
%         error('Did not find thetaFrames for %s', folder)
    end
    
    % Check if there are the same number of angular samples
    S = getSciScanVariables(recordingPath, {'no.of.frames.acquired'});
    nFrames = S.noofframesacquired;
    
    % Make sure angular vector is the same length as number of images.
    nAngles = numel(angles);
    if nAngles < nFrames
        angles = cat(1, angles, angles((end-(nFrames-nAngles)+1):end));
        rotating = cat(1, rotating, rotating((end-(nFrames-nAngles)+1):end));
    elseif nAngles > nFrames
        angles = angles(1:nFrames);
        rotating = rotating(1:nFrames);
    end

end


function ncShifts = addShifts(ncShifts, ncShiftsStack)
    for k = 1:numel(ncShifts)
        ncShifts(k).shifts(:,:,:,1) = ncShifts(k).shifts(:,:,:,1) + ncShiftsStack.shifts(1);
        ncShifts(k).shifts_up(:,:,:,1) = ncShifts(k).shifts_up(:,:,:,1) + ncShiftsStack.shifts_up(1);
        
        ncShifts(k).shifts(:,:,:,2) = ncShifts(k).shifts(:,:,:,2) + ncShiftsStack.shifts(2);
        ncShifts(k).shifts_up(:,:,:,2) = ncShifts(k).shifts_up(:,:,:,2) + ncShiftsStack.shifts_up(2);
    end  
end


function options = getAllOptions(options, recordingPath)
    
    options.recordingPath = recordingPath;

    options.MovingAvgBinsize = 15;
    options.BidirBatchSize = 100;
    
    if ~isfield(options, 'redoAligning')
        options.redoAligning = false;
    end
    

    if ~isfield(options, 'selectedRegMethod')
        options.selectedRegMethod = 'nonrigid';
    end
    
    if ~isfield(options, 'nFlybackLines')
        options.nFlybackLines = 8;
    end
    
    if ~isfield(options, 'correctRotation')
        options.correctRotation = false;
    end

    
    if ~isfield(options, 'saveDirPath') || isempty(options.saveDirPath)
        parentDirs = strsplit(recordingPath, filesep);
        if isempty(parentDirs{1})
            parentDirs{1} = filesep;
        end
        
        % Find username of current user
        if isunix
            [~, username] = system('whoami');
            username = username(1:end-1); % remove new-line char at end
        elseif ispc
            username = getenv('USERNAME');
        else
            username = 'unknown';
        end
        
        switch username
            case {'Tekla'}
                options.saveDirPath = fullfile(parentDirs{1:end-2}, 'PROCESSED');
            case 'labuser'
                options.saveDirPath = fullfile(parentDirs{1:end-3}, 'PROCESSING');
            case 'eivinhen'
                options.saveDirPath = fullfile(parentDirs{1:end-4}, 'PROCESSED');
            otherwise
                options.saveDirPath = fullfile(parentDirs{1:end-4}, 'PROCESSED');
        end
        
        % Get path to session folder. Will be created if it does not exist.
        [mFolder, sFolder] = getMouseAndSessionFolderName(parentDirs{end});
        options.saveDirPath = getSessionFolder(options.saveDirPath, mFolder, sFolder);

    end
    
    createSessionFolderTree(options.saveDirPath)
end


function [mFolder, sFolder] = getMouseAndSessionFolderName(recordingName)

    % Find session id in recordingName
    sessionID = strfindsid(recordingName);
    
    % Find mouse number in recordingName
    mouseNum = regexp(sessionID, 'm\d{4}', 'match', 'once');
    
    if isempty(mouseNum)
        mFolder = 'other';
    else
        mFolder = strrep(mouseNum, 'm', 'mouse');
    end


    if isempty(sessionID)
        sFolder = recordingName(1:end-8);
    else
        sFolder = strcat('session-', sessionID);
    end

end


function sessionFolderPath = getSessionFolder(savePath, mFolder, sFolder)

    subFolders = strcat({mFolder, sFolder}, '*');

    doCreate = false;
    
    searchPath = savePath;
    for i = 1:numel(subFolders)
        listing = dir(fullfile(searchPath, subFolders{i}));
        if isempty(listing)
            doCreate = true;
            subFolders{i} = strrep(subFolders{i}, '*', '');
        else
            subFolders{i} = listing(1).name;
            searchPath = fullfile(searchPath, listing(1).name);
        end    
        
    end
    
    savePath = fullfile(savePath, subFolders{:});
        
    createSessionFolderTree(savePath)
    
    sessionFolderPath = savePath;
    
end


function createSessionFolderTree(sessionFolderPath)
    if ~exist(sessionFolderPath, 'dir'); mkdir(sessionFolderPath); end
    
    subfolders = {'calcium_images_aligned', 'calcium_images_temp', ...
        'imreg_data', 'average_images', 'metadata', 'fov_image'};
    
    for i = 1:numel(subfolders)
        subfolderPath = fullfile(sessionFolderPath, subfolders{i});
        if ~exist(subfolderPath, 'dir'); mkdir(subfolderPath); end
    end

end
