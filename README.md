# dirdiff

A CLI directory analysis tool built in *Julia*.

## Installation

### Dependencies

Before going ahead with the installation, make sure you have the following already installed:

- [Julia](https://julialang.org/) with correct environment PATHs set
	```
	Julia v1.6.1 (or later)
	```

### Building from source

To install *dirdiff* from source:

- clone this repository (example using SSH)
	```
	$ git clone git@github.com:zceepst/dirdiff.git
	```
- navigate to download location
	```
	$ cd <location>/dirdiff/
	```
- run installer script
	```
	$./install.sh
	```

## Shell Integration

Look into how to use `ArgParse.jl` to control both target directories and analysis behaviour, see docs [here](https://argparsejl.readthedocs.io/en/latest/argparse.html).

At the moment I'm thinking something like:
```
$ dirdiff rec/write/... --dir1 "<first directory>" -dir2 "<second directory>" -v/-f/-r ...
```
