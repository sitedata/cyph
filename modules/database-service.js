/**
 * @file Simple implementation of subset of FirebaseDatabaseService logic for interoperability.
 */

import {proto, util} from '@cyph/sdk';
import {Storage} from '@google-cloud/storage';
import crypto from 'crypto';
import FCM from 'fcm-node';
import admin from 'firebase-admin';
import fs from 'fs';
import memoize from 'lodash-es/memoize.js';
import lz4 from 'lz4';
import os from 'os';
import * as brotli from './brotli.js';
import {sendMessageInternal} from './messaging-internal.js';

const {BinaryProto, StringProto} = proto;
const {deserialize, retryUntilSuccessful, serialize, sleep, uuid} = util;

/** Max number of bytes to upload to non-blob storage. */
const nonBlobStorageLimit = 8192;

export const initDatabaseService = memoize((config, isCloudFunction) => {
	if (typeof config === 'string') {
		const projectId = config;
		const configDir = `${os.homedir()}/.cyph`;
		const fcmKeyFilename = `${configDir}/firebase-credentials/${projectId}.fcm`;
		const keyFilename = `${configDir}/firebase-credentials/${projectId}.json`;

		config = {
			fcmServerKey: fs.readFileSync(fcmKeyFilename).toString().trim(),
			firebase: {
				credential: admin.credential.cert(
					JSON.parse(fs.readFileSync(keyFilename).toString())
				),
				databaseURL: `https://${projectId}.firebaseio.com`
			},
			project: {id: projectId},
			storage: {keyFilename, projectId}
		};
	}

	const app = admin.initializeApp(config.firebase, uuid());
	const auth = app.auth();
	const database = app.database();
	const messaging = new FCM(config.fcmServerKey);
	const storage = new Storage(config.storage).bucket(
		`${config.project.id}.appspot.com`
	);

	const archiveStorage =
		config.project.id === 'cyphme' && !isCloudFunction ?
			new Storage(config.storage).bucket('cyph-archive-storage') :
			undefined;

	const processURL = (namespace, url) => {
		if (!namespace || !url) {
			throw new Error('Invalid URL.');
		}

		return `${namespace.replace(/\./g, '_')}/${url.replace(/^\//, '')}`;
	};

	const getHash = bytes =>
		crypto.createHash('sha512').update(bytes).digest('hex');

	const retry = async f =>
		retryUntilSuccessful(async lastErr => {
			if (lastErr) {
				console.error(lastErr);
			}

			return Promise.race([
				f(),
				sleep(600000).then(() =>
					Promise.reject('Database method timeout.')
				)
			]);
		});

	const databaseService = {
		admin,
		app,
		auth,
		database,
		getHash,
		messaging,
		processURL,
		async getArchive (archiveName, timestamp)  {
			if (!archiveStorage) {
				throw new Error('Archive storage bucket is production-only.');
			}

			return brotli.decode(
				await retry(
					async () =>
						(
							await archiveStorage
								.file(
									`${archiveName}/${(timestamp instanceof
									Date ?
										timestamp.getTime() :
										timestamp
									).toString()}`
								)
								.download()
						)[0]
				)
			);
		},
		async getItem (
			namespace,
			url,
			proto,
			skipSignature,
			decompress,
			inlineDataOnly = false
		)  {
			const providedData =
				url && typeof url === 'object' ? url : undefined;

			url = processURL(namespace, providedData?.url || url);

			const {data, hash} =
				providedData ||
				(await retry(async () =>
					(await database.ref(url).once('value')).val()
				));

			let bytes = data ?
				Buffer.from(data, 'base64') :
			!inlineDataOnly ?
				await databaseService.storageGetItem(undefined, url, hash) :
				undefined;

			if (bytes === undefined) {
				return proto.create();
			}

			if (skipSignature) {
				bytes = bytes.slice(41256);
			}
			if (decompress) {
				bytes = lz4.decode(bytes);
			}

			return deserialize(proto, bytes);
		},
		async getOrSetDefault (
			namespace,
			url,
			proto,
			defaultValue,
			skipSignature,
			decompress
		)  {
			if (!url) {
				return defaultValue();
			}

			try {
				return await databaseService.getItem(
					namespace,
					url,
					proto,
					skipSignature,
					decompress
				);
			}
			catch {
				const value = await defaultValue();
				await databaseService.setItem(namespace, url, proto, value);
				return value;
			}
		},
		async getOrSetDefaultSimple (namespace, url, defaultValue)  {
			if (!url) {
				return defaultValue();
			}

			const fullURL = processURL(namespace, url);

			let value = (await database.ref(fullURL).once('value')).val();

			if (typeof value === 'string') {
				return value;
			}

			if (
				typeof value === 'object' &&
				typeof (value || {}).hash === 'string'
			) {
				value = await databaseService.getItem(
					namespace,
					url,
					StringProto
				);
			}
			else {
				value = await defaultValue();
			}

			await retry(async () => database.ref(fullURL).set(value));
			return value;
		},
		async hasItem (namespace, url)  {
			url = processURL(namespace, url);
			return (await database.ref(url).once('value')).exists();
		},
		async pushItem (namespace, url, proto, value)  {
			/* TODO: Copy the FirebaseDatabaseService implementation or use nextPushId */
			return databaseService.setItem(
				namespace,
				`${url}/${Date.now().toString()}`,
				proto,
				value
			);
		},
		async removeItem (namespace, url, deleteStorage = isCloudFunction)  {
			url = processURL(namespace, url);

			if (deleteStorage) {
				await Promise.all([
					database.ref(url).remove(),
					storage
						.deleteFiles({force: true, prefix: `${url}/`})
						.catch(() => {})
				]);
			}
			else {
				await retry(async () => database.ref(url).remove());
			}
		},
		async sendMessage (namespace, username, body, options)  {
			return sendMessageInternal(
				database,
				messaging,
				namespace,
				username,
				body,
				options
			);
		},
		async setArchive (archiveName, bytes)  {
			if (!archiveStorage) {
				throw new Error('Archive storage bucket is production-only.');
			}

			const timestamp = Date.now();
			const encodedBytes = brotli.encode(bytes);

			await retry(async () =>
				archiveStorage
					.file(`${archiveName}/${timestamp.toString()}`)
					.save(encodedBytes)
			);

			return timestamp;
		},
		async setItem (namespace, url, proto, value)  {
			return databaseService.setItemInternal(
				processURL(namespace, url),
				await serialize(proto, value)
			);
		},
		async setItemInternal (url, value, hash, dataAlreadySet)  {
			const [bytes, bytesBase64] =
				typeof value === 'string' ?
					[Buffer.from(value, 'base64'), value] :
					[value, Buffer.from(value).toString('base64')];
			const noBlobStorage = bytes.length <= nonBlobStorageLimit;

			if (hash === undefined) {
				hash = getHash(bytes);
			}

			if (!noBlobStorage) {
				await retry(async () =>
					storage.file(`${url}/${hash}`).save(bytes)
				);
			}
			else if (dataAlreadySet) {
				return;
			}

			await retry(async () =>
				database.ref(url).set({
					hash,
					timestamp: admin.database.ServerValue.TIMESTAMP,
					...(!noBlobStorage ?
						{} :
						{
							data: bytesBase64
						})
				})
			);
		},
		storage,
		storageGetItem: async (namespace, url, hash) =>
			retry(
				async () =>
					(
						await storage
							.file(
								`${
									namespace === undefined ?
										url :
										processURL(namespace, url)
								}/${hash}`
							)
							.download()
					)[0]
			)
	};

	return databaseService;
});
