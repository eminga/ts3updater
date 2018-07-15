#!/bin/sh
# Script Name: ts3updater.sh
# Author: eminga
# Version: 1.4
# Description: Installs and updates TeamSpeak 3 servers
# License: MIT License

cd "$(dirname "$0")" || exit 1

# check whether the dependencies curl, jq, and tar are installed
if ! command -v curl > /dev/null 2>&1; then
	echo 'curl not found' 1>&2
	exit 1
elif ! command -v jq > /dev/null 2>&1; then
        echo 'jq not found' 1>&2
        exit 1
elif ! command -v tar > /dev/null 2>&1; then
        echo 'tar not found' 1>&2
        exit 1
fi

# determine os and cpu architecture
os=$(uname -s)
if [ "$os" = 'Darwin' ]; then
	jqfilter='.macos'
else
	if [ "$os" = 'Linux' ]; then
		jqfilter='.linux'
	elif [ "$os" = 'FreeBSD' ]; then
		jqfilter='.freebsd'
	else
		echo 'Could not detect operating system. If you run Linux, FreeBSD, or macOS and get this error, please open an issue on Github.' 1>&2
		exit 1
	fi

	architecture=$(uname -m)
	if [ "$architecture" = 'x86_64' ] || [ "$architecture" = 'amd64' ]; then
		jqfilter="${jqfilter}.x86_64"
	else
		jqfilter="${jqfilter}.x86"
	fi
fi


server=$(curl -Ls 'https://www.teamspeak.com/versions/server.json' | jq "$jqfilter")

if [ -e 'CHANGELOG' ]; then
	old_version=$(grep -Eom1 'Server Release \S*' "CHANGELOG" | cut -b 16-)
else
	old_version='-1'
fi

version=$(printf '%s' "$server" | jq -r '.version')

if [ "$old_version" != "$version" ]; then
	echo "New version available: $version"
	checksum=$(printf '%s' "$server" | jq -r '.checksum')
	links=$(printf '%s' "$server" | jq -r '.mirrors | values[]')

	# order mirrors randomly
	if command -v shuf > /dev/null 2>&1; then
		links=$(printf '%s' "$links" | shuf)
	fi

	tmpfile=$(mktemp)
	i=1
	n=$(printf '%s\n' "$links" | wc -l)

	# try to download from mirrors until download is successful or all mirrors tried
	while [ "$i" -le "$n" ]; do
		link=$(printf '%s' "$links" | sed -n "$i"p)
		echo "Downloading the file $link"
		curl -Lo "$tmpfile" "$link"
		if [ $? = 0 ]; then
			i=$(( n + 1 ))
		else
			i=$(( i + 1 ))
		fi
	done

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
		tsdir=$(tar -tf "$tmpfile" | grep -m1 /)
		if [ ! -e '.ts3server_license_accepted' ]; then
			tar --to-stdout -xf "$tmpfile" "$tsdir"LICENSE
			echo -n "Accept license agreement (y/N)? "
			read answer
			if ! echo "$answer" | grep -iq "^y" ; then
				rm "$tmpfile"
				exit 1
			fi
		fi
		if [ -e 'ts3server_startscript.sh' ]; then
        		./ts3server_startscript.sh stop
		else
			mkdir "$tsdir" || { echo 'Could not create installation directory. If you wanted to upgrade an existing installation, make sure to place this script INSIDE the existing installation directory.' 1>&2; rm "$tmpfile"; exit 1; }
			cd "$tsdir" && mv ../"$(basename "$0")" .
		fi

		tar --strip-components 1 -xf "$tmpfile" "$tsdir"
		touch .ts3server_license_accepted
		if [ "$1" != '--dont-start' ]; then
			./ts3server_startscript.sh start "$@"
		fi
	else
		echo 'Checksum of downloaded file is incorrect!' 1>&2
		rm "$tmpfile"
		exit 1
	fi

	rm "$tmpfile"
else
	echo "The installed server is up-to-date. Version: $version"
fi
