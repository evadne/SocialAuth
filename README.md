# SocialAuth

Painless Facebook & Twitter auth on iOS 6+.

## Play

Look at the [Sample App](https://github.com/evadne/SocialAuth-Sample). Check out the [Sample Video](http://vimeo.com/evadne/socialauth-debut). Try to break it.

## Use

Use `SAAccountStore`. Request an arbitrary account by calling `-requestAccountTyped:withOptions:completion:`. For more information, check out the sample app — this is the representative portion:

	ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
	[self.accountStore requestAccountTyped:accountType withOptions:nil completion:^(BOOL didFinish, ACAccount *account, NSError *error) {
		if (account) {
			//	use it!
		}
	}];

## Behavior Matrix

Access State | No Accounts | One Account | Many Accounts
- | - | - | -
Never Granted or Denied | Bails on Settings | Asks for Permission | Asks for Permission
Explicitly Granted      | Bails on Settings | Succeeds with Account | Presents Picker
Explicitly Denied       | Propagates Error | Propagates Error | Propagates Error

* **Bails on Settings:** SocialAuth will present an UIAlertView asking the customer to go sign in thru Settings.app. SocialAuth *does not* invoke the callback in this case.
* **Asks for Permission:** SocialAuth will trigger a permission dialog and ask the customer for permission. After the permission is explicitly granted or denied, SocialAuth’s behavior follows the columns belonging to either *Explicitly Granted* or *Explicitly Denied* in the matrix.
* **Succeeds with Account:** SocialAuth will directly invoke the callback with the account.
* **Presents Picker:** SocialAuth will present an *internal* `UIActionSheet` that can be used to select an appropriate account. Once the action sheet finishes, SocialAuth invokes the callback with either the selected account or `nil` if the customer has hit *Cancel*.
* **Propagates Error** SocialAuth invokes the callback directly with the `NSError` object presented thru `ACAccountStore`.