#!/bin/sh

# Pregenerates a markdown file with numbered chapters with the headers

# generate from 1 to 400 by default
if [ -z "$1" ]; then
  END="400"
  START="1"
else
  START="$1"
fi

# if given just one number, start with 
if [ -z "$2" ]; then
  END="400"
else
  END="$2"
fi

# write the markdown chapters
for i in $(seq $START $END); do
  echo ""
  echo "### $i"
  echo ""
  echo ""
done
