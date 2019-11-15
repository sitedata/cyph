import {ChangeDetectionStrategy, Component, OnInit} from '@angular/core';
import {BaseProvider} from '../../base-provider';
import {AccountService} from '../../services/account.service';
import {AccountDatabaseService} from '../../services/crypto/account-database.service';
import {EnvService} from '../../services/env.service';
import {StringsService} from '../../services/strings.service';

/**
 * Angular component for account post register UI.
 */
@Component({
	changeDetection: ChangeDetectionStrategy.OnPush,
	selector: 'cyph-account-post-register',
	styleUrls: ['./account-post-register.component.scss'],
	templateUrl: './account-post-register.component.html'
})
export class AccountPostRegisterComponent extends BaseProvider
	implements OnInit {
	/** @inheritDoc */
	public ngOnInit () : void {
		this.accountService.setHeader('IMPORTANT: Confirm Your Master Key');
		this.accountService.transitionEnd();
		this.accountService.resolveUiReady();
	}

	constructor (
		/** @see AccountService */
		public readonly accountService: AccountService,

		/** @see AccountDatabaseService */
		public readonly accountDatabaseService: AccountDatabaseService,

		/** @see EnvService */
		public readonly envService: EnvService,

		/** @see StringsService */
		public readonly stringsService: StringsService
	) {
		super();
	}
}
