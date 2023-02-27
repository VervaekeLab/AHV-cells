function im = removeDarkPixels(im, bLim)

    isDarkPixel = im < bLim(1);
    
    isBorder = false(size(im));
    isBorder([1:5, end-4:end], :, :) = true;
    isBorder(:, [1:5, end-4:end], :) = true;

    % Fill holes in image due to dark pixels:
    isDarkPixelEroded = imerode(isDarkPixel, ones(3,3));
    isDarkPixelEroded(isBorder) = isDarkPixel(isBorder);

    % Erode image. Image edges are sometimes blurry, want to ignore these.
    isDarkPixel = imdilate(isDarkPixelEroded, ones(7,7));
    
    brightPixels = im(~isDarkPixel);
    
    fillRange = prctile(brightPixels(:), [5, 50]);
    
    darkPixelInd = find(isDarkPixel);
    
    fillValue = randi(round(fillRange), size(darkPixelInd));
    im(darkPixelInd) = fillValue;
end