function filtS = processImageUsingPyradiomics(planC,strName,filtType,paramS)
%processImageUsingPyradiomics
% AI 06/12/2020

%% Get scan & mask
indexS = planC{end};

if ~isempty(strName)
    strC = {planC{indexS.structures}.structureName};
    strNum = getMatchingIndex(strName,strC,'exact');
    mask3M = getStrMask(strNum,planC);
    
    scanNum = getStructureAssociatedScan(strNum,planC);
else
    %Use entire scan
    scanNum = 1;
    mask3M = false(size(getScanArray(scanNum,planC)));
end
scan3M = double(getScanArray(scanNum,planC));
CToffset = planC{indexS.scan}(scanNum).scanInfo(1).CTOffset;
scan3M = scan3M - CToffset;

%% Get voxel size
dx = planC{indexS.scan}(scanNum).scanInfo(1).grid2Units;
dy = planC{indexS.scan}(scanNum).scanInfo(1).grid1Units;
dz = planC{indexS.scan}(scanNum).scanInfo(1).sliceThickness;
voxelSizeV = [dx,dy,dz]*10; %convert to mm

%% Apply filters

%Add python module to system path & iImport
pyModule = 'pyProcessImage';

try
    py.importlib.import_module(pyModule);
catch
    disp('Python module could not be imported, check the pyradiomics path');
end

%Write scan & mask to NRRD format
fprintf('\nWriting scan and mask to NRRD format...\n');

originV = [0,0,0];
encoding = 'raw';

mask3M = uint16(mask3M);
mask3M = permute(mask3M, [2 1 3]);
mask3M = flip(mask3M,3);

scan3M = permute(scan3M, [2 1 3]);
scan3M = flip(scan3M,3);

scanFilename = strcat(tempdir,'scan.nrrd');
scanRes = nrrdWriter(scanFilename, scan3M, voxelSizeV, originV, encoding);

maskFilename = strcat(tempdir, 'mask.nrrd');
maskRes = nrrdWriter(maskFilename, mask3M, voxelSizeV, originV, encoding);


%Call image processing fn
try
    
    filtImgPyList = py.pyProcessImage.filtImg(scanFilename, maskFilename,...
        filtType, paramS);
    filtImgC = cell(filtImgPyList);
    
    filtS = struct();
    paramC = fieldnames(paramS);
    
    for n = 1:length(filtImgC)
        %Convert python dictionary to matlab struct
        outFieldname = filtType;
        for m = 1:length(paramC)
            valV = paramS.(paramC{m});
            addStr = ['_',paramC{m},'_',num2str(valV(n))];
            outFieldname = [outFieldname,addStr];
        end
        filtS.(outFieldname) = filtImgC{n};
    end
    
catch e
    error('Feature extraction failed with message %s',e.message)
end


end
