#!/bin/bash


set -e
cd $(cd "$(dirname "$0")" ; pwd)

test=''
if [ "${1}" == '--test' ] ; then
	echo -e 'TEST BUILD\n\n'
	test=true
	shift
fi

allPlatforms=''
android=''
debug=''
electron=''
iOS=''
iOSEmulator=''
if [ ! "${1}" ] ; then
	allPlatforms=true
elif [ "${1}" == 'android' ] ; then
	android=true
	shift
elif [ "${1}" == 'androidDebug' ] ; then
	android=true
	debug=true
	shift
elif [ "${1}" == 'electron' ] ; then
	electron=true
	shift
elif [ "${1}" == 'ios' ] ; then
	iOS=true
	shift
elif [ "${1}" == 'iOSEmulator' ] ; then
	iOS=true
	iOSEmulator=true
	shift
else
	echo 'Invalid platform.'
	exit 1
fi

password=''
passwordWindows=''
if [ "${1}" ] ; then
	password="${1}"
	shift
	passwordWindows="${1}"
	shift
elif [ ! "${debug}" ] && ( [ "${allPlatforms}" ] || [ "${android}" ] || [ "${electron}" ] ) ; then
	echo -n 'Password: '
	read -s password
	echo
	echo -n 'Password (Windows): '
	read -s passwordWindows
	echo
fi

if [ "${allPlatforms}" ] ; then
	rm -rf cordova-build* 2> /dev/null

	./build.sh android "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.android
	./build.sh --test android "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.android-test

	./build.sh electron "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.electron
	./build.sh --test electron "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.electron-test

	./build.sh ios "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.ios
	./build.sh --test ios "${password}" "${passwordWindows}" || exit 1
	mv cordova-build cordova-build.ios-test

	./build.sh androidDebug || exit 1
	mv cordova-build cordova-build.android-debug
	./build.sh --test androidDebug || exit 1
	mv cordova-build cordova-build.android-debug-test

	mkdir -p cordova-build/build
	cp -a cordova-build.*/build/* cordova-build/build/
	exit
fi


export CSC_KEY_PASSWORD="${passwordWindows}"
export CSC_KEYCHAIN="${HOME}/.cyph/nativereleasesigning/apple/cyph.keychain"
export ORG_GRADLE_PROJECT_cdvMinSdkVersion="$(grep android-minSdkVersion config.xml | perl -pe 's/.*value="(.*?)".*/\1/g')"

if [ -d cordova-build ] ; then
	rm -rf cordova-build
fi
mkdir -p cordova-build/build

for f in $(ls -a | grep -vP \
	'^(\.|\.\.|cordova-build.*|node_modules|package-lock.json|platforms|plugins)$'
) ; do
	cp -a "${f}" cordova-build/
done

cd cordova-build
mkdir node_modules platforms plugins

cd www
for f in $(find . -type f -name '*.patch' | perl -pe 's/^\.\/(.*)\.patch/\1/g') ; do
	cp ../../../websign/${f} ${f}
	patch ${f} ${f}.patch
	rm ${f}.patch
done
cd ..

echo -e '\n\nADD PLATFORMS\n\n'

sed -i "s|~|${HOME}|g" build.json

packageName='cyph'
iOSDevelopmentIdentity='Apple Development'
iOSDevelopmentProvisioningProfile='6f59e786-6771-435e-9dcd-f3d142252cef'
iOSDistributionIdentity='Apple Distribution'
iOSDistributionProvisioningProfile='a6dfd760-2d77-4a59-95af-5aa972bbcead'

if [ "${test}" ] ; then
	packageName='test.cyph'
	iOSDevelopmentProvisioningProfile='172e104f-8098-4fa8-8ec9-e3a98b8973c8'
	iOSDistributionProvisioningProfile='9ab28e3e-d0c4-42ef-9e9d-d9d71df1c2fc'

	cat config.xml |
		grep -v cordova-plugin-privacyscreen |
		sed 's|<name>Cyph</name>|<name>CyphTest</name>|g' |
		perl -pe 's/com\.cyph\.(app|desktop)/com.cyph.test/g' |
		perl -pe 's/(android:largeHeap="true")/\1 android:usesCleartextTraffic="true"/g' |
		perl -pe 's/([":])(cyph|burner)\./\1staging.\2./g' \
	> config.xml.new
	mv config.xml.new config.xml

	if [ "${android}" ] ; then
		cat config.xml |
			grep -v cordova-plugin-ionic-webview \
		> config.xml.new
		mv config.xml.new config.xml
	fi

	cat package.json |
		sed 's|"URL_SCHEME": "cyph"|"URL_SCHEME": "cyph-test"|g' |
		perl -pe 's/"(cyph|burner)\./"staging.\1./g' \
	> package.json.new
	mv package.json.new package.json

	sed -i 's|macOS_Distribution|Test_macOS_Distribution|g' build.json

	mv google-services.test.json google-services.json
	mv GoogleService-Info.test.plist GoogleService-Info.plist
	patch www/js/main.js main.js.test.patch
fi

npm install

if [ ! "${electron}" ] ; then
	cd www/nodejs-project
	npm install
	cd ../..
fi

if [ ! "${test}" ] ; then
	while ! npm run updateDefaultCacheValues ; do echo 'Retrying' ; done
fi


initPlatform () {
	platform="${1}"

	cp package.json package.json.old

	node -e "
		const document = new (require('xmldom').DOMParser)().
			parseFromString(fs.readFileSync('config.xml').toString());

		const otherPlatforms = Array.from(
			document.documentElement.getElementsByTagName('platform')
		).filter(elem => elem.getAttribute('name') !== '${platform}');

		for (const otherPlatform of otherPlatforms) {
			otherPlatform.parentNode.removeChild(otherPlatform);
		}

		fs.writeFileSync(
			'config.xml',
			new (require('xmldom').XMLSerializer)().serializeToString(document)
		);
	"

	npx cordova platform add ${platform}

	sed -i 's/.*<engine.*//g' config.xml

	for plugin in $(node -e "console.log(
		Array.from(
			new (require('xmldom').DOMParser)().
				parseFromString(fs.readFileSync('config.xml').toString()).
				documentElement.getElementsByTagName('plugin')
		).
			map(
				elem => \`\${elem.getAttribute('name')}@\${elem.getAttribute('spec')}\`
			).
			join('\n')
	)") ; do node -e "process.exit(child_process.spawnSync(
		'npx',
		[
			'cordova',
			'plugin',
			'add',
			'${plugin}',
			...Array.from(
				Object.entries(
					JSON.parse(
						fs.readFileSync('package.json.old').toString()
					).cordova.plugins['${plugin}'.replace(/(.)@.*/g, '\$1')] || {}
				)
			).
				map(([k, v]) => ['--variable', \`\${k}=\${v}\`]).
				reduce((a, b) => a.concat(b), [])
		],
		{stdio: 'inherit'}
	).status)" ; done

	node node_modules/patch-package/index.js

	node -e "
		const oldPackageJSON = JSON.parse(fs.readFileSync('package.json.old').toString());
		const packageJSON = JSON.parse(fs.readFileSync('package.json').toString());

		const dependencies = {...packageJSON.dependencies, ...packageJSON.devDependencies};

		const getDependencies = filter => Object.entries(dependencies)
			.filter(filter)
			.reduce((o, [k, v]) => ({...o, [k]: v}), {});

		packageJSON.dependencies =
			getDependencies(([k]) => k in oldPackageJSON.dependencies)
		;
		packageJSON.devDependencies =
			getDependencies(([k]) => !(k in oldPackageJSON.dependencies))
		;

		fs.writeFileSync('package.json', JSON.stringify(packageJSON));
	"

	rm package.json.old
}


if [ "${android}" ] ; then
	initPlatform android
fi

if [ "${electron}" ] ; then
	initPlatform electron
fi

if [ "${iOS}" ] ; then
	if ! which gem > /dev/null ; then
		brew install ruby
	fi

	if ! which pod > /dev/null ; then
		brew install cocoapods
	fi

	npm install xcode
	initPlatform ios

	chmod +x plugins/cordova-plugin-iosrtc/extra/hooks/iosrtc-swift-support.js

	# https://github.com/phonegap/phonegap-plugin-push/issues/2872#issuecomment-588179073
	cat >> platforms/ios/Podfile << EndOfMessage
		post_install do |lib|
			lib.pods_project.targets.each do |target|
				target.build_configurations.each do |config|
					config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
				end
			end
		end
EndOfMessage

	pod install --project-directory=platforms/ios
fi


echo -e '\n\nBUILD\n\n'

if [ "${iOSEmulator}" ] ; then
	npx cordova build --debug --emulator --verbose || exit 1
	exit
fi

if [ "${debug}" ] ; then
	npx cordova build --debug --device --verbose || exit 1
	cp platforms/android/app/build/outputs/apk/debug/app-debug.apk build/${packageName}.debug.apk
	exit
fi


if [ "${android}" ] ; then
	npx cordova build android --release --device --verbose -- \
		--keystore="${HOME}/.cyph/nativereleasesigning/android/cyph.jks" \
		--alias=cyph \
		--storePassword="${password}" \
		--password="${password}" \
		--packageType=apk

	cp platforms/android/app/build/outputs/apk/release/app-release.apk build/${packageName}.apk || exit 1
fi

if [ "${electron}" ] ; then
	cp -f electron.js platforms/electron/platform_www/cdv-electron-main.js

	mkdir -p platforms/electron/build-res/appx 2> /dev/null
	cp -f res/icon/windows/* platforms/electron/build-res/appx/

	# npx cordova build electron --release --verbose

	# https://github.com/electron-userland/electron-builder/issues/4151#issuecomment-520663362
	find . -type f -name 'electronMac.js' -exec sed -i 's|\${helperBundleIdentifier}\.\${postfix}|${helperBundleIdentifier}.${postfix.replace(/[^a-z0-9]/gim,"")}|g' {} \;

	npx electron-rebuild

	# Workaround for Cordova and/or Electron and/or Parallels bug
	cp build.json build.json.bak
	electronScript="
		const buildConfig = JSON.parse(fs.readFileSync('build.json').toString());
		const {linux, mac, windows} = buildConfig.electron;

		windows.signing.release.certificatePassword = '${passwordWindows}';

		const macDmgDebug = {
			...mac,
			package: ['dmg']
		};

		const windowsExe = {
			...windows,
			package: ['nsis']
		};

		const windowsExeDebug = {
			...windowsExe,
			signing: undefined
		};

		const windowsAppStore = {
			...windows,
			package: ['appx'],
			signing: undefined
		};

		const build = (config, docker = false) => {
			fs.writeFileSync('build.json', JSON.stringify({electron: config}));

			if (docker) {
				child_process.spawnSync(
					'docker',
					[
						'run',
						'-it',
						'-v',
						\`\${process.cwd()}:/build\`,
						'snapcore/snapcraft:stable',
						'bash',
						'-c',
						'cd /build ; ' +
							'apt-get update ; ' +
							'apt-get install -y curl apt-transport-https lsb-release software-properties-common ; ' +
							'echo \"deb https://deb.nodesource.com/node_16.x \$(' +
								'grep DISTRIB_CODENAME /etc/lsb-release | ' +
								'tr \\'=\\' \\' \\' | ' +
								'awk \\'{print \$2}\\'' +
							') main\" >> /etc/apt/sources.list ; ' +
							'curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - ; ' +
							'add-apt-repository -y ppa:deadsnakes/ppa ; ' +
							'apt-get update ; ' +
							'apt-get install -y build-essential git nodejs python3.6 ; ' +
							'update-alternatives --install /usr/bin/python python /usr/bin/python3.6 10 ; ' +
							'npx cordova telemetry off ; ' +
							'npx electron-rebuild ; ' +
							'while true ; do npx cordova build electron --release --verbose && break ; done'
					],
					{stdio: 'inherit'}
				);
				return;
			}

			while (true) {
				const {status} = child_process.spawnSync(
					'npx',
					['cordova', 'build', 'electron', '--release', '--verbose'],
					{stdio: 'inherit'}
				);

				if (status === 0) {
					break;
				}
			}
		};

		// Workaround for Cordova oversight
		const originalOptionsSet = 'builder_util_1.deepAssign({}, this.packager.platformSpecificBuildOptions, this.packager.config.appx);';

		fs.writeFileSync(
			'node_modules/app-builder-lib/out/targets/AppxTarget.js',
			fs.readFileSync(
				'node_modules/app-builder-lib/out/targets/AppxTarget.js'
			).toString().replace(
				originalOptionsSet,
				originalOptionsSet + '\n' +
					'this.options.applicationId = \'' + windows.applicationId + '\';\n' +
					'this.options.identityName = this.options.applicationId;\n' +
					'this.options.publisher = \'' + windows.publisher + '\';\n'
			)
		);
	"

	node -e "
		${electronScript}

		build({mac});
		build({windows: windowsExe});
		build({windows: windowsAppStore});
	"
	mv platforms/electron/build/mas-universal/*.pkg build/${packageName}.pkg || exit 1
	mv platforms/electron/build/*\ arm64.appx build/${packageName}.arm64.appx || exit 1
	mv platforms/electron/build/*.appx build/${packageName}.x64.appx || exit 1
	mv platforms/electron/build/*.dmg build/${packageName}.dmg || exit 1
	mv platforms/electron/build/*.exe build/${packageName}.exe || exit 1

	cp -f build.json.bak build.json
	node -e "
		$(echo "${electronScript}" | sed 's|--release|--debug|g')

		build({mac: macDmgDebug});
		build({windows: windowsExeDebug});
	"
	mv platforms/electron/build/*.dmg build/${packageName}.debug.dmg || exit 1
	mv platforms/electron/build/*.exe build/${packageName}.debug.exe || exit 1

	cp -f build.json.bak build.json
	node -e "
		${electronScript}

		build({linux}, true);
	"
	# cp platforms/electron/build/*.AppImage build/${packageName}.AppImage || exit 1
	# cp platforms/electron/build/*.deb build/${packageName}.deb || exit 1
	# cp platforms/electron/build/*.rpm build/${packageName}.rpm || exit 1
	cp platforms/electron/build/*_amd64.snap build/${packageName}.amd64.snap || exit 1
	# cp platforms/electron/build/*_arm64.snap build/${packageName}.arm64.snap || exit 1
	cp platforms/electron/build/*_armhf.snap build/${packageName}.armhf.snap || exit 1

	mv build.json.bak build.json
fi

if [ "${iOS}" ] ; then
	echo 0 > www/NODEJS_MOBILE_BUILD_NATIVE_MODULES_VALUE.txt
	find www/nodejs-project \( \
		-name '*.node' \
		-or -name '*.o' \
		-or -name '*.a' \
		-or -name '*.framework' \
	\) -delete

	npx cordova build ios --debug --device --verbose \
		--codeSignIdentity="${iOSDevelopmentIdentity}" \
		--developmentTeam='SXZZ8WLPV2' \
		--packageType='development' \
		--provisioningProfile="${iOSDevelopmentProvisioningProfile}"

	if [ ! -f platforms/ios/build/device/Cyph*.ipa ] ; then exit 1 ; fi

	mv platforms/ios/build/device ios-debug

	npx cordova build ios --release --device --verbose \
		--codeSignIdentity="${iOSDistributionIdentity}" \
		--developmentTeam='SXZZ8WLPV2' \
		--packageType='app-store' \
		--provisioningProfile="${iOSDistributionProvisioningProfile}"

	if [ ! -f platforms/ios/build/device/Cyph*.ipa ] ; then exit 1 ; fi

	mv platforms/ios/build/device ios-release

	mkdir platforms/ios/build/device
	mv ios-debug platforms/ios/build/device/debug
	mv ios-release platforms/ios/build/device/release

	cp platforms/ios/build/device/debug/Cyph*.ipa build/${packageName}.debug.ipa
	cp platforms/ios/build/device/release/Cyph*.ipa build/${packageName}.ipa
fi
