clc;
clear;
close all;

%% AUTOMATIC GEAR ERROR DETECTION SYSTEM
% This program uses MATLAB image processing to detect and analyze
% gear dimensions and number of teeth.
%
% Processing stages:
% 1. Read gear image
% 2. Convert to grayscale
% 3. Remove noise using median filtering
% 4. Otsu thresholding
% 5. Segment the gear
% 6. Find centroid
% 7. Measure inner and outer diameter
% 8. Estimate number of teeth
% 9. Calculate PCD and module
% 10. Display the result

%% Step 1: Load Input Gear Image

img = imread('gear.jpg');

figure;
imshow(img);
title('Input Gear Image');

%% Step 2: Convert RGB Image to Grayscale

if size(img,3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end

%% Step 3: Remove Noise Using Median Filter

denoised = medfilt2(gray,[3 3]);

figure;
subplot(1,2,1);
imshow(gray);
title('Input Image');

subplot(1,2,2);
imshow(denoised);
title('Denoised Image');

%% Step 4: Otsu Thresholding

level = graythresh(denoised);

binaryImage = im2bw(denoised,level);

% Make sure the gear is white and background is black
if mean(binaryImage(:)) > 0.5
    binaryImage = ~binaryImage;
end

figure;
subplot(1,2,1);
imshow(binaryImage);
title('Otsu Image');

%% Step 5: Remove Small Objects

binaryImage = bwareaopen(binaryImage,50);

% Fill small holes inside the gear
binaryImage = imfill(binaryImage,'holes');

%% Step 6: Select the Largest Object

cc = bwconncomp(binaryImage);

if cc.NumObjects == 0
    error('No gear was detected in the image.');
end

stats = regionprops(cc,'Area');

areas = [stats.Area];
[~,largestIndex] = max(areas);

gear = false(size(binaryImage));
gear(cc.PixelIdxList{largestIndex}) = true;

%% Display Segmented Gear

subplot(1,2,2);
imshow(gear);
title('Segmented Gear');

%% Step 7: Find Gear Centroid

statsGear = regionprops(gear,'Centroid','BoundingBox','Area');

centroid = statsGear.Centroid;

figure;
imshow(gear);
hold on;

plot(centroid(1),centroid(2),'r+','MarkerSize',15,'LineWidth',2);

title('Gear Centroid');
hold off;

%% Step 8: Measure Outer Diameter

% Calculate distance from centroid to every gear pixel.
[y,x] = find(gear);

distance = sqrt((x-centroid(1)).^2 + ...
                (y-centroid(2)).^2);

outerRadiusPixels = max(distance);
outerDiameterPixels = 2 * outerRadiusPixels;

%% Step 9: Measure Inner Diameter

% The center hole is represented by the background inside the gear.
holeMask = ~gear;

% Find connected components in the inverted image.
ccHole = bwconncomp(holeMask);

holeStats = regionprops(ccHole,'Area','Centroid','EquivDiameter');

% Find a component close to the gear centroid.
innerDiameterPixels = NaN;

for k = 1:length(holeStats)

    holeCentroid = holeStats(k).Centroid;

    centroidDistance = sqrt( ...
        (holeCentroid(1)-centroid(1))^2 + ...
        (holeCentroid(2)-centroid(2))^2 );

    if centroidDistance < 10
        innerDiameterPixels = holeStats(k).EquivDiameter;
        break;
    end
end

%% Step 10: Pixel-to-Millimetre Calibration

% IMPORTANT:
% This is an example calibration value.
% Change this value according to your camera setup/calibration.

mmPerPixel = 0.35;

outerDiameter = outerDiameterPixels * mmPerPixel;

if isnan(innerDiameterPixels)
    innerDiameter = NaN;
else
    innerDiameter = innerDiameterPixels * mmPerPixel;
end

%% Step 11: Estimate Number of Teeth

% Create a radial distance profile around the centroid.

theta = 0:1:359;

radialDistance = zeros(size(theta));

for k = 1:length(theta)

    angle = theta(k) * pi / 180;

    % Search outward from centroid
    maxRadius = floor(min(size(gear))/2);

    for r = 1:maxRadius

        xx = round(centroid(1) + r*cos(angle));
        yy = round(centroid(2) + r*sin(angle));

        if xx < 1 || yy < 1 || ...
           xx > size(gear,2) || yy > size(gear,1)

            break;
        end

        if gear(yy,xx) == 0
            break;
        end

        radialDistance(k) = r;
    end
end

% Smooth radial profile
radialDistanceSmooth = smooth(radialDistance,9);

%% Find Local Peaks

% A tooth generally produces a local maximum in the radial profile.

peaks = [];

for k = 2:length(radialDistanceSmooth)-1

    if radialDistanceSmooth(k) > radialDistanceSmooth(k-1) && ...
       radialDistanceSmooth(k) >= radialDistanceSmooth(k+1)

        peaks = [peaks k];
    end
end

% Remove peaks that are too close to each other.
% This prevents multiple detections of the same tooth.

minimumPeakDistance = 10;

selectedPeaks = [];

for k = 1:length(peaks)

    if isempty(selectedPeaks)

        selectedPeaks = peaks(k);

    else

        circularDistance = abs(peaks(k)-selectedPeaks(end));

        if circularDistance >= minimumPeakDistance
            selectedPeaks = [selectedPeaks peaks(k)];
        end
    end
end

numberOfTeeth = length(selectedPeaks);

%% Step 12: Calculate Pitch Circle Diameter

% Approximate PCD using the measured outer and inner diameters.

if ~isnan(innerDiameter)

    PCD = (outerDiameter + innerDiameter) / 2;

else

    PCD = NaN;

end

%% Step 13: Calculate Module

if numberOfTeeth > 0 && ~isnan(PCD)

    moduleValue = PCD / numberOfTeeth;

else

    moduleValue = NaN;

end

%% Step 14: Calculate Tooth Height

if ~isnan(innerDiameter)

    toothHeight = (outerDiameter - innerDiameter) / 2;

else

    toothHeight = NaN;

end

%% Step 15: Display Cropped Gear With Centroid

figure;

imshow(gear);
hold on;

plot(centroid(1),centroid(2),'r+','MarkerSize',15,'LineWidth',2);

title('Cropped Gear Image with Centroid');

hold off;

%% Step 16: Display Radial Profile

figure;

plot(theta,radialDistanceSmooth);

xlabel('Angle (degrees)');
ylabel('Radius (pixels)');
title('Gear Radial Profile');
grid on;

%% Step 17: Display Measurements

fprintf('\n');
fprintf('=============================================\n');
fprintf('     AUTOMATIC GEAR ERROR DETECTION SYSTEM\n');
fprintf('=============================================\n');

fprintf('Inner Diameter value: %.2f mm\n',innerDiameter);
fprintf('Outer Diameter value: %.2f mm\n',outerDiameter);
fprintf('No of Teeth: %d\n',numberOfTeeth);
fprintf('Tooth Height: %.2f mm\n',toothHeight);
fprintf('PCD: %.2f mm\n',PCD);
fprintf('Module: %.2f mm\n',moduleValue);

fprintf('=============================================\n');

%% Step 18: Gear Defect Decision

% Example reference values based on the project prototype.
% These values can be changed according to the required gear.

referenceOuterDiameter = 28;
referenceInnerDiameter = 24;
referenceTeeth = 10;

diameterTolerance = 2;
teethTolerance = 1;

outerDiameterOK = abs(outerDiameter-referenceOuterDiameter) ...
                  <= diameterTolerance;

innerDiameterOK = abs(innerDiameter-referenceInnerDiameter) ...
                  <= diameterTolerance;

teethOK = abs(numberOfTeeth-referenceTeeth) ...
          <= teethTolerance;

if outerDiameterOK && innerDiameterOK && teethOK

    fprintf('Gear Status: NON-DEFECTIVE\n');

else

    fprintf('Gear Status: DEFECTIVE\n');

end

fprintf('=============================================\n');
