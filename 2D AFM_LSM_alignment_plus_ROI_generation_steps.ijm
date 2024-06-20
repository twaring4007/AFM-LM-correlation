/*

						- Written by Thomas Waring [twaring@liverpool.ac.uk] June 2024 -
								- Liverpool CCI (https://cci.liverpool.ac.uk/) -
________________________________________________________________________________________________________________________

BSD 2-Clause License

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
*
*/

//#@ File (label="Input Directory", style="directory") Input
#@ File (label="Output Directory", style="directory") Output
#@ String (label="Cell Number", style="open") celln
#@ String (value="Please select the files you wish to process.", visibility="MESSAGE") message
#@ File (label="Young's Modulus Image", style="open") YMimage
#@ File (label="Height Image", style="open") Heightimage
#@ File (label="Pixel Difference Image", style="open") PDimage
#@ String (label = "Input file type", choices={"ASCII","TIFF"}, style="radioButtonHorizontal") input_file_type
#@ Double(label="Calibration in xy: " , value = 0.197, stepSize=0.001, persist=false) AFM_xy_scaling
#@ String(label = "Calibration unit: ", description = "nm", persist=true) AFM_calibration_unit
#@ File (label="Light Microscope Image", style="open") LMimage
#@ String (label="Cell marker channel:") cellChannel
#@ Double(label="Proportion of longest axis defined as Cell Body: " , value = 0.5, stepSize=0.01, persist=false) scale_factor
#@ String (label = "Generate AFM/LM multichannel image?", choices={"Yes","No"}, style="radioButtonHorizontal") figureNeeded


//Opening AFM images and combining them

if (input_file_type == "TIFF") {
		run("Bio-Formats Windowless Importer", "open=[" + YMimage + "]");
		YMimageTitle = getTitle();
		run("Bio-Formats Windowless Importer", "open=[" + Heightimage + "]");
		HeightimageTitle = getTitle();
		run("Bio-Formats Windowless Importer", "open=[" + PDimage + "]");
		PDimageTitle = getTitle();
		run("Enhance Contrast", "saturated=0.35");
	}
	else if (input_file_type == "ASCII") {
		run("Text Image... ", "open=[" + YMimage + "]");
		YMimageTitle = getTitle();
		run("Text Image... ", "open=[" + Heightimage + "]");
		HeightimageTitle = getTitle();
		run("Text Image... ", "open=[" + PDimage + "]");
		PDimageTitle = getTitle();
		run("Enhance Contrast", "saturated=0.35");
	}

run("Merge Channels...", "c1=" + HeightimageTitle + " c2=" + YMimageTitle + " c4=" + PDimageTitle + " create");
run("Properties...", "channels=3 slices=1 frames=1 pixel_width=" + AFM_xy_scaling + " pixel_height=" + AFM_xy_scaling + " voxel_depth=1");
Stack.setXUnit(AFM_calibration_unit);
saveAs("TIFF", Output + File.separator + "AFM_data_Cell" + celln + ".tif");
AFM_image = getTitle();

//open LM data (need to generalise channel selection for substack)

run("Bio-Formats Windowless Importer", "open=[" + LMimage + "]");
getDimensions(width, height, channels, slices, frames);
LM_slices = slices;
run("Make Substack...", "channels=1,3 slices=1-" + LM_slices);
run("Z Project...", "projection=[Max Intensity]");
LM_MAX_image = getTitle();
waitForUser("Select the frame you want for the Transmitted channel and duplicate it");
TL_image = getTitle();
run("Enhance Contrast", "saturated=0.35");
selectImage(LM_MAX_image);
run("Split Channels");
run("Merge Channels...", "c2=C1-" + LM_MAX_image + " c4=" + TL_image + " c6=C2-" + LM_MAX_image + " create");
getDimensions(width, height, channels, slices, frames);
LM_size = width;
getPixelSize(unit, pixelWidth, pixelHeight);
LM_scale = pixelWidth;
LM_scale_unit = unit;

//Orient LM data and start Bigwarp

run("Rotate 90 Degrees Left");
run("Flip Horizontally", "stack");
save(Output + File.separator + "LM_data_MAX_Cell" + celln + ".tif");
LM_MAX_image = getTitle();
run("Big Warp", "moving_image=" + LM_MAX_image + " target_image=[" + AFM_image + "] moving=[] moving_0=[] target=[] target_0=[] landmarks=[] apply");
waitForUser("Complete BigWarp alignment - Remember to save the landmarks!");
//run("Properties...", "channels=3 slices=1 frames=1 pixel_width=" + LM_scale + " pixel_height=" + LM_scale + " voxel_depth=1");
run("Duplicate...", "duplicate slices=1");
Stack.setXUnit(LM_scale_unit);
saveAs("TIFF", Output + File.separator + "LM_data_MAX_Cell" + celln + "_transformed.tif");
LM_transformed = getTitle();

//OPTIONAL - duplicate and rescale the AFM image and overlap to generate a figure image

if (figureNeeded == "Yes") {
	selectImage(LM_transformed);
	LM_transformed_name = file_name_remove_extension(LM_transformed);
	getDimensions(width, height, channels, slices, frames);
	LM_transformed_width = width;
	LM_transformed_height = height;
	selectImage(AFM_image);
	AFM_image_name = file_name_remove_extension(AFM_image);
	run("Duplicate...", "duplicate");
	run("Size...", "width=" + LM_transformed_width + " height=" + LM_transformed_height + " depth=3 average interpolation=None");
	run("Split Channels");
	selectImage(LM_transformed);
	run("32-bit");
	run("Stack to Images");
	run("Merge Channels...", "c1=C1-" + AFM_image_name + "-1.tif c2=C2-" + AFM_image_name + "-1.tif c4=" + LM_transformed_name + "-0001 c5=" + LM_transformed_name + "-0002 c6=" + LM_transformed_name + "-0003 create");
	saveAs("TIFF", Output + File.separator + "AFM_LM_merged_Cell" + celln + ".tif");
	close();
	open(Output + File.separator + "LM_data_MAX_Cell" + celln + "_transformed.tif");
}

//Take the warped LM image and process it

//get individual ROIs based on actin intensity

selectImage(LM_transformed);
run("Make Composite", "display=Composite");
LM_tranformed_name = file_name_remove_extension(LM_transformed);
run("Duplicate...", "duplicate channels=1");
run("Difference of Gaussians", "  sigma1=2 sigma2=1");
//run("Threshold...");
setAutoThreshold("Triangle dark");
setOption("BlackBackground", true);
run("Convert to Mask");
saveAs("TIFF", Output + File.separator + LM_transformed_name + "_mask.tif");
run("Analyze Particles...", "size=1-Infinity add");

number_of_ROI = roiManager("count");
//print("ROI count = " + number_of_ROI);
Rescale_ROIs(AFM_image, LM_transformed, number_of_ROI);
roiManager("Save", Output + File.separator + "Cell" + celln + "_ROIs.zip");
roiManager("Reset");
roiManager("Show None");
roiManager("Show All");

//get whole cell ROI, then define a region in the centre of the cell (using cell centre of mass as reference), then measure this area versus peripheral area

Define_Cell_Body_Periphery (LM_transformed, cellChannel, scale_factor, Output);

number_of_ROI = roiManager("count");
//print("ROI count = " + number_of_ROI);
Rescale_ROIs(AFM_image, LM_transformed, number_of_ROI);
roiManager("Save", Output + File.separator + "Cell" + celln + "_Cell_Regions_ROIs.zip");

//Reset ImageJ for next image

run("Clear Results");
roiManager("Reset");
run("Close All");

//Functions used

function file_name_remove_extension(file_name){
	dotIndex = lastIndexOf(file_name, "." ); 
	file_name_without_extension = substring(file_name, 0, dotIndex );
	//print( "Name without extension: " + file_name_without_extension );
	return file_name_without_extension;
}
	
function Rescale_ROIs(ref_image_name, to_scale_image_name, number_of_ROI){
	selectImage(ref_image_name);
	getDimensions(width, height, channels, slices, frames);
	ref_image_width = width;
	ref_image_height = height;
	selectImage(to_scale_image_name);
	getDimensions(width, height, channels, slices, frames);
	to_scale_width = width;
	to_scale_height = height;
	ROI_scale = ref_image_width/to_scale_width;
	//print("ROI scale = " + ROI_scale);
	for (i=0; i < number_of_ROI; i++) {
	roiManager("Select", i);
	roiManager("Rename", "Object_" + i);
	run("Scale... ", "x=" + ROI_scale + " y=" + ROI_scale);
	roiManager("Add");
	roiManager("Select", (roiManager("Count"))-1);
	roiManager("Rename", "Object_" + i + "_rescaled");
	}
}

function Define_Cell_Body_Periphery (cell_image, cell_marker_channel, cell_body_fraction, output) {
	run("Set Measurements...", "center feret's redirect=None decimal=3");
	selectImage(cell_image);
	run("Duplicate...", "duplicate channels=cell_marker_channel");
	run("Median...", "radius=2");
	run("Threshold...");
	setAutoThreshold("Percentile dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Fill Holes");
	waitForUser("Check cell ROI - disconnect from other cells/the edge using draw tool");
	saveAs("TIFF", Output + File.separator + LM_transformed_name + "_cell_area_mask.tif");
	run("Analyze Particles...", "size=100-Infinity exclude add");
	roiManager("Select",0);
	roiManager("Measure");
	body_diameter = getResult("Feret", 0);
	width_height = body_diameter*scale_factor;
	X = getResult("XM", 0);
	Y = getResult("YM", 0);
	X_ROI = X - (width_height/2);
	Y_ROI = Y - (width_height/2);
	//print(X_ROI);
	//print(Y_ROI);
	//print(width_height);
	run("Specify...", "width=" + width_height + " height=" + width_height + " x=" + X_ROI + " y=" + Y_ROI + " oval scaled");
	roiManager("Add");
	//roiManager("Select",1);
	//roiManager("Rename", "central oval");
	roiManager("Select", newArray(0,1));
	roiManager("AND");
	roiManager("Add");
	//roiManager("Select",2);
	//roiManager("Rename", "Cell Body");
	roiManager("Select", newArray(0,2));
	roiManager("XOR");
	roiManager("Add");
	//roiManager("Select",3);
	//roiManager("Rename", "Cell Periphery");
	//roiManager("Save", Output + File.separator + ImageNameNoExt + " - Cell_Region_ROISet.zip");
	//run("Clear Results");
	//roiManager("Reset");
	//run("Close All");
}
