#!/bin/sh
lstr=`ls -A1 *.md`
readarray -t lsarr <<<"$lstr"
for i in "${lsarr[@]}"
do
	:
	echo $i
	title=`echo $i | sed 's/-/\ /g' | sed 's/\.md//g'`
	echo $title
	echo -e "# $title\n$(cat $i)" > $i
done

