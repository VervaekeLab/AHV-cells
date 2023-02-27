function mask = createcircularmask(frameSize, radius)

    x = frameSize(2)/2;
    y = frameSize(1)/2;

    [xx, yy] = ndgrid((1:frameSize(1)) - y, (1:frameSize(2)) - x);
    mask = (xx.^2 + yy.^2) < radius^2;
    mask = double(mask);
end