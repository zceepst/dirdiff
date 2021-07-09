#=
	dirdiff.jl

Command line directory analysis tool.

Features:
- pass arguments to program by passing shell args [see docs.](https://argparsejl.readthedocs.io/en/latest/argparse.html)
- control anaylsis behaviour by passing shell args
=#

using CSV, FileIO, DataFrames
using ImageMagick, Images, ImageIO


