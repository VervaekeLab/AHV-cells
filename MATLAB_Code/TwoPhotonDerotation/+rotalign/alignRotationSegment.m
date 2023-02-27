function [imArrayCorrected, summary] = alignRotationSegment(imArray, referenceImage, angularFramePosition, options)

        % Shift stack based on average of rotation center offsets before 
        % derotation. Use the average of the rotationCenterOffset for all
        % stationary trials.
        % Todo: Implement automatic detection of center of rotation offset
        
        import rotalign.utility.stack.removeDarkPixels
        import rotalign.utility.stack.imcropcenter
        import rotalign.wrapper.rigid

        options.CorrectRotation = false; % Todo...

        % Required inputs:
        frameSize  = size(imArray, [1,2]);
        frameSizeSmall = repmat( floor( sqrt(min(frameSize).^2 / 2) ), 1, 2);

        % Todo: Adjust this based on center of rotation offset and
        % alignment shifts.

        centerOfRotationOffset = options.CenterOfRotationOffset;
        imArray = rotalign.shiftStack(imArray, round(centerOfRotationOffset)); % imtranslate.


        % The first part of this function does a preliminary derotation and
        % rigid alignment. 
        
        originalLineCount = size(imArray, 1) + options.NumFlybackLines;

        % Derotate images using a line by line derotation.
        imArrayDerotFirstPass = rotalign.derotateLineByLine(imArray, angularFramePosition, originalLineCount);
        
        if isnan( options.AngularSampleOffset )
            % Find angular delay. Sometimes there seems to be a variable offset
            % or delay between the angular samples and the actual angular
            % position of the image. Try to automatically detect delay in
            % sample units.
            if false 
                % Note: Sometimes, the rigid aligning before finding the
                % sampleOffset is good, other times it is not.
                imArrayDerotFirstPass = rotalign.wrapper.rigidWithCrop(...
                    imArrayDerotFirstPass, referenceImage, frameSizeSmall);
            end
            sampleOffset = rotalign.estimateAngularSamplingOffset(imArrayDerotFirstPass, angularFramePosition, referenceImage);
        else
            sampleOffset = options.AngularSampleOffset;
        end

        summary.angularSamplingDelay = sampleOffset;
        
        % Second rotation to correct for the angular offset 
        shiftedAngles = rotalign.utility.shiftvector(angularFramePosition, sampleOffset);
        thetacorrection = angularFramePosition - shiftedAngles;
        imArrayDerotated = rotalign.rotateStack(imArrayDerotFirstPass, thetacorrection, true);
        
        % Crop center again and redo the rigid...
        tmpImSmall = imcropcenter(imArrayDerotated, frameSizeSmall);
        referenceImageSmall = imcropcenter(referenceImage, frameSizeSmall);
        
        % Align rigidly
        [imrig, ~, ncShifts, ncOptions] = rigid(tmpImSmall, referenceImageSmall);
        summary.rigidShifts = fliplr(squeeze(cat(1, ncShifts.shifts)));
        imrig = removeDarkPixels(imrig, options.BlackLevel);

        % Find the drift. Todo: Is this needed?
        subRefSmall = mean(imrig, 3);
        [~, ~, ncShiftsSubStack, ~] = rigid(subRefSmall, referenceImageSmall);
        summary.imageDrift = fliplr(squeeze(ncShiftsSubStack.shifts)');

        % Add together individual frame shifts and substack frame shifts.
        ncShifts = rotalign.addNormcorreShifts(ncShifts, ncShiftsSubStack);

        % Call normcorres apply_shift function do subpixel shifts.
        ncOptions.d1 = size(imArrayDerotated, 1); ncOptions.d2 = size(imArrayDerotated, 2);
        ncOptions.grid_size = [ncOptions.d1, ncOptions.d2, 1];
        imRigid = apply_shifts(imArrayDerotated, ncShifts, ncOptions);
        
        % Do a final step off fft rigid rotation correction.
        
        % Find size of maximum shifts and crop images based on this value
        % to avoid black borders jumping in and out of the frame.
        shifts = squeeze(cat(1, ncShifts.shifts));
        maxShift = max(abs(shifts(:))) + max(abs(centerOfRotationOffset));
        cropSize = frameSize - repmat(ceil(maxShift)*2, 1, 2);
        tmpcropped = imcropcenter(imRigid, cropSize);
        refcropped = imcropcenter(referenceImage, cropSize);
        
        if options.CorrectRotation
            % Find frame by frame rotation corrections.
            [ corrections ] = rotalign.findRotationOffsetsFFT( tmpcropped, [], refcropped );
    %         imviewer(cat(3, tmpcropped, refcropped))
    %         corrections = sgolayfilt(corrections, 3, 11); % Should they be smoothed??

            tmpcropped = rotalign.rotateStack(tmpcropped, corrections);
        else
            corrections = zeros(1, size(imArray,3) );
        end
        
        tmpcroppedMean = mean(tmpcropped, 3);
        clearvars tmpcropped
        [ subStackCorr ] = rotalign.findRotationOffsetsFFT( tmpcroppedMean, [], refcropped );
        subStackCorr=0;
        corrections = thetacorrection + corrections + subStackCorr;
        summary.angularCorrections = corrections;
        
%         im2 = rotateStack(im, corrections);
        
        % Derotate images using a line by line derotation, as a final step.
        imDerot = rotalign.derotateLineByLine(imArray, angularFramePosition + corrections, originalLineCount, true, 2);  
        
        % Apply the rigid shifts.
        ncOptions.boundary = 0;
        im = apply_shifts(imDerot, ncShifts, ncOptions);            

        

        %% Use flowregistration for a final non-rigid correction

        % Create circular mask that covers all pixels that are present
        % throughout a full rotation
        borderSize = max(centerOfRotationOffset);
        maskRadius = round( min(frameSize) / 2 - borderSize);
        weight = rotalign.createcircularmask(frameSize, maskRadius) + 0.5;
        
        % Specify some non-default options tailored to these data
        ofOptions = OF_options(...
            'alpha', 5, ...
            'weight', reshape(weight, [1, frameSize]), ...
            'buffer_size', 12 );
        
        % Run flow registration on the derotated images.
        [IM, ~] = compensate_inplace(im, single(referenceImage), ofOptions);
        
        imArrayCorrected = IM;

        trialReference = mean(imArrayCorrected, 3);
        summary.trialReference = rotalign.utility.stack.removeDarkPixels(trialReference, options.BlackLevel);
end
