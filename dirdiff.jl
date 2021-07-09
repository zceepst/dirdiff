#=
	dirdiff.jl

Command line directory analysis tool.

Features:
- pass arguments to program by passing shell args [see docs.](https://argparsejl.readthedocs.io/en/latest/argparse.html)
- control anaylsis behaviour by passing shell args

TODO:
- rename v51, v54 to generic variables
- setup argparse variable generation routine
- exapnd file format capabilities fast .txt & .bmp
- think about types of analysis (start with name/content/diff analysis, expand later)
- split-up main script into sub parts (keep centralized until further system planning done)
=#

using CSV, FileIO, DataFrames
using ImageMagick, Images, ImageIO

# for now assume given directory paths, in future these will be provided via ArgParse shell args

v51_files = CSV.File("../../dev-ops/sdcards/v51.csv") |> DataFrame |> x -> x[!, :Files]
v54_files = CSV.File("../../dev-ops/sdcards/v54.csv") |> DataFrame |> x -> x[!, :Files]

v51_path = "../../dev-ops/sdcards/CHGCTV51/"
v54_path = "../../dev-ops/sdcards/CHGCTV54/"

# filter out txt files from bmp files

"""
	filterformat(mixed_filenames)

Split `.txt` and `.bmp` files from array of mixed string file names.
"""
function filterformat(mixed_filenames)
	bmp_filenames = []
	txt_filenames = []
	for filename in mixed_filenames
		if split(filename, ".")[2] != "txt"
			push!(bmp_filenames, filename)
		else
			push!(txt_filenames, filename)
		end
	end

	return bmp_filenames, txt_filenames
end

# separated file types (only works for .txt and .bmp for now)

v51_bmp, v51_txt = filterformat(v51_files)
v54_bmp, v54_txt = filterformat(v54_files)

# load images and text files into dictionaries, keeping track of (filename => contents) pairs

# images
v51_images = Dict(v51_bmp .=> load.(v51_path .* v51_bmp))
v54_images = Dict(v54_bmp .=> load.(v54_path .* v54_bmp))

# txt
v51_text = Dict(v51_txt .=> read.(v51_path .* v51_txt, String))
v54_text = Dict(v54_txt .=> read.(v54_path .* v54_txt, String))

# analyse the difference in image files between both directories
# check: images contents, image names
# sort into:
# 	- common
#	- forward (v1 -> v2, files in v2 not common to v1)
#	- backward (v1 <- v2, files in v1 not common to v2)
# edge cases comparing pairs (name1 => image1) & (name2 => image2):
#	- if name1 == name2 but image1 != image2
#	- if name1 != name2 but image1 == image2

"""
	comparebmps(dict1, dict2)

Compare the `.bmp` file contents in dict1 and dict2.
The data is formatted so that each pair in both dictionaries represents a single element in a directory:
```
element :: Pair{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}
```
therefore the type signature of both parameters is:
```
dict1, dict2 :: Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}
```
"""
function comparebmps(dict1, dict2)
	analysis = [] # placeholder
	return analysis
end

function commonbmps(dict1, dict2)
	common = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()

	# sort common images: check dict2, ref dict1
	for pair in dict1
		# if image from dict1 is found (not by name by raw data) in dict2, pair added to common
		if pair[2] in values(dict2)
			push!(common, pair) # add pair to common collection
		end
	end
	# @assert allunique(keys(common)) # passes for v51
	@assert allunique(values(common)) # check all the images are unique in the common images
	# assertion error v51 -- there must be duplicate images woth
	# switch order: check dict1, ref dict2
	# for pair in dict2
		# if pair[2] in values(dict1)
			# push!(common, pair)
		# end
	# end

	return common
end

# commonbmps(v51_images, v54_images)
commonbmps(v54_images, v51_images)
# both version fail common image unique assertion test
# this means there are common image duplicates between both versions where both (or more) files
# have different names but are the same image

# v51_bmp, v54_bmp