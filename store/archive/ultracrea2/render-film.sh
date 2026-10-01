#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -framerate 30 -t 4 -i "$here/frames/01.jpg" \
  -loop 1 -framerate 30 -t 4 -i "$here/frames/02.jpg" \
  -loop 1 -framerate 30 -t 4 -i "$here/frames/03.jpg" \
  -loop 1 -framerate 30 -t 4 -i "$here/frames/04.jpg" \
  -loop 1 -framerate 30 -t 4 -i "$here/frames/05.jpg" \
  -filter_complex "\
    [0:v]zoompan=z='min(zoom+0.00023,1.028)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p,trim=duration=4,setpts=PTS-STARTPTS[v0];\
    [1:v]zoompan=z='min(zoom+0.00023,1.028)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p,trim=duration=4,setpts=PTS-STARTPTS[v1];\
    [2:v]zoompan=z='min(zoom+0.00023,1.028)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p,trim=duration=4,setpts=PTS-STARTPTS[v2];\
    [3:v]zoompan=z='min(zoom+0.00023,1.028)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p,trim=duration=4,setpts=PTS-STARTPTS[v3];\
    [4:v]zoompan=z='min(zoom+0.00023,1.028)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p,trim=duration=4,setpts=PTS-STARTPTS[v4];\
    [v0][v1]xfade=transition=fadeblack:duration=0.5:offset=3.5[x1];\
    [x1][v2]xfade=transition=fadeblack:duration=0.5:offset=7[x2];\
    [x2][v3]xfade=transition=fadeblack:duration=0.5:offset=10.5[x3];\
    [x3][v4]xfade=transition=fadeblack:duration=0.5:offset=14[out]" \
  -map '[out]' -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -movflags +faststart "$here/../videos/ultracrea2-promo.mp4"

ffprobe -v error -show_entries format=duration,size:stream=width,height \
  -of default=noprint_wrappers=1 "$here/../videos/ultracrea2-promo.mp4"
