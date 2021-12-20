function varStruct = getSciScanVariables(imFolderPath, varList)

ini_file = dir(fullfile(imFolderPath, '20*.ini'));
inifilepath = fullfile(imFolderPath, ini_file(1).name);
inistring = fileread(inifilepath);

if ~isa(varList, 'cell')
    varList = {varList};
end


for i = 1:numel(varList)
    varname = varList{i};
    matlabname = lower(varname);
    matlabname = strrep(matlabname, '.', '');
    varStruct.(matlabname) = readinivar(inistring, varname);
end

end