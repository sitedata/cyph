import {ChangeDetectionStrategy, Component} from '@angular/core';
import {ActivatedRoute} from '@angular/router';
import {AccountChatService} from '../../services/account-chat.service';
import {AccountContactsService} from '../../services/account-contacts.service';
import {AccountFilesService} from '../../services/account-files.service';
import {AccountService} from '../../services/account.service';
import {AccountAuthService} from '../../services/crypto/account-auth.service';
import {AccountDatabaseService} from '../../services/crypto/account-database.service';
import {DatabaseService} from '../../services/database.service';
import {EnvService} from '../../services/env.service';
import {ScrollService} from '../../services/scroll.service';
import {SessionService} from '../../services/session.service';
import {StringsService} from '../../services/strings.service';
import {AccountComposeComponent} from '../account-compose';

/**
 * Angular component for account compose UI.
 */
@Component({
	changeDetection: ChangeDetectionStrategy.OnPush,
	selector: 'cyph-account-compose-no-providers',
	styleUrls: ['../account-compose/account-compose.component.scss'],
	templateUrl: '../account-compose/account-compose.component.html'
})
export class AccountComposeNoProvidersComponent extends AccountComposeComponent {
	/** @inheritDoc */
	protected readonly hasOwnProviders: boolean = false;

	constructor (
		accountAuthService: AccountAuthService,
		accountChatService: AccountChatService,
		accountContactsService: AccountContactsService,
		accountFilesService: AccountFilesService,
		databaseService: DatabaseService,
		scrollService: ScrollService,
		sessionService: SessionService,
		activatedRoute: ActivatedRoute,
		accountService: AccountService,
		accountDatabaseService: AccountDatabaseService,
		envService: EnvService,
		stringsService: StringsService
	) {
		super(
			accountAuthService,
			accountChatService,
			accountContactsService,
			accountFilesService,
			databaseService,
			scrollService,
			sessionService,
			activatedRoute,
			accountService,
			accountDatabaseService,
			envService,
			stringsService
		);
	}
}
