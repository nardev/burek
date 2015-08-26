#!/bin/bash

## Discription: This script will convert videos, genrate thumbnails, genrate preview

OUTPATH="/root/output/"
LOGPATH="/tmp/"
if [ $# -lt 2 ]; then
	echo "Illegal number of parameters"
	echo "Usage:"
	echo "Cut & Convert Video: -c <START_TIME> <END_TIME> --resolution desktop|mobile --format flv|mp4 -i Filename -o <Output FileName>"
	echo "Convert Full Video: -c --resolution desktop|mobile --format flv|mp4 -i Filename -o <Output FileName>"
	echo "Get Video Length(seconds): -t -i Filename"
	echo "Genrate preview: -s <SNAP-SECOND> -i Filename -o <Output FileName>"
	exit 1
fi

SPRITE=0
for param in $(seq 1 $#); do
	PARAMCNT=$(expr ${param} + 1)
	PARAMTMP=$(eval echo \$\{$param\})
	[ ${PARAMTMP} == "-o" ] && OUTFILENAME=$(eval echo \${$PARAMCNT})
	[ ${PARAMTMP} == "-i" ] && INPUTFILE=$(eval echo \${$PARAMCNT})
	[ ${PARAMTMP} == "--resolution" ] && CONVERTTYPE=$(eval echo \${$PARAMCNT})
	[ ${PARAMTMP} == "--format" ] && FORMAT=$(eval echo \${$PARAMCNT})
	[ ${PARAMTMP} == "--sprite" ] && SPRITE=1
done
CPUNO=2

transcode() {
	RESOLUTION=$(echo  ${1}|sed 's#x#*#g' |bc)

	TMPRESOL=${1}

	if [ ${FORMAT} == 'mp4' ]; then
		OUTFILE="${OUTPATH}/${OUTFILENAME}-${TMPRESOL}.mp4"
		if ! ${FFMPEG} -i "${INPUTFILE}" $([ ${REOLVIDEO} -ge ${RESOLUTION} ] && echo "-s ${TMPRESOL}") -movflags rtphint -b:v 1168k -vcodec libx264 -acodec libfaac -ab 20k -ar 44100 -y "${OUTFILE}"; then
			echo "Conversion Failed"
		fi
	fi

	if [ ${FORMAT} == 'flv' ]; then
		OUTFILE="${OUTPATH}/${OUTFILENAME}-${TMPRESOL}.flv"
		if ! ${FFMPEG} -i "${INPUTFILE}" $([ ${REOLVIDEO} -ge ${RESOLUTION} ] && echo "-s ${TMPRESOL}") -movflags rtphint -b:v 1168k -vcodec libx264 -acodec libfaac -ab 20k -ar 44100 -y "${OUTFILE}"; then
			echo "Conversion Failed: flv"
		fi
	fi
}

case $1 in

-c)
	[ -z ${OUTFILENAME} ] && echo "Please provide output filename. Use -o" && exit 1
	[ -z ${INPUTFILE} ] && echo "Please provide input filename. Use -i" && exit 1
	[ -z ${CONVERTTYPE} ] && echo "Please provide convert type. Use --resolution" && exit 1
	[ -z ${FORMAT} ] && echo "Please provide convert type. Use --format" && exit 1

	if [ $# -le 10 ]; then
		FFMPEG="ffmpeg -threads ${CPUNO}"
	else
		if [ $2 -ge $3 ]; then
			echo "Incorrect video crop time.."
			exit 1
		fi
		START_TIME=$2
		LENGTH=$(expr $3 - $2)
		FFMPEG="ffmpeg -threads ${CPUNO} -ss ${START_TIME} -t ${LENGTH}"
	fi

	streams_stream_0_width= ; streams_stream_0_height=
	eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=height,width "${INPUTFILE}")
	SIZE=${streams_stream_0_width}x${streams_stream_0_height}

	REOLVIDEO=$(echo ${SIZE} |sed 's#x#*#g' | bc)
	RESOLUTION=$(echo "scale=1; $streams_stream_0_width/$streams_stream_0_height" | bc)

	# Aspect ratio check
	if [ ${RESOLUTION} = '1.3' ]; then
		[ ${CONVERTTYPE} == 'mobile' ] && transcode 640x480 >> "${LOGPATH}/${OUTFILENAME}-convert.log.txt" 2>&1
		[ ${CONVERTTYPE} == 'desktop' ] && transcode 1024x768 >> "${LOGPATH}/${OUTFILENAME}-convert.log.txt" 2>&1
	elif [ ${RESOLUTION} = '1.7' ]; then
		[ ${CONVERTTYPE} == 'mobile' ] && transcode 640x360 >> "${LOGPATH}/${OUTFILENAME}-convert.log.txt" 2>&1
		[ ${CONVERTTYPE} == 'desktop' ] && transcode 1024x576 >> "${LOGPATH}/${OUTFILENAME}-convert.log.txt" 2>&1
	else
		default() {
			if [ ${FORMAT} == 'mp4' ]; then
        		        OUTFILE="${OUTPATH}/${OUTFILENAME}-${TMPRESOL}.mp4"
        		        if ! ${FFMPEG} -i "${INPUTFILE}" -movflags rtphint -b:v 1168k -vcodec libx264 -acodec libfaac -ab 20k -ar 44100 -y "${OUTFILE}"; then
        		                echo "Conversion Failed"
        		        fi
        		fi

        		if [ ${FORMAT} == 'flv' ]; then
        		        OUTFILE="${OUTPATH}/${OUTFILENAME}-${TMPRESOL}.flv"
        		        if ! ${FFMPEG} -i "${INPUTFILE}" -movflags rtphint -b:v 1168k -vcodec libx264 -acodec libfaac -ab 20k -ar 44100 -y "${OUTFILE}"; then
        		                echo "Conversion Failed: flv"
        		        fi
        		fi
		}
		default >> "${LOGPATH}/${OUTFILENAME}-convert.log.txt" 2>&1
	fi

	if [ ${SPRITE} == '1' ]; then
	thumbnail() {
		# Thumbnail generation
		TMPVIDEOLEN=$(ffprobe "${OUTFILE}" 2>&1 | /bin/grep Duration: | /bin/sed -e "s/^.*Duration: //" -e "s/\..*$//")
		VIDEOLEN=$(/bin/date -u -d "1970-01-01 ${TMPVIDEOLEN}" +"%s")

		MODVIDEOLEN=$((${VIDEOLEN} % 10))
		if [ ${MODVIDEOLEN} -ne 0 ]; then
			VIDEOLEN=$(((10 - ${VIDEOLEN} % 10) + ${VIDEOLEN}))
		fi

		TMPFRAME=$(expr ${VIDEOLEN} / 10)
		SNAPFRAME=$(expr ${TMPFRAME} + 1)

		TOTALFRAMES=$(ffprobe -select_streams v -show_streams "${OUTFILE}" 2>/dev/null | grep nb_frames | sed -e 's/nb_frames=//')
		THUMBNAILVAL=$(expr "${TOTALFRAMES} / ${SNAPFRAME}" | bc)

		if ! ffmpeg -threads ${CPUNO} -ss 10 -i "${OUTFILE}" -f image2 -vf "thumbnail=${THUMBNAILVAL},scale=120:96,tile=12x10" -pix_fmt yuvj420p -an -vsync 0 -y "${OUTPATH}/${OUTFILENAME}-120x69-thumb-%03d.jpg"; then
			echo "Thumbnail generation Failed"
		fi
		}
		thumbnail >> "${LOGPATH}/${OUTFILENAME}-thumbnail.log.txt" 2>&1
	fi
	;;
-s)
	[ -z ${OUTFILENAME} ] && echo "Please provide output filename. Use -o" && exit 1
	[ -z ${INPUTFILE} ] && echo "Please provide input filename. Use -i" && exit 1
	if [ $# -lt 6 ]; then
		echo "Illegal number of parameters : Preview creation"
		exit 1
        fi
	ffmpeg -i "${INPUTFILE}" -ss 00:00:${2} -t 1 -s 320x185 -f mjpeg -y "${OUTPATH}/${OUTFILENAME}-preview.jpeg" >> "${LOGPATH}/${OUTFILENAME}-preview.log.txt" 2>&1
	;;
-t)
	[ -z ${INPUTFILE} ] && echo "Please provide input filename. Use -i" && exit 1
	videotime() {
		TMPVIDEOLEN=$(ffprobe "${INPUTFILE}" 2>&1 | /bin/grep Duration: | /bin/sed -e "s/^.*Duration: //" -e "s/\..*$//")
		VIDEOLEN=$(/bin/date -u -d "1970-01-01 ${TMPVIDEOLEN}" +"%s")
	}
	videotime >> "${LOGPATH}/${OUTFILENAME}-videotime.log.txt" 2>&1
	echo ${VIDEOLEN};
	;;
*)
	echo "Incorrect argument..!!"
	echo "Usage:"
	echo "Cut & Convert Video: -c <START_TIME> <END_TIME> -i Filename -o <Output FileName>"
	echo "Convert Full Video: -c -i Filename -o <Output FileName>"
	echo "Get Video Length(seconds): -t -i Filename"
	echo "Genrate preview: -s <SNAP-SECOND> -i Filename -o <Output FileName>"
	exit 1
	;;
esac
