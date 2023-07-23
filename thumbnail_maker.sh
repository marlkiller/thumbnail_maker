#!/bin/bash
# Usage : sh thumbnail_maker.sh /Users/voidm/Downloads/one-piece.E0162.mkv 3 4

param_count=$#
if [ $param_count -lt 3 ]; then
    echo "Error: Need at least 3 parameters"
    echo "Usage: $0 video.mp4 3 4"
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "Please install ffmpeg first"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Please install jq first."
    exit 1
fi

echo "Processing $0 $1 $2"

abs_video_file="$1"
video_name=$(basename "$abs_video_file")

# ffmpeg config
composite_img_width=2048
img_limit="-frames:v 1 -update 1"
#ffmpeg_out=""
ffmpeg_out=">> ffmpeg.out.log 2>&1"

# If the watermark text is garbled, set the font file path here and end with ":"
# eg font_file="fontfile=/System/Library/Fonts/Supplemental/Arial Unicode.ttf:"
font_file=""
img_suffix=".jpg"

## tile config
x="$2"
y="$3"
total_count=$(expr $x \* $y)

# If scale is placed before tile, the parameters control the resolution of the small tiles;
# if scale is placed after tile, the parameters control the resolution of the final composite image.And the padding/margin property in the tile may not be calculated correctly.
margin=50
padding=20

tile_img_width=$(echo "($composite_img_width - ($padding * ($x-1)) - ($margin * 2)) / $x" | bc)
scale="scale=$tile_img_width:-1,"
tile="${scale} tile=${x}x${y}:padding=$padding:margin=$margin:color=gray,"

#scale="scale=$composite_img_width:-1,"
#tile="tile=${x}x${y}:padding=$padding:margin=$margin:color=gray,${scale}"

## time watermark config
draw_time="drawtext=${font_file}text='%{pts\:hms}':fontsize=h/15:fontcolor=white:x=w/20:y=h/20,"

## Head info config
info_height=140

echo "$abs_video_file >>> [$x X $y = $total_count]"

generate_tile_by_time() {
    out_img_name="$abs_video_file""_""$1"
    total_time=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$abs_video_file")
    # total_time=`ffprobe "$abs_video_file" -select_streams v -show_entries stream=duration -of default=nk=1:nw=1 -v quiet`
    chunk=$(echo "scale=2; $total_time / ($total_count + 1)" | bc)
    if (($(echo "$chunk <= 0" | bc -l))); then
        chunk=0.01
    fi
    echo "total_time: $total_time, chunk: $chunk"
    ffmpeg_cmd="ffmpeg -y -i \"$abs_video_file\" ${img_limit} -vf \"select=(gte(t\,$chunk))*(isnan(prev_selected_t)+gte(t-prev_selected_t\,$chunk)),${draw_time} ${tile} \" -fps_mode auto \"$out_img_name\""
    echo $ffmpeg_cmd
    eval "$ffmpeg_cmd $ffmpeg_out"
}

size_format() {
    total_size=$1
    if [[ "$total_size" =~ ^[0-9]+$ ]]; then
        if [ 1024 -gt $total_size ]; then
            size="$total_size B"
        elif [ 1048576 -gt $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 1024 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size KB"
        elif [ 1073741824 -gt $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 1048576 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size MB"
        elif [ 1073741824 -le $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 1073741824 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size GB"
        else
            size="0"
        fi
    else
        size="NULL"
    fi
    echo $size
}

time_format() {
    total_size=$1
    if [[ $(echo "$total_size + 0" | bc) ]]; then
        if [ 60 -gt $total_size ]; then
            size="$total_size Sec"
        elif [ 3600 -gt $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 60 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size Min"
        elif [ 216000 -gt $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 3600 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size Hour"
        elif [ 5184000 -le $total_size ]; then
            size=$(echo "scale=2; a = $total_size / 216000 ; if (length(a)==scale(a)) print 0;print a" | bc)
            size="$size Day"
        else
            size="0"
        fi
    else
        size="NULL"
    fi
    echo $size
}
generate_video_info() {
    out_img_name="$abs_video_file""_""$1"
    info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$abs_video_file")
    filename=$(echo "$info" | jq -r '.format.filename')
    size=$(echo "$info" | jq -r '.format.size')
    duration=$(echo "$info" | jq -r '.format.duration')
    width=$(echo "$info" | jq -r '.streams[0].width')
    height=$(echo "$info" | jq -r '.streams[0].height')

    size=$(size_format $size)
    int_duration=${duration%.*}
    duration=$(time_format $(echo "scale=0; $int_duration" | bc))

    text_tile="$abs_video_file""_""$1".txt

    cat >$text_tile <<EOF
Filename: $video_name
Size: $size
Resolution: ${width}x${height}
duration: ${duration}
EOF
    ffmpeg_cmd="ffmpeg -y -f lavfi -i color=gray:s=${composite_img_width}x${info_height}:d=1 -update 1  -filter:v  \"drawtext=${font_file}textfile='$text_tile':fontsize=24:fontcolor=white:x=$margin:y=trunc((h-text_h+$margin)/2)\" \"$out_img_name\""
    echo $ffmpeg_cmd
    eval "$ffmpeg_cmd $ffmpeg_out"
}

tile_merge_info() {
    file_img="$abs_video_file""_""$1"
    file_info="$abs_video_file""_""$2"
    file_merge="$abs_video_file""_""$3"

    ffmpeg_cmd="ffmpeg -y -i \"$file_img\" -i \"$file_info\" -update 1 -frames:v 1 -filter_complex \"[0:v]pad=iw:ih+$info_height+1:0:$info_height:color=white[top]; [top][1:v]overlay=0:0\" \"$file_merge\""
    echo $ffmpeg_cmd
    eval "$ffmpeg_cmd $ffmpeg_out"
}

start_time=$(date +%s.%N)

generate_tile_by_time "time_2${img_suffix}"

generate_video_info "info${img_suffix}"

tile_merge_info "time_2${img_suffix}" "info${img_suffix}" "merge${img_suffix}"

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
echo "[$video_name] Command take $duration seconds to execute."
