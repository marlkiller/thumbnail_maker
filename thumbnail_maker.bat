@echo off

rem Usage :
rem .\thumbnail_maker.bat sample\video.mp4 4 5

rem set PATH=C:\Users\marlkiller\Downloads\ffmpeg\bin;%PATH%

set param_count=0
for %%i in (%*) do (
set /a param_count+=1
)


if %param_count% lss 3 (
echo Error: Need at least 3 parameters
echo Usage: %~f0 sample\video.mp4 4 5
exit /b 1
)


where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
echo "Please install ffmpeg first"
exit /b 1
)



set time_begin=%time%
set /A time_begin_minute=%time_begin:~3,2%
set /A time_begin_second=%time_begin:~-5,2%
set /A time_begin_mill=%time_begin:~-2,2%


echo "Processing %1 %2 %3"

rem tile config
set "x=%2"
set "y=%3"
set /a total_count=%x% * %y%


rem echo all arguments: %*

set "abs_video_file=%1"

for %%i in ("%abs_video_file%") do set "video_name=%%~nxi"



rem ffmpeg config
set composite_img_width=2048
set img_limit=-frames:v 1 -update 1
rem set ffmpeg_out=
set ffmpeg_out=^>^> ffmpeg.out.log 2^>^&1

echo ffmpeg_outffmpeg_outffmpeg_outffmpeg_out %ffmpeg_out%

rem If the watermark text is garbled, set the font file path here and end with ":"
rem eg font_file="fontfile=/System/Library/Fonts/Supplemental/Arial Unicode.ttf:"
set font_file=
set img_suffix=.jpg


rem If scale is placed before tile, the parameters control the resolution of the small tiles;
rem if scale is placed after tile, the parameters control the resolution of the final composite image.And the padding/margin property in the tile may not be calculated correctly.
set margin=40
set padding=20

rem SET /A "tile_img_width=(%composite_img_width% - (%padding% * (%x%-1)) - (%margin% * 2)) / %x%"
rem set "scale=scale=%tile_img_width%:-1,"
rem set "tile=%scale% tile=%x%x%y%:padding=%padding%:margin=%margin%:color=gray,"

set "scale=scale=%composite_img_width%:-1,"
set "tile=tile=%x%x%y%:padding=%padding%:margin=%margin%:color=gray,%scale%"



rem time watermark config
set "draw_time=drawtext=%font_file%text='%%{pts \: hms}':fontsize=h/15:fontcolor=white:x=w/20:y=h/20,"

rem Head info config
set info_height=150

echo %abs_video_file% ^>^>^> [%x% X %y% = %total_count%]




rem func generate_tile_by_time

set "out_tile_img_name=%abs_video_file%_time_2%img_suffix%"
for /f "usebackq delims=" %%a in (`ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 %abs_video_file%`) do set "total_time=%%a"


rem Keep two decimal places
set /a total_time_2=total_time*1000
set /a total_count_2=total_count+1
set /a chunk=total_time_2/total_count_2+5
set chunk=%chunk:~,-3%.%chunk:~-3,2%

rem if %chunk% leq 0 set "chunk=0.01"

echo total_time: %total_time%, chunk: %chunk%
set "ffmpeg_cmd=ffmpeg -y -i %abs_video_file% %img_limit% -vf "select=(gte(t\,%chunk%))*(isnan(prev_selected_t)+gte(t-prev_selected_t\,%chunk%)),%draw_time% %tile%" -fps_mode auto %out_tile_img_name%"
echo %ffmpeg_cmd%
rem call %ffmpeg_cmd%
cmd /c %ffmpeg_cmd% %ffmpeg_out%


rem func generate_video_info
@setlocal enabledelayedexpansion

set wrap=^


set info=
for /f "delims=" %%i in ('ffprobe -v quiet -print_format json -show_format -show_streams %abs_video_file%') do (
set info=!info!%%i!wrap!
)

echo !info! > info_json.txt

for /f tokens^=4^ delims^=^" %%i in ('type info_json.txt ^| findstr \"filename\"') do set "filename=%%~i"
for /f tokens^=4^ delims^=^" %%i in ('type info_json.txt ^| findstr \"size\"') do set "size=%%~i"

rem Filter the third line of matching parameters
set num=0
for /f tokens^=4^ delims^=^" %%i in ('type info_json.txt ^| findstr \"duration\"') do (
set /a num+=1
if !num!==3 (set duration=%%i)
)

for /f "tokens=2 delims=:, " %%i in ('type info_json.txt ^| findstr \"width\"') do set "width=%%~i"
for /f "tokens=2 delims=:, " %%i in ('type info_json.txt ^| findstr \"height\"') do set "height=%%~i"

echo video_info: %filename%,%size%,%duration%,%width%,%height%

set "out_info_txt_name=%abs_video_file%_info%img_suffix%.txt"
echo,Filename: %filename%> "%out_info_txt_name%"
echo,Size: %size%>> "%out_info_txt_name%"
echo,Resolution: %width%x%height%>> "%out_info_txt_name%"
set /p="duration: %duration%" <nul >> "%out_info_txt_name%"


set nl=^& echo.

set "out_info_img_name=%abs_video_file%_info%img_suffix%"

rem converts the \ in the string to /
set "out_info_txt_name=%out_info_txt_name:\=/%"
rem converts the : in the string to \:
set "out_info_txt_name=%out_info_txt_name::=\:%"
set "ffmpeg_cmd=ffmpeg -y -f lavfi -i color=gray:s=%composite_img_width%x%info_height%:d=1 -update 1 -filter:v "drawtext=%font_file%textfile='%out_info_txt_name%':fontsize=24:fontcolor=white:x=%margin%:y=trunc((h-text_h+%margin%)/2)" %out_info_img_name%"
echo %ffmpeg_cmd%
call %ffmpeg_cmd% %ffmpeg_out%

rem func tile_merge_info

set "file_merge=%abs_video_file%_merge%img_suffix%"
set "ffmpeg_cmd=ffmpeg -y -i %out_tile_img_name% -i %out_info_img_name% -update 1 -frames:v 1 -filter_complex "[0:v]pad=iw:ih+%info_height%+1:0:%info_height%:color=white[top]; [top][1:v]overlay=0:0" %file_merge%"
echo %ffmpeg_cmd%
call %ffmpeg_cmd% %ffmpeg_out%



set time_end=%time%
set /A time_end_minute=%time_end:~3,2%
set /A time_end_second=%time_end:~-5,2%
set /A time_end_mill=%time_end:~-2,2%

if %time_end_mill% lss %time_begin_mill% set /A time_end_mill+=100&set /A time_end_second-=1
if %time_end_second% lss %time_begin_second% set /A time_end_second+=60&set /A time_end_minute-=1

set /A minute=time_end_minute-time_begin_minute
set /A second=time_end_second-time_begin_second
set /A mill=time_end_mill-time_begin_mill

echo %time_begin% - %time_end%
echo "[%video_name%] Command take %minute%:%second%:%mill% to execute."


