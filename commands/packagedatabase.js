#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const glob = require('glob/sync');
const os = require('os');
const path = require('path');
const {updateRepos} = require('./updaterepos');

const repoPath = `${os.homedir()}/.cyph/repos/cdn`;

const options = {cwd: repoPath};
const globOptions = {cwd: repoPath, symlinks: true};

const packageDatabase = () => {
	updateRepos();

	return glob('**/pkg.gz', globOptions)
		.map(pkg => [
			pkg
				.split('/')
				.slice(0, -1)
				.join('/'),
			childProcess
				.spawnSync('gunzip', ['-c', pkg], options)
				.stdout.toString()
				.trim(),
			parseFloat(
				childProcess
					.spawnSync(
						'gunzip',
						['-c', pkg.slice(0, -6) + 'current.gz'],
						options
					)
					.stdout.toString()
			) || 0,
			fs.existsSync(path.join(repoPath, pkg.slice(0, -6) + 'pkg.ipfs')) ?
				{
					integrityHash: fs
						.readFileSync(
							path.join(repoPath, pkg.slice(0, -6) + 'pkg.br')
						)
						.toString('hex'),
					ipfsHash: fs
						.readFileSync(
							path.join(repoPath, pkg.slice(0, -6) + 'pkg.ipfs')
						)
						.toString()
						.trim()
				} :
				{}
		])
		.reduce(
			(packages, [packageName, root, timestamp, uptime]) => ({
				...packages,
				[packageName]: {
					package: {
						root,
						subresources: glob(
							`${packageName}/**/*.ipfs`,
							globOptions
						)
							.map(ipfs => [
								ipfs.slice(packageName.length + 1, -5),
								fs
									.readFileSync(path.join(repoPath, ipfs))
									.toString()
									.trim()
							])
							.reduce(
								(subresources, [subresource, hash]) => ({
									...subresources,
									[subresource]: hash
								}),
								{}
							)
					},
					timestamp,
					uptime
				}
			}),
			{}
		);
};

if (require.main === module) {
	if (process.argv[2]) {
		fs.writeFileSync(process.argv[2], JSON.stringify(packageDatabase()));
	}
	else {
		console.log(JSON.stringify(packageDatabase()));
	}
}
else {
	module.exports = {packageDatabase};
}
