#!/bin/bash
#
# Copyright 2017-2019 JJS Manufacturing Limited.
# 
# This script should be deployed to /opt/gas/appdata/deployment on the production server.
# It copies the contents of the patch directory into the directories that start with master or beta.
#
# Clean up the deployed applications with:
#
#   $ . /opt/gas/envas
#   $ gasadmin gar --clean-archive
#
# Then use this script.
#
patch=$1
live=$2
test=$3

die()
{
   >&2 printf "$1\n"
   exit 1
}


usage()
{
   die "Usage: $0 patch_dir [dir...]"
}

shift

[[ -z $patch ]] && patch=$(ls -1d patch*/)

# Validate directories
[[ -z $patch ]] && usage
[[ $patch =~ ^patch ]] || die "Invalid patch directory specified"
[[ -r $patch ]] || die "Patch directory does not exist"
# Strip final directory seperator, if it exists.
patch=${patch%/}

dirs=$@
[[ -z "$dirs" ]] && dirs=$(ls -1d {master*,beta*})

# Move MANIFEST file
mv $patch/MANIFEST .

# Apply the patch files
for dir in $dirs
do
   #[[ $dir =~ ^ims_ ]] || die "Invalid directory specified: $dir"
   [[ -r $dir ]] || die "Directory does not exist: $dir"
   dir=${dir%/}
   printf "Patching directory $dir..."
   cp -ax $patch/* $dir/.
   printf "done\n"
done

# restore the MANIFEST file
mv MANIFEST $patch/.
