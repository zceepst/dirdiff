#-----------------------------------------------#
#					dirdiff.jl					#
#-----------------------------------------------#
# Command line execution script for analysing	#
# the differences in directory contents, used	#
# mainly to compare SD card versions which		#
# contain `.bmp` and config files.				#
#						~						#
#				Pierre Steen 2021				#
#===============================================#

## Packages

using CSV
using FileIO
using DataFrames
using ImageMagick
using Images
using ImageIO
using ArgParse
using OutputCollectors

## Custom Type Definitions

"""
	Differences{T<:AbstractDict}

Type which contains
"""
struct Differences{T<:AbstractDict}
	unchanged::T
	reassigned::T
	renamed::T
	removed::T
	added::T
end

## `Differences` Type Constructor

"""
	calcdifferences(collection1, collection2)

Calculates and constructs a `::Differences` datatype instance for the input
"""
function calcdifferences(collection1, collection2)::Differences
	return Differences(
		unchangedpairs(collection1, collection2),
		reassignedpairs(collection1, collection2),
		renamedpairs(collection1, collection2),
		diffpairs(collection1, collection2),	# removed (v51 to v54)
		diffpairs(collection2, collection1)		# added
	)
end

## ArgParse Setup

"""
	parse_commandline()

Parses and returns a dictionary of parsed command line arguments and flags.
"""
function parsecommandline()
	s = ArgParseSettings()

	@add_arg_table! s begin
		# "--bmp", "-b"
			# help = "an option with an argument"
		# "--flag1"
			# help = "an option without argument, i.e. a flag"
			# action = :store_true
		"dir1"
		# dir1 represents the old directory version passed in as a string
			help = "references directory - old version"
			arg_type = String
			required = true
		"dir2"
		# dir2 represents the new directory version passed in as a string
			help = "target directory - new version"
			arg_type = String
			required = true
	end

	return parse_args(s)
end

## Analysis

"""
	encodeimages(collection::Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}})

Encode a dictionary of `filename::String => image::Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}` to a dictionary of `id::Int => image::Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}` pairs.
Ensure image entries are unique before adding to dictionary.
"""
function encodeimages(collection::T) where {T<:AbstractDict}
	# encoded = Dict{Int, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}() # initialise empty dictionary
	encoded = Dict()
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

"""
	unchangedpairs(collection1::T, collection2::T) where {T<:AbstractDict}

Calculates which pairs are unchanged when moving comparing `collection2` to `collection1`, where both collections are dictionaries of `(file_name => file_content)` pairs.
"""
function unchangedpairs(collection1::T, collection2::T) where {T<:AbstractDict}
	# unchanged = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	unchanged = Dict()
	for pair in collection2
		if in(pair, collection1)
			push!(unchanged, pair)
		end
	end

	return unchanged
end

"""
	reassignedpairs(collection1::T, collection2::T) where {T<:AbstractDict}
"""
function reassignedpairs(collection1::T, collection2::T) where {T<:AbstractDict}
	# reassigned = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	reassigned = Dict()
	for pair in collection2
		if in(pair[1], keys(collection1)) && !in(pair[2], values(collection1))
			push!(reassigned, pair)
		end
	end

	return reassigned
end

"""
	renamedpairs(collection1::T, collection2::T) where {T<:AbstractDict}
"""
function renamedpairs(collection1::T, collection2::T) where {T<:AbstractDict}
	# renamed = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	renamed = Dict()
	for pair in collection2
		if in(pair[2], values(collection1)) && !in(pair[1], keys(collection1))
			push!(renamed, pair)
		end
	end

	return renamed
end

"""
	diffpairs(collection1::T, collection2::T) where {T<:AbstractDict}

Works for both removed and added pairs, switch argument order to change functionality.
"""
function diffpairs(collection1::T, collection2::T) where {T<:AbstractDict}
	# removed = Dict{String, Matrix{ColorTypes.RGB{FixedPointNumbers.N0f8}}}()
	removed = Dict()
	for pair in collection1
		if !in(pair[2], values(collection2)) && !in(pair, collection2) && !in(pair[1], keys(collection2))
			push!(removed, pair)
		end
	end

	return removed
end

## Shell diff and `.csv` file build

"""
	argstodirs(parsed_args)

Assembles the output of `OutputCollector -> parsedcommandline()` to an array of directory strings.
"""
function argstodirs(parsed_args)
	return (parsed_args["dir1"], parsed_args["dir2"])
end

"""
	streamfilenames(directories)

Navigate to ref and target directory then run shell command:
```
find . -type f
```
which will create and output stream of all the file names in the current directory.
Do this for each directory we want to analyse, use OutputCollector to collect stdout
and stderr IO streams.
Resulting output string will be formatted somewhat like
```
output = "<filename>\n<filename>\n<filename>\n..."
```
we can therefore use `x -> split(x, "\n")` to split the large string into sub-string filenames, removing the newline chars.
Finally we return an array containing two sub-string vectors.
"""
function streamfilenames(directories)
	returnto = @__DIR__
	filenames = []
	script = """
	#!/bin/bash
	find . -type f
	"""

	for dir in directories
		cd(dir)
		oc = OutputCollector(`bash -c $script`; verbose=false)
		merge(oc)
		if isempty(collect_stderr(oc))
			push!(filenames, String.(split(collect_stdout(oc), "\n")[1:(end-1)]))
		else
			break
		end
	end
	cd(returnto)

	return (filenames[1], filenames[2])
end

# refactored file name shell command stream collector: ------------!!!
# function streamfilenames(directory)
	# locald = @__DIR__
	# script = """
	# #!/bin/bash
	# find . -type f
	# """
#
	# cd(directory)
	# oc = OutputCollector(`bash -c $script`; verbose=false)
	# @assert isempty(collect_stderr(oc))
#
	# names = String.(split(collect_stdout(oc)[1:(end-1)], "\n"))
	# cd(locald)
#
	# return names
# end

"""
REFACTOR TO: filterformat(mixed_fileformats; format="bmp") --------!!!

	filterformat(mixed_filenames)

Split `.txt` and `.bmp` files from array of mixed string file names.
"""
function filterformat(mixed_filenames)
	bmp_filenames = String[]
	txt_filenames = String[]
	for filename in mixed_filenames
		if split(filename, ".")[3] != "txt"
			push!(bmp_filenames, filename)
		else
			push!(txt_filenames, filename)
		end
	end

	return bmp_filenames, txt_filenames
end

"""
	formatdifferences(analysis::Differences)

Formats the directory file content difference analysis results into a form which can later be parsed and used for programmatically determining the necessary file downloads, name changes and deletions to perform to convert the group of files from the reference directory to the target directory.
"""
# function formatdifferences(images::Tuple{T,T}, text::Tuple{T,T}, analysis::Differences) where {T<:AbstractDict}
function formatdifferences(image_analysis::Differences, text_analysis::Differences)
	# write a file (csv?, txt? JSON?)
	# data that needs to be conveyed:
	# reference file:	<filename>.<extension>
	# diff analysis:	<unchanged/reassigned/renamed/removed/added>
	#
end

## Tests

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

## Main Function

# Next steps:
# - [x] split .bmp txt file
# - [x] construct Pair(filename => image) and Pair(filename => content) dictionaries
# - [x] calculate changes and construct Differences instance
# - []
# - []
function main()
	# read args then capture filenames from bash IO stream using OutputCollector
	# parsed_args = parsecommandline()

	# use when testing from julia> REPL
	parsed_args = Dict(
		"dir1" => "/home/pb/Documents/work/dev-ops/sdcards/CHGCTV51/",
		"dir2" => "/home/pb/Documents/work/dev-ops/sdcards/CHGCTV54/"
	)

	# generate directory strings, then make filename string vector tuple
	dir_paths = argstodirs(parsed_args)
	ref_names, tgt_names = streamfilenames(dir_paths)

	ref_bmp, ref_txt = filterformat(ref_names) # filter reference and target filenames lists into `.bmp` and `.txt`
	tgt_bmp, tgt_txt = filterformat(tgt_names)

	# load images and text files into dictionaries, keeping track of (filename => contents) pairs

	# images
	ref_imgs = Dict(ref_bmp .=> load.(dir_paths[1] .* ref_bmp))
	tgt_imgs = Dict(tgt_bmp .=> load.(dir_paths[2] .* tgt_bmp))

	# txt
	ref_text = Dict(ref_txt .=> read.(dir_paths[1] .* ref_txt, String))
	tgt_text = Dict(tgt_txt .=> read.(dir_paths[2] .* tgt_txt, String))

	# calculate differences between reference and target files, construct Differences data type
	imgs_diff = calcdifferences(ref_imgs, tgt_imgs) # ::Differences
	text_diff = calcdifferences(ref_text, tgt_text)
end

# @show main() # program execution
@show out = main()

