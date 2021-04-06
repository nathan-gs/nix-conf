#!/usr/bin/env bash

urlencode() {
	local LANG=C i c e=""
	for ((i=0;i<${#1};i++)); do
                c=${1:$i:1}
		[[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
                e+="$c"
	done
        echo "$e"
}

##
# Example usage: 
# vrt https://www.vrt.be/vrtnu/a-z/une-soeur/2018/une-soeur/ "/media/media/Films/Une Soeur (2018)"
#
vrt() {
    url=$1
    file_clean=$2

    youtube-dl \
            --no-progress \
            --ignore-errors \
            --ignore-config \
            --username $VRT_USERNAME \
            --password $VRT_PASSWORD \
            --write-sub \
            --sub-format srt \
            --all-subs \
            --convert-subs srt \
            --add-metadata \
            --prefer-ffmpeg \
            --external-downloader-args '-loglevel error' \
            --sleep-interval 10 \
            --max-sleep-interval 120 \
            --restrict-filenames \
            --sub-lang nl,en \
            -o "$file_clean.%(ext)s" \
            $url || true
}

##
# Example usage:
# vrt_search_and_download "/media/media/Kids/Series" "Musti"
#
vrt_search_and_download() {

  series="$2"
  search=$(urlencode "$series")
  path="$1" 
  if [[ "$3" != "" ]]; then
    titleSelector="$3" 
  else
    titleSelector="title"
  fi

  pushd "$path" > /dev/null
  results=`curl --silent "https://search.vrt.be/search?i=video&q=$search&highlight=true&size=100&available=true&" | jq -c '.results[] | {title, url, seasonTitle, episodeNumber, shortDescription}'`

  IFS=$'\n'
  for i in $results;
  do
    title=`echo $i | jq -r ".$titleSelector"`
    url=`echo $i | jq -r '.url'`
    season=$(( printf '%02d' `echo $i | jq -r '.seasonTitle'` ) || echo "NO_SEASON")
    seasonNumber=`echo $i | jq -r '.seasonTitle'`
    episode=$(printf '%02d' `echo $i | jq -r '.episodeNumber'` || "none")
    if [[ $season == *"NO_SEASON"* ]];
    then
	echo "No season found in \"$i\", skipping."
	continue
    fi

    mkdir -p "$series"/"Season $seasonNumber"
    chmod ugo+rwx "$series"/"Season $seasonNumber" || true
    pushd "$series"/"Season $seasonNumber" > /dev/null

    filename="$series S${season}E${episode} $title"
    file_clean=`echo $filename | tr -cs "[ A-Za-z0-9\-]_" _ | sed 's/_$//'`
    
    echo $url 
    echo $filename

    
    if [ `ls | grep -c "$file_clean"` -eq 0 ]
    then
      if [[ ${url} != *"marathonradio"* ]];
      then  
        if [[ ${url} != *"audiodescriptie"* ]];
          then
          echo "downloading $file_clean"

          vrt $url $file_clean

          chmod ugo+rw * || true
          echo "downloaded $file_clean"
        else
          echo "Skipping audiodescriptie"
        fi
      else
        echo "Skipping marathonradio"
      fi
    else
      echo "Already downloaded $file_clean, skipping"
    fi

    popd > /dev/null
  done
  popd > /dev/null
}

##
# Example usage: 
# nickjr "/media/media/Kids/Series" "Paw Patrol" http://www.nickjr.nl /paw-patrol/videos/
#
nickjr() {
  baseUrl="$3"
  basePath="$4"
  
  selector="Hele aflevering"
  fsPath="$1"
  name="$2"

  echo "nickjr: Searching for $name"
  url="${baseUrl}/${basePath}"

  results=`curl --silent "${url}" | pup ":parent-of(:parent-of(:parent-of(:parent-of(:contains(\"${selector}\"))))) attr{href}"`    
  
  for i in $results;
  do
    
    vidUrl="${baseUrl}${i}"
    

    title=`curl --silent "$vidUrl" | pup 'title text{}'`
    season=`echo $title | grep -o -E 'S[0-9]{1,2}' | sed 's/S//'`
    episode=`echo $title | grep -o -E 'Ep[0-9]{3,4}' | sed "s/Ep${season}//"`

    youtube-dl \
            --no-progress \
            --ignore-errors \
            --ignore-config \
            --write-sub \
            --sub-format srt \
            --all-subs \
            --convert-subs srt \
            --add-metadata \
            --prefer-ffmpeg \
            --sleep-interval 10 \
            --max-sleep-interval 120 \
            --restrict-filenames \
            --sub-lang nl,en \
            --no-overwrite \
            -o "$fsPath/${name}/Season ${season}/${name} S${season}E${episode} %(playlist_title)s.%(ext)s" \
            "$vidUrl"

  done;
}
