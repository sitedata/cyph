import {AfterViewInit, Component, ElementRef, Input} from '@angular/core';
import {SafeUrl} from '@angular/platform-browser';
import * as $ from 'jquery';
import {fadeIn} from '../animations';
import {States} from '../chat/enums';
import {ChatMessageValueTypes, DataURIProto} from '../proto';
import {ChatService} from '../services/chat.service';
import {EnvService} from '../services/env.service';
import {FileTransferService} from '../services/file-transfer.service';
import {P2PWebRTCService} from '../services/p2p-webrtc.service';
import {P2PService} from '../services/p2p.service';
import {SessionService} from '../services/session.service';
import {StringsService} from '../services/strings.service';
import {trackByTransfer} from '../track-by/track-by-transfer';
import {readableByteLength} from '../util/formatting';
import {deserialize} from '../util/serialization';


/**
 * Angular component for main chat UI.
 */
@Component({
	animations: [fadeIn],
	selector: 'cyph-chat-main',
	styleUrls: ['../../../css/components/chat-main.scss'],
	templateUrl: '../../../templates/chat-main.html'
})
export class ChatMainComponent implements AfterViewInit {
	/** Indicates whether this is the accounts UI. */
	@Input() public accounts: boolean	= false;

	/** @see customBuildAudioImage */
	public readonly customBuildAudioImage?: Promise<SafeUrl>	= customBuildAudioImage ?
		deserialize(DataURIProto, customBuildAudioImage) :
		undefined
	;

	/** @see customBuildErrorImage */
	public readonly customBuildErrorImage?: Promise<SafeUrl>	= customBuildErrorImage ?
		deserialize(DataURIProto, customBuildErrorImage) :
		undefined
	;

	/** Indicates whether projected disconnection message should be hidden. */
	@Input() public hideDisconnectMessage: boolean;

	/** @see ChatMessageListComponent.messageCountInTitle */
	@Input() public messageCountInTitle: boolean;

	/** Indicates which version of the UI should be displayed. */
	@Input() public messageType: ChatMessageValueTypes	= ChatMessageValueTypes.Text;

	/** @see readableByteLength */
	public readonly readableByteLength: typeof readableByteLength	= readableByteLength;

	/** @see States */
	public readonly states: typeof States							= States;

	/** @see trackByTransfer */
	public readonly trackByTransfer: typeof trackByTransfer			= trackByTransfer;

	/** @inheritDoc */
	public ngAfterViewInit () : void {
		if (!this.elementRef.nativeElement || !this.envService.isWeb) {
			/* TODO: HANDLE NATIVE */
			return;
		}

		const $element	= $(this.elementRef.nativeElement);

		this.p2pService.init(
			() => $element.find('.video-call .me'),
			() => $element.find('.video-call .friend.stream')
		);
	}

	constructor (
		/** @ignore */
		private readonly elementRef: ElementRef,

		/** @see ChatService */
		public readonly chatService: ChatService,

		/** @see EnvService */
		public readonly envService: EnvService,

		/** @see FileTransferService */
		public readonly fileTransferService: FileTransferService,

		/** @see P2PService */
		public readonly p2pService: P2PService,

		/** @see P2PWebRTCService */
		public readonly p2pWebRTCService: P2PWebRTCService,

		/** @see SessionService */
		public readonly sessionService: SessionService,

		/** @see StringsService */
		public readonly stringsService: StringsService
	) {}
}
