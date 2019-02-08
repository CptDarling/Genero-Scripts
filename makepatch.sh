#!/bin/bash
#
# Copyright 2017-2019 JJS Manufacturing Limited.
#
# Assembles a patch directory ready for the Genero Studio patch project.
#
# Change log
# ==========
# 2018-04-12 V1.0.1
#  Patch directory contents are not listed, this is left to the caller to do.
#  No arguments prints the usage.
#
version=1.0.1
self=$(basename $0)

patchdir=distbin/patch
bindir=bin
commit=HEAD
en=en_GB
cs=cs_CZ

die()
{
  >&2 printf "$1\n"
  exit 1
}

patchfile()
{
  cp $bindir/$1.42* $patchdir
  rm $patchdir/$1.42x 2>/dev/null
}

process()
{
  for file in $*
  do
    patchfile $file
  done
}

clean()
{
  cd $patchdir
  [[ $? -ne 0 ]] && die "Cannot find patch directory $patchdir"
  git clean -fxd >/dev/null
  cd - >/dev/null
}

diff()
{
  [[ -n "$1" ]] && commit=$1

  declare -a arr=() changes=() files=() filenames=() exts=()

  arr=$(git diff --name-status $commit~1 $commit)
  for line in $arr
  do
    case "$line" in
      M|A|D)  changes+=($line);;
        *)  files+=($line)
          ext=(${line#*.})
          exts+=($ext)
          filenames+=($(basename $line .$ext))
          ;;
    esac
  done

  for i in ${!changes[@]}
  do
    printf "Change %s %s %s\t%s\n" "$(($i + 1))" "${changes[$i]}" "${exts[$i]}" "${filenames[$i]}"

    change=${changes[$i]}
    filename=${filenames[$i]}
    ext=${exts[$i]}

    # Don't process deleted lines or project files
    case "$change" in
      D) continue ;;
      *) ;;
    esac

    case "$ext" in
      4gl) patchbin $filename ;;
      4fd) patchfrm $filename ;;
      per) patchfrm $filename ;;
        *) continue ;;
    esac

  done

  rm $patchdir/*42x 2>/dev/null

}

patchbin()
{
  prog=$bindir/$1.42r
  obj=$bindir/$1.42m

  if [ -r $prog ]; then
    cp $prog $patchdir
    fail_check
  fi
  if [ -r $obj ]; then
    cp $obj $patchdir
    fail_check
  fi
}

patchfrm()
{
  form=$bindir/$1.42f

  if [ -r $prog ]; then
    cp $form $patchdir
    fail_check
  fi
}

patchstr()
{
  mkdir -p $patchdir/$en $patchdir/$cs
  fail_check
  cp res/strings/$en/bin/$1 $patchdir/$en
  fail_check
  cp res/strings/$cs/bin/$1 $patchdir/$cs
  fail_check
}

fail_check()
{
  [[ $? -ne 0 ]] && die "Aborted"
}

usage()
{
  declare -a arr=(
    "Options:"
    "-c|--clean          Clear out the patch directory before adding files."
    "-d|--diff [commit]  Uses file list from git diff between commit~1 and commit, defaults to HEAD."
    "-h|--help           This help information."
    "-v|--version        The version number of this script."
    )

  printf "Usage: $self [OPTIONS] [files...]\n"

  ## now loop through the above array
  for i in "${arr[@]}"
  do
    echo "$i"
  done
  exit
}

version()
{
  printf "Version $version\n"
  exit
}

[[ $# -eq 0 ]] && usage
[[ ! -r $patchdir ]] && mkdir -p $patchdir
[[ ! -r $bindir ]] && die "Cannot find bin directory!"

for arg
do
    case "$arg" in
      -c|--clean)
        shift; clean ;;
      -d|--diff)
        shift; diff $*;;
      -h|--help)
        usage;;
      -v|--version)
        version;;
      *)
        [[ ${arg:0:1} == "-" ]] && die "Invalid argument $arg" ;;
    esac
done

shift

process $*
