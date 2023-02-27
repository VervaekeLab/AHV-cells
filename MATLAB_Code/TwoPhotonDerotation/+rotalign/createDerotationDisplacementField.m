function D = createDerotationDisplacementField(imSize, angles, ds)
%createDerotationDisplacementField Create D for derotation using imwarp
%    D = createDerotationDisplacementField(im, angles) returns a
%    displacement field for doing line by line derotation using imwarp. 
%    im is a 2D or 3D array of image(s) and angles is a matrix of angles 
%    (nImRows x nImFrames). The size of D is (nRows, nCols, nFrames, 2), 
%    where the last two dimensions are the x- and y-displacements
%    respectively.
%
%    D = createDerotationDisplacementField(im, angles, ds) creates the
%    displacement field on a downsampled angles matrix. This increases
%    speed. Default is no downsampling.
%
%    Written by Eivind Hennestad 2019 | Vervaeke Lab   


if nargin < 3; ds = 1; end

assert(size(angles,2)==imSize(3), 'Angles input must have the same number of elements as the third dim of imSize')

% Determine size of image
imSizeOrig = imSize;

% Downsample image size and angles.
imSize = round(imSizeOrig ./ ds);

if mod(imSizeOrig(1), ds) == 0 
    angles = angles(1:ds:end, :);
else
    anglesDs = zeros(imSize(1), imSizeOrig(3));
    for n = 1:imSizeOrig(3)
        anglesDs(:,n) = linspace(angles(1, n), angles(end,n), imSize(1));
    end
    angles = anglesDs;
end


imCenter = mean([1, imSize(1); 1, imSize(2)], 2);

% Create a grid of original x and y coordinates.
[yy1, xx1] = ndgrid((1:imSize(1)) - imCenter(1), (1:imSize(2)) - imCenter(2));

% Flip y coordinates from image coordinates to cartesian coordinates
% yy1 = flipud(yy1);

% Find the polar coordinates of each pixel
[theta, rho] = cart2pol(xx1, yy1);

% Find old and new indices of each image pixel.
[row, col] = ndgrid(1:imSize(1), 1:imSize(2));

% Make sure angles is a column vector, because angular displacement should
% be applied row by row.
% if isrow(angles)
%     angles = angles';
% end

% NB! Angles need to be inverted if using the scatterInterpolant method. No
% idea why. This comment makes so sense here....

angles = flipud(angles);

D = zeros([imSizeOrig, 2]);

for i = 1:imSizeOrig(3)
    
    % % One angle per line in image, expand to array of same size as image.
    dtheta = repmat(deg2rad(angles(:,i)), 1, imSize(2));
    
    thetaNew = theta + deg2rad(angles(:,i));

    % Convert back to cartesian coordinates
    [xx2, yy2] = pol2cart(thetaNew, rho);

    % Calculate shifts for each image pixel
% %     shiftX = xx2 - xx1;
% %     shiftY = yy2 - yy1;

    % Find pixel coordinates from the cartesian coordinates.
    xx2im = xx2 + imCenter(2); % shift right
    yy2im = imSize(1) - (yy2 + imCenter(1)) + 1; % Shift up and reverse

    % Find linear indices of initial (old) pixel coordinates
    oldIND = sub2ind(imSize(1:2), row(:), col(:));

    % Ignore pixel indices which have been shifted outside of image boundary.
    valid = yy2im(:) >= 1 & yy2im(:) <= imSize(1) & xx2im(:) >= 1 & xx2im(:) <= imSize(2);
    yy2im(~valid) = 1;
    xx2im(~valid) = 1;

    % Find linear indices of shifted (new) pixel coordinates
    newIND = sub2ind(imSize(1:2), round(yy2im(:)), round(xx2im(:)));

    dthetaInv = zeros(imSize(1:2));
    dthetaInv(newIND) = -dtheta(oldIND);
    
    % Find missing shift values.
    dthetaInv(1,1) = nan;
    dthetaInv(dthetaInv == 0) = nan;
    
    
    % For angles close to 0 or 90, there might be many missing values on
    % the horizontal or vertical. Use fillmissing along the dimension which
    % is opposite. I only checked a few examples, so I dont know if this
    % will always work..
    
    if ds > 1
        %  Using linear interpolation would be more robust, but is slower.
        dthetaInv = fillmissing(dthetaInv, 'linear');
    else
        % This does not work when downsampling
        meanAngle = rad2deg(dthetaInv(round(imCenter(1)), round(imCenter(2))));
        if abs( round(mod(meanAngle,180) - 90) ) < 45 % Closer to 90. Fill horz
            dthetaInv = fillmissing(dthetaInv, 'movmean', 3, 2, 'EndValues', 'none');
        else % Closer to horizontal, fill missing along vertical dimension.
            dthetaInv = fillmissing(dthetaInv, 'movmean', 3, 1, 'EndValues', 'none');
        end
    end


    
    [xx2, yy2] = pol2cart(theta-dthetaInv, rho);
    
    D(:,:,i,1) = imresize( (xx2-xx1)*ds, imSizeOrig(1:2));
    D(:,:,i,2) = imresize( (yy2-yy1)*ds, imSizeOrig(1:2));

    
% % % % Older implementation. Slower because fillmissing is called twice.
    
% %     
% %     % Initialize Dx and Dy.
% %     Dx = zeros(imSize(1:2));
% %     Dy = zeros(imSize(1:2));
% % 
% %     Dx(newIND) = -shiftX(oldIND);
% % 
% %     % Create a mask representing area outside the image borders of warped image.
% % %     BW = Dx ~= 0;
% % %     BW = imdilate(BW, ones(3,3));
% % %     BW = imerode(BW, ones(3,3));
% % 
% %     % Find missing shift values.
% %     Dx(1,1) = nan;
% %     Dx(Dx == 0) = nan;
% % 
% %     % Using movmean instead of linear interpolation is faster.
% % 
% %     % Dx = fillmissing(Dx, 'linear', 'EndValues', 'none'); %, 'movmean', 3);
% %     Dx = fillmissing(Dx, 'movmean', 3, 'EndValues', 'none'); %, );
% % 
% %     % Dx = inpaint_nans(Dx);
% % 
% %     Dy(newIND) = shiftY(oldIND);
% %     Dy(1,1) = nan;
% %     Dy(Dy == 0) = nan;
% % 
% %     % Dy = fillmissing(Dy, 'linear', 'EndValues', 'none'); %, 'movmean', 3);
% %     Dy = fillmissing(Dy, 'movmean', 3, 'EndValues', 'none'); %, );
% % 
% %     % Dy = inpaint_nans(Dy);
% % 
% %     % Put Dx and Dy into displacement matrix:
% % %     D = cat(3, Dx, Dy); % Displacement field...
% %     
% %     D(:,:,i,1)=Dx;
% %     D(:,:,i,2)=Dy;

    
end

D(isnan(D))=0;
% D = imresize(D*ds, imSizeOrig(1:2));

end