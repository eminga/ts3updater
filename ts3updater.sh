#!/bin/sh
# Script Name: ts3updater.sh
# Author: eminga
# Version: 0.3
# Description: Installs and updates TeamSpeak 3 servers
# License: MIT License

cd "${0%/*}"

# determine os and cpu architecture
os=$(uname -s)
if [ "$os" = 'Darwin' ]; then
	jqfilter='.macos'
	tsdir='teamspeak3-server_mac'
else
	if [ "$os" = 'Linux' ]; then
		jqfilter='.linux'
		tsdir='teamspeak3-server_linux'
	elif [ "$os" = 'FreeBSD' ]; then
		jqfilter='.freebsd'
		tsdir='teamspeak3-server_freebsd'
	else
		echo 'Could not detect operating system. If you run Linux, FreeBSD, or macOS and get this error, please open an issue on Github.'
		exit 1
	fi

	architecture=$(uname -m)
	if [ "$architecture" = 'x86_64' ] || [ "$architecture" = 'amd64' ]; then
		jqfilter="${jqfilter}.x86_64"
		tsdir="${tsdir}_amd64"
	else
		jqfilter="${jqfilter}.x86"
		tsdir="${tsdir}_x86"
	fi
fi


server=$(curl -Ls 'https://www.teamspeak.com/versions/server.json' | jq "$jqfilter")

if [ -e "CHANGELOG" ]; then
	old_version=$(grep -Eom1 'Server Release \S*' "CHANGELOG" | cut -b 16-)
else
	old_version='-1'
fi

version=$(echo "$server" | jq -r '.version')

if [ "$old_version" != "$version" ]; then
	echo "New version available: $version"
	checksum=$(echo "$server" | jq -r '.checksum')
	link=$(echo "$server" | jq -r '.mirrors | values[]')

	# select random mirror
	i=$(echo "$link" | wc -l)
	i=$(((RANDOM % i) + 1))
	link=$(echo "$link" | sed -n ${i}p)

	tmpfile=$(mktemp)
	curl -Lo "$tmpfile" "$link"

	if command -v sha256sum > /dev/null 2>&1; then
		sha256=$(sha256sum "$tmpfile" | cut -b 1-64)
	elif command -v shasum > /dev/null 2>&1; then
		sha256=$(shasum -a 256 "$tmpfile" | cut -b 1-64)
	elif command -v sha256 > /dev/null 2>&1; then
		sha256=$(sha256 -q "$tmpfile")
	else
		echo 'Could not generate SHA256 hash. Please make sure at least one of these commands is available: sha256sum, shasum, sha256' 1>&2
		rm "$tmpfile"
		exit 1
	fi

	if [ "$checksum" = "$sha256" ]; then
		if [ -e "ts3server_startscript.sh" ]; then
        		./ts3server_startscript.sh stop
		else
			mkdir "$tsdir"; cd "$tsdir" && mv ../"$0" .
		fi

		tar --strip-components 1 -xf "$tmpfile" "$tsdir"
		./ts3server_startscript.sh start
	else
		echo 'Checksum of downloaded file is incorrect!' 1>&2
		rm "$tmpfile"
		exit 1
	fi

	rm "$tmpfile"
else
	echo "The installed server is up-to-date. Version: $version"
fi
