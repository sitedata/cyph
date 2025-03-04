# Sourced by bashrc within Docker

if [ ! "${CYPH_BASHRC_INIT_COMPLETE}" ] ; then


export GIT_EDITOR='vim'
export GOPATH='/home/gibson/go'
export ANDROID_HOME='/home/gibson/androidsdk'
export JAVA_HOME="$(
	update-alternatives --query javac | sed -n -e "s/Best: *\(.*\)\/bin\/javac/\1/p"
)"

export PATH="$(
	echo -n '/opt/local/bin:' ;
	echo -n '/opt/local/sbin:' ;
	echo -n '/usr/local/opt/go/libexec/bin:' ;
	echo -n "/usr/lib/go-1.16/bin:" ;
	echo -n "${GOPATH}/bin:" ;
	echo -n "${ANDROID_HOME}/platform-tools:" ;
	echo -n "${ANDROID_HOME}/tools:" ;
	echo -n "${PATH}:" ;
	echo -n '/node_modules/.bin'
)"

if [ ! -f ~/.gnupg/keycache -a -d ~/.gnupg.original ] ; then
	rm -rf ~/.gnupg 2> /dev/null
	cp -a ~/.gnupg.original ~/.gnupg
fi
export GPG_TTY="$(tty)"
eval $(gpg-agent --daemon 2> /dev/null) &> /dev/null

eval $(ssh-agent 2> /dev/null) &> /dev/null

if [ -f ~/google-cloud-sdk/path.bash.inc ] ; then
	source ~/google-cloud-sdk/path.bash.inc
fi
if [ -f ~/google-cloud-sdk/completion.bash.inc ] ; then
	source ~/google-cloud-sdk/completion.bash.inc
fi


export NEWLINE=$'\n'
export NODE_OPTIONS='--max-old-space-size=12288'

bindmount () {
	if [ "${CIRCLECI}" -o ! -d /cyph ] ; then
		rm -rf "${2}" 2> /dev/null
		cp -a "${1}" "${2}"
	else
		mkdir "${2}" 2> /dev/null
		sudo mount --bind "${1}" "${2}"
	fi
}

checkfail () {
	if (( $? )) ; then
		fail "${*}"
	fi
}

checkfailretry () {
	if (( $? )) ; then
		cd $(readlink -e /proc/${PPID}/cwd)
		$(ps -o args= ${$} | head -n2 | tail -n1)
		exit $?
	fi
}

download () {
	log "Downloading: ${*}"
	curl -s --compressed --retry 50 ${1} > ${2}
}

fail () {
	if [ "${*}" ] ; then
		log "${*}\n\nFAIL"
	else
		log 'FAIL'
	fi
	exit 1
}

getBoolArg () {
	if [ "${1}" == 'on' ] ; then
		echo 'true'
	fi
}

ipfsAdd () {
	f="$(realpath "${1}")"

	hash="$(ipfsAddNative ${f})"
	while [ ! "${hash}" ] ; do
		sleep 5
		hash="$(ipfsAddNative ${f})"
	done

	pinataHash=''
	while [ "${pinataHash}" != "${hash}" ] ; do
		export pinataResponse="$(
			curl -s https://api.pinata.cloud/pinning/pinFileToIPFS \
				-H "pinata_api_key: $(head -n1 ~/.cyph/pinata.key)" \
				-H "pinata_secret_api_key: $(tail -n1 ~/.cyph/pinata.key)" \
				-F "file=@${f}"
		)"
		pinataHash="$(node -e 'console.log(JSON.parse(process.env.pinataResponse).IpfsHash)')"
	done

	curl -i -s -X POST https://www.eternum.io/api/pin/ \
		-H "Authorization: Bearer $(cat ~/.cyph/eternum.key)" \
		-H 'Content-Type: application/json' \
		-d "{\"hash\": \"${hash}\"}" \
	&> /dev/null

	echo "${hash}"
}

ipfsAddNative () {
	ipfsInit
	ipfs add -q "${@}"
}

export ipfsGatewaysCache=""

ipfsGateways () {
	if [ ! "${ipfsGatewaysCache}" ] ; then
		ipfsGatewaysCache="$(node -e "console.log(
			$(/cyph/commands/ipfsgateways.js --skip-uptime-check).map(o => o.url).join('\\n')
		)")"
	fi

	echo -n "${ipfsGatewaysCache}"
}

ipfsHash () {
	ipfs add -qn "${1}"
}

ipfsInit () {
	newDaemonInit=''
	while ! ps ux | grep 'ipfs daemon' | grep -v grep &> /dev/null ; do
		newDaemonInit=true
		rm ~/.ipfs/repo.lock &> /dev/null
		bash -c 'ipfs daemon &' &> /dev/null
		sleep 5
	done

	while [ "${newDaemonInit}" ] ; do
		ipfs swarm peers &> /dev/null && break
		sleep 1
	done
}

export defaultGateway='https://gateway.ipfs.io/ipfs/:hash'

ipfsWarmUp () {
	verify=''
	if [ "${1}" == '--verify' ] ; then
		verify=true
		shift
	fi

	hash="${1}"
	shift

	gateway="${defaultGateway}"
	if [ "${1}" ] ; then
		gateway="${1}"
		shift
	fi

	url="$(echo "${gateway}" | sed "s|:hash|${hash}|")"

	if [ ! "${verify}" ] ; then
		curl -s -m 30 "${url}" &> /dev/null
		return
	fi

	f="/tmp/$(echo "${url}" | sha).ipfswarmup"

	while true ; do
		rm "${f}" 2> /dev/null
		echo wget "${url}" -T 30 -t 1 -O "${f}"
		wget "${url}" -T 30 -t 1 -O "${f}"

		# Switch to this if concurrency support is needed:
		# if [ -f "${f}" ] && [ "$(stat --printf='%s' "${f}")" != '0' ] ; then
		if [ -f "${f}" ] && [ "$(ipfsHash "${f}")" == "${hash}" ] ; then
			break
		fi
	done

	rm "${f}" 2> /dev/null
}

ipfsWarmUpAll () {
	for gateway in $(ipfsGateways | grep -v "${defaultGateway}") ; do
		for f in "${@}" ; do
			ipfsWarmUp "$(cat "${f}")" "${gateway}"
		done &
	done

	for f in "${@}" ; do
		ipfsWarmUp --verify "$(cat "${f}")"
	done
}

log () {
	echo -e "\n\n\n${*} ($(date))\n"
}

notify () {
	/cyph/commands/notify.js "${@}" > /dev/null

	if [ "${1}" == '--admins' ] ; then
		shift
	fi

	log "${*}"
}

parseArgs () {
	argbash-init "${@}" - |
		argbash - |
		tr '\n' '☁' |
		perl -pe 's/.*START OF CODE GENERATED BY Argbash(.*)END OF CODE GENERATED BY Argbash.*/#$1/g' |
		tr '☁' '\n'
}

pass () {
	if [ "${*}" ] ; then
		log "${*}\n\nPASS"
	else
		log 'PASS'
	fi
	exit 0
}

sha () {
	shasum -a 512 "${@}" | awk '{print $1}'
}

unbindmount () {
	unbindmountInternal "${1}"
	rm -rf "${1}"
}

unbindmountInternal () {
	if [ ! "${CIRCLECI}" -a -d /cyph ] ; then
		sudo umount "${1}"
	fi
}

export -f bindmount
export -f checkfail
export -f checkfailretry
export -f download
export -f fail
export -f getBoolArg
export -f ipfsAdd
export -f ipfsAddNative
export -f ipfsGateways
export -f ipfsHash
export -f ipfsInit
export -f ipfsWarmUp
export -f ipfsWarmUpAll
export -f log
export -f notify
export -f parseArgs
export -f pass
export -f sha
export -f unbindmount
export -f unbindmountInternal


export FIREBASE_CONFIG='{}'


# Setup for documentation generation
if [ -d /cyph ] ; then
	cp -f /cyph/LICENSE /cyph/README.md /cyph/cyph.app/
	echo -e '\n---\n' >> /cyph/cyph.app/README.md
	cat /cyph/PATENTS >> /cyph/cyph.app/README.md
fi


# Workaround for localhost not working in CircleCI
if [ "${CIRCLECI}" ] ; then
	sed -i 's|localhost|0.0.0.0|g' /cyph/commands/serve.sh /cyph/*/protractor.conf.js
fi


export CYPH_BASHRC_INIT_COMPLETE=true
fi
