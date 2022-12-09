#!/bin/bash
# Credits to @sputnick-dev: https://github.com/sputnick-dev

function convertDMStoDecimal() {
	echo "$1" | awk -v FS="[ \t]" '{print $0,substr($1,length($1),1)substr($2,length($2),1)}' \
			  | sed 's/\xc2\xb0\([0-9]\{1,2\}\).\([NEWS]\)/ \1 0 \2/g;s/\xc2\xb0\([NEWS]\)/ 0 0 \1/g;s/[^0-9NEWS]/ /g' \
			  | awk '{if ($9=="NE") {printf ("%.4f\t%.4f\n",$1+$2/60+$3/3600,$5+$6/60+$7/3600)} \
					 else if ($9=="NW") {printf ("%.4f\t%.4f\n",$1+$2/60+$3/3600,-($5+$6/60+$7/3600))} \
					 else if ($9=="SE") {printf ("%.4f\t%.4f\n",-($1+$2/60+$3/3600),$5+$6/60+$7/3600)} \
					 else if ($9=="SW") {printf ("%.4f\t%.4f\n",-($1+$2/60+$3/3600),-($5+$6/60+$7/3600))}}' \
			  | xargs
}

function extractGeoCoordinate() {
	fname="city.html"
	URL="https://en.wikipedia.org/wiki/$1"

	pattern_1='(//span[@class="latitude"]/text())[position()=1]'
	pattern_2='(//span[@class="longitude"]/text())[position()=1]'
	xmlstartlet_pattern="$pattern_1 | $pattern_2"
	perl_pattern='s|^(\d+)\D+(\d+)\D+(\d+).*|$1+($2/60)+($3/60)/60|e'

	curl -s $URL > "$fname"
	xmlstarlet format -H "$fname" 2>/dev/null | sponge "$fname"
	lat_lng="$(xmlstarlet sel -t -v "$xmlstartlet_pattern" "$fname" | sed 'N;s/\n/ /')"
	rm "$fname"

	echo "$(convertDMStoDecimal "$lat_lng")"
}

cities_filename=$1

to_csv_filename="BR_tmp.csv"
rm -f "$to_csv_filename" && touch "$to_csv_filename"

cat "$cities_filename" | \
tail -n +2 | 
awk '{ print $1 }' FS="," | \
perl -lne 'print $2 while m{(["'\''])((?:\\.|(?!\1).)*+)\1}g' | \
sed 's/ /_/g' | \
uniq >> "$to_csv_filename"

to_output_filename='cities_lat_lng.csv'
rm -f "$to_output_filename" && touch "$to_output_filename"

line_count="$(wc -l < $to_csv_filename)"
i=1
perc=0
scale=7
while read city; do	
	lat_lng="$(extractGeoCoordinate "$city" | sed 's/ /,/g')"
	echo "$city,$lat_lng" >> $to_output_filename

	perc="$(echo "scale=$scale; $i/$line_count" | bc -l)"
	echo "$perc% ($i/$line_count): $city,$lat_lng"
	i="$(echo "$i+1" | bc)"
done < "$to_csv_filename"

rm -f BR_tmp.csv
