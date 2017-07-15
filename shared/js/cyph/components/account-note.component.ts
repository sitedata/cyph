import {Component, OnInit} from '@angular/core';
import {ActivatedRoute, Router} from '@angular/router';
import {AccountFileRecord, IAccountFileRecord} from '../../proto';
import {AccountContactsService} from '../services/account-contacts.service';
import {AccountFilesService} from '../services/account-files.service';
import {AccountDatabaseService} from '../services/crypto/account-database.service';
import {EnvService} from '../services/env.service';
import {UtilService} from '../services/util.service';


/**
 * Angular component for an individual note.
 */
@Component({
	selector: 'cyph-account-note',
	styleUrls: ['../../../css/components/account-note.scss'],
	templateUrl: '../../../templates/account-note.html'
})
export class AccountNoteComponent implements OnInit {
	/** Current note. */
	public note?: IAccountFileRecord;

	/** @inheritDoc */
	public ngOnInit () : void {
		this.activatedRouteService.params.subscribe(async o => {
			try {
				const id: string|undefined	= o.id;

				if (!id) {
					throw new Error('Invalid note ID.');
				}

				this.note	= await this.accountFilesService.getFile(
					id,
					AccountFileRecord.RecordTypes.Note
				);
			}
			catch (_) {
				this.routerService.navigate(['404']);
			}
		});
	}

	constructor (
		/** @ignore */
		private readonly activatedRouteService: ActivatedRoute,

		/** @ignore */
		private readonly routerService: Router,

		/** @see AccountContactsService */
		public readonly accountContactsService: AccountContactsService,

		/** @see AccountDatabaseService */
		public readonly accountDatabaseService: AccountDatabaseService,

		/** @see AccountFilesService */
		public readonly accountFilesService: AccountFilesService,

		/** @see EnvService */
		public readonly envService: EnvService,

		/** @see UtilService */
		public readonly utilService: UtilService
	) {}
}
