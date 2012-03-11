#!/bin/bash

DOMAIN="photofile.ru"
TRACE="--silent --show-error"
rename=0
while [ "$1" != "" ];
do
	arg="$1"
	shift
	case "$arg" in
		-u|--user)
			USER="$1"
			shift
			;;
		-p|--password)
			PASSWORD="$1"
			shift
			;;
		-a|--album-id)
			ALBUM_ID="$1"
			shift
			;;
		-A|--album)
			ALBUM="$1"
			shift
			;;
		-t|--trace)
			TRACE="$TRACE --trace -"
			shift
			;;
		-v|--verbose)
			TRACE="$TRACE -v"
			;;
		-P|--progress)
			# remove "--silent" option to show progress
			TRACE="${TRACE//--silent/} -#"
			;;
		-r|--rename)
			rename=1
			;;
		*)
			FILE="$arg"
			;;
	esac
done
SITE=http://photo.qip.ru
CACHE=$HOME/.cache/curl/photo.qip.ru
COOKIE=$CACHE/cookie
LOG="$CACHE/cache.$$.log"
mkdir -p "$CACHE"

# try to open "add photo" page
# if it fails (not 200 OK)
# then login
if ! curl $SITE/users/$USER/addphoto/ -b "$COOKIE" -D - -o /dev/null 2>/dev/null | head -1 | grep -qF 'HTTP/1.1 200 OK'; then
	if [[ "$USER" == "" || "$PASSWORD" == "" ]]; then
		echo "credentials (username/password) not defined!"
		exit 1
	fi
	curl $SITE/login/ -d login=$USER -d "domain=@$DOMAIN" -d password="$PASSWORD" -c "$COOKIE"
fi
if [ "$ALBUM" != "" ]; then
	ALBUM_ID=$(curl $SITE/users/$USER/addphoto/ -b "$COOKIE" --silent --show-error \
		| grep -F 'option value=' \
		| grep "$ALBUM" \
		| sed -r "s/.+value=\"([0-9]+)\".+/\1/")
	if [ "$ALBUM_ID" == "" ]; then
		ALBUM_ID="0"
		echo "Album ID for name \"$ALBUM\" cannot be found! New album used"
		new_album=1
	fi
elif [ "$ALBUM_ID" == "" ]; then
	echo "Nor album name nor album id not defined!"
	exit 2
fi
if [ "$FILE" == "" ]; then
	echo "Filename not defined!"
	exit 3
fi
if [ ! -e "$FILE" ]; then
	echo "File \"$FILE\" not found!"
	exit 3
fi
curl $SITE/photo/$USER/$ALBUM_ID/do/ \
	-F act=add_images \
	-F rename_by_album=$rename \
	-F album_name="$ALBUM" \
	-F image_files\[\]=@"$FILE"\;type=image/jpeg \
	-b $COOKIE \
	-c $COOKIE \
	-e $SITE/users/$USER/addphoto/ \
	-o /dev/null \
	-D "$LOG" \
	$TRACE 
exitcode=$?
if grep -qP 'Location:.+done=(uploadfok|add_album_photo)' "$LOG" && [ $exitcode -eq 0 ]; then
	if [ "$new_album" == "1" ]; then
		ALBUM_ID=$(grep -P "Location: $SITE/users/$USER/\d+/edit/\?done=add_album_photo" "$LOG" \
			| sed -r "s#.+/$USER/([0-9]+)/edit/.+#\1#")
		curl $SITE/photo/$USER/$ALBUM_ID/do/ -d "name=$ALBUM" -d act=update --silent --show-error -b "$COOKIE"
	fi
	echo "Successfully uploaded to album \"$ALBUM\"($ALBUM_ID)!"
else
	echo "Upload failed!"
fi
