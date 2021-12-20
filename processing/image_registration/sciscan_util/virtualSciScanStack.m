classdef virtualSciScanStack < handle
% Todo: Subclass from twophoton recording & virtualStack
%
    
properties
    filepath
    metadata
    imsize
    M
    channel = 1
    numChannels = 1
end


methods
    
    function obj = virtualSciScanStack(folderPath)
        
        if nargin < 1; folderPath = uigetdir; end
       
        % Find fileName from folderPath
        if contains(folderPath, '.raw')
            [folderPath, fileName, ext] = fileparts(folderPath);
            fileName = strcat(fileName, ext);
        elseif contains(folderPath, '.ini')
            [folderPath, fileName, ~] = fileparts(folderPath);
            fileName = strcat(fileName, '.raw');
        else
            listing = dir(fullfile(folderPath, '*.raw'));
            fileName = listing(1).name;
        end
        
        if isempty(fileName) 
            error('Did not find raw file in the specified folder')
        end
        
        % Create a memory map from the file
        meta2P = getSciScanMetaData(folderPath);
        obj.imsize = [meta2P.xpixels, meta2P.ypixels, meta2P.nChannels, meta2P.nFrames];
        obj.metadata = meta2P;
        
        filePath = fullfile(folderPath, fileName);
        obj.M = memmapfile(filePath, 'Format', {'uint16', obj.imsize, 'xyn'});
        
    end
    
    
    function data = subsref(obj, s)
        
        errmsg = 'Unsupported indexing reference for a SciScanVirtualStack';
        assert(numel(s)==1, errmsg)
        
        switch s.type
            
            % Use builtin if a property is requested.
            case '.'
                data = builtin('subsref', obj, s);
                return
                
            % Return image data if (yInd, xInd, frInd) is used for 
            % indexing reference
            case '()'
                if isequal(s.subs, {':'}) % Return all data as 1D
                    % temp: return max 100 frames
                    IND = 1:min(100, size(obj, 3)); 
                    data = obj.M.Data.xyn(:, :, :, IND);
                    data = data(:);
                    
                elseif numel(s.subs) == 3
                    
                    if strcmp(s.subs{1}, ':')
                        s.subs{1} = 1:obj.imsize(2);
                    end
                    
                    if strcmp(s.subs{2}, ':')
                        s.subs{2} = 1:obj.imsize(1);
                    end
                            
                    if strcmp(s.subs{3}, ':')
                        s.subs{3} = 1:obj.imsize(4);
                    end
                    
                    if obj.metadata.nChannels == 1
                        s.subs{4} = s.subs{3};
                        s.subs{3} = 1;
                    elseif obj.metadata.nChannels > 1
                        s.subs{4} = s.subs{3};
                        s.subs{3} = obj.channel;
                    end
                    
                    data = obj.M.Data.xyn(s.subs{2}, s.subs{1}, s.subs{3}, s.subs{4});
                    data = permute(swapbytes(data), [2,1,3,4]);
                    data = squeeze(data);
                    
                else
                    error(errmsg)
                end
        end

    end
    
    
    function varargout = size(obj, dim)
        
        imsize = obj.imsize([2,1,4]); % y, x, nframes
        
        if nargin == 1 && (nargout == 1 || ~nargout)
            varargout{1} = imsize;
        elseif nargin == 2 && (nargout == 1 || ~nargout)
            varargout{1} = imsize(dim);
        elseif nargin == 1 && nargout > 1
            varargout = cell(1, nargout);
            for i = 1:nargout
                if i <= 3
                    varargout{i} = imsize(i);
                else
                    varargout{i} = 1;
                end
            end
        end     
    end

    
    function dataClass = class(obj)
        dataClass = obj.M.Format{1};
    end
    
%     function [S, L] = bounds(obj)
%         
%     end
    
    
    function mean(obj, dim)
        error('Mean is not yet implemented for VirtualSciScanStack')
    end
    
    
    function maxim = max(obj, dim)
        
        maxim = zeros(obj.imsize(1:2));
        
        batchSize = 2000;
        for i = 1:batchSize:batchSize*3 %obj.imsize(end)
            ii = i;
            ie = i-1+batchSize;
            if ie > obj.imsize(end)
                ie = obj.imsize(end);
            end
                        
            data = obj.M.Data.xyn(:, :, :, ii:ie);
            data = permute(swapbytes(data), [2,1,3,4]);
            data = squeeze(data);
            
            maxim=max(cat(3, maxim, max(data, [], 3)), [], 3);
        end
        
%         error('Max is not yet implemented for VirtualSciScanStack')
    end
    
    
end
    
end




% Notes:
%   VirtualStack should be an abstract class. 
%                  
%       For virtual stacks there are zstacks and timeseries
% 
%       Each acquisition software should implement each of these classes.
%       A single image / reference recording should be considered a 
%       single-plane zstack.
%
%       twophoton.sciscan.timeseries
%       twophoton.prairieview.timeseries
%       twophoton.scanimage.timeseries
% 
%       twophoton.sciscan.zstack
%       twophoton.prairieview.zstack
%       twophoton.scanimage.zstack
%
%       
%       % Properties and methods
%       
%           ? Where does processed data fit in?
%           ? What methods should be a one-time procedure




