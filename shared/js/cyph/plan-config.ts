import {CyphPlans} from '../proto';

/** Configuration options for Cyph plans. */
export const planConfig: Record<
	CyphPlans,
	{
		initialInvites: number;
		rank: number;
		storageCapGB: number;
		usernameMinLength: number;
		walletEarlyAccess?: string;
	}
> = {
	[CyphPlans.AnnualPremium]: {
		initialInvites: 10,
		rank: 2,
		storageCapGB: 25,
		usernameMinLength: 5,
		walletEarlyAccess: 'beta'
	},
	[CyphPlans.FoundersAndFriends]: {
		initialInvites: 15,
		rank: 4,
		storageCapGB: 100,
		usernameMinLength: 1,
		walletEarlyAccess: 'alpha'
	},
	[CyphPlans.Free]: {
		initialInvites: 2,
		rank: 0,
		storageCapGB: 1,
		usernameMinLength: 5
	},
	[CyphPlans.LifetimePlatinum]: {
		initialInvites: 15,
		rank: 3,
		storageCapGB: 100,
		usernameMinLength: 1,
		walletEarlyAccess: 'alpha'
	},
	[CyphPlans.MonthlyPremium]: {
		initialInvites: 5,
		rank: 1,
		storageCapGB: 5,
		usernameMinLength: 5
	}
};
