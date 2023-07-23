# thumbnail_maker

This project is a command-line tool that generates x*y thumbnails for a given video file. Each thumbnail displays the time of the corresponding frame, and all the thumbnails are merged into a single large image. The resulting image also includes information about the video's size and duration.




![](sample/one-piece.E0162.mkv_merge.png)

# Features

- Generates x*y thumbnails for a given video file.
- Displays the time of each frame in the thumbnail.
- Includes information about the video's size and duration in the resulting image.

# Prerequisites
- ffmpeg

To use this tool, you need to have ffmpeg installed on your system. You can install it by following the instructions on the [official website ↗.](https://ffmpeg.org/download.html)


# Usage


```shell
git clone github.com/marlkiller/thumbnail_maker
cd thumbnail_maker

sh thumbnail_maker.sh sample/video.mp4 4 5
```


sh thumbnail_maker.sh [input_video] [x] [y]
- input_video: /path/video.mp4
- x y: rows and columns

In this example, "4 5" splits each input stream into 4 rows and 5 columns, resulting in 20 equal IMG blocks in the output stream.



## How it works?

TODO

# Supported Platform

- Mac OS
- Linux
- ~~Windows (TODO)~~
