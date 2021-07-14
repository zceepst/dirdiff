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

"""
	encodeimages(collection::Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}})

Encode a dictionary of `filename::String => image::Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}` to a dictionary of `id::Int => image::Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}` pairs.
Ensure image entries are unique before adding to dictionary.
"""
function encodeimages(collection)
	encoded = Dict{Int, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}() # initialise empty dictionary
	count = 1
	for pair in collection
		# ensure image not already encoded for (such that allunique(values(encoded)) = true)
		if !in(pair[2], values(encoded))
			push!(encoded, count => pair[2]) # add unique image to encode dictionary
			count += 1 # only increment count if image has been added
		end
	end

	return encoded
end

v51_lenraw = length(v51_images)
v54_lenraw = length(v54_images)

v51_imgenc = encodeimages(v51_images)
v54_imgenc = encodeimages(v54_images)

v51_lenenc = length(v51_imgenc)
v54_lenenc = length(v54_imgenc)

# we now want to sort the files into five categories:
# (consider direction change from v51 to v54)
# - unchanged	(filename & image unchanged)
# - renamed		(image unchanged & new file name (careful with duplicates))
# - reassigned	(filename unchanged & new image)
# - removed		(filename & image removed)
# - added		(new filename & image content)

struct Differences
	unchanged
	reassigned
	renamed
	removed
	added
end

function sortdiffs(collection1, collection2)
	return Differences(
		unchangedpairs(collection1, collection2),
		reassignedpairs(collection1, collection2),
		renamedpairs(collection1, collection2),
		diffpairs(collection1, collection2),	# removed (v51 to v54)
		diffpairs(collection2, collection1)		# added
	)
end

function unchangedpairs(collection1, collection2)
	# unchanged = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	unchanged = Dict()
	for pair in collection2
		if in(pair, collection1)
			push!(unchanged, pair)
		end
	end

	return unchanged
end

function reassignedpairs(collection1, collection2)
	# reassigned = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	reassigned = Dict()
	for pair in collection2
		if in(pair[1], keys(collection1)) && !in(pair[2], values(collection1))
			push!(reassigned, pair)
		end
	end

	return reassigned
end

function renamedpairs(collection1, collection2)
	# renamed = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	renamed = Dict()
	for pair in collection2
		if in(pair[2], values(collection1)) && !in(pair[1], keys(collection1))
			push!(renamed, pair)
		end
	end

	return renamed
end

# works for both removed and added pairs, switch argument order to change functionality
function diffpairs(collection1, collection2)
	# removed = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	removed = Dict()
	for pair in collection1
		if !in(pair[2], values(collection2)) && !in(pair, collection2) && !in(pair[1], keys(collection2))
			push!(removed, pair)
		end
	end

	return removed
end

diff = sortdiffs(v51_images, v54_images) # diff type of version change info

# test that `diff` is valid (length testing)
function testdiff(diff)
	for pair in diff.unchanged
		@assert !in(pair, diff.reassigned)
		@assert !in(pair, diff.renamed)
		@assert !in(pair, diff.removed)
		@assert !in(pair, diff.added)
	end
	for pair in diff.reassigned
		@assert !in(pair, diff.unchanged)
		@assert !in(pair, diff.renamed)
		@assert !in(pair, diff.removed)
		@assert !in(pair, diff.added) # fails for v51, v54 diff
	end
	for pair in diff.renamed
		@assert !in(pair, diff.unchanged)
		@assert !in(pair, diff.reassigned)
		@assert !in(pair, diff.removed)
		@assert !in(pair, diff.added)
	end
	for pair in diff.removed
		@assert !in(pair, diff.unchanged)
		@assert !in(pair, diff.reassigned)
		@assert !in(pair, diff.renamed)
		@assert !in(pair, diff.added)
	end
	for pair in diff.added
		@assert !in(pair, diff.unchanged)
		@assert !in(pair, diff.reassigned) # fails for v51, v54 diff -- overlap between added & reassigned sets
		@assert !in(pair, diff.renamed)
		@assert !in(pair, diff.removed)
	end
end

testdiff(diff)

# length() dispatch re-write for `bmpdiffs` type
# returns a tuple of integers
function Base.length(x::Differences)
	return length.((x.unchanged, x.reassigned, x.renamed, x.removed, x.added))
end

length(diff)

# """
# - group renamed files
# - point reassigned files to
# """
# function transitioninfo()
#
# end

#=
TESTING
---

Create a test case to validate that sortdiffs(c2, c2) works properly and treats all edge cases.
=#

x1 = Dict(
	"one" => 1,
	"two" => 2,
	"three" => 2,
	"four" => 4,
	"five" => 5,
	"six" => 6,
	"seven" => 7,
	"eight" => 8,
	"nine" => 9
)
x2 = Dict(
	"one" => 1,
	"eleven" => 2,
	"three" => 2,
	"four" => 11,
	"five" => 5,
	"six" => 6,
	"seven" => 7,
	"nine" => 9,
	"ten" => 10
)

test1 = sortdiffs(x1, x2) # looks good!
