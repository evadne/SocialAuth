# SocialAuth

Painless Facebook & Twitter auth on iOS 6+.

## Play

Look at the [Sample App](https://github.com/evadne/SocialAuth-Sample). Check out the [Sample Video](http://vimeo.com/evadne/socialauth-debut). Try to break it.

## Note

SocialAuth uses [OAuthCore](https://github.com/evadne/OAuthCore) whose spec is not in the official Cocoapods repo yet. If you are using SocialAuth today, add evadne’s Specs repo:

	$ pod repo add evadne git@github.com:evadne/Specs.git

## Use

### Authenticating

Use `SAAccountStore`. Request an arbitrary account by calling `-requestAccountTyped:withOptions:completion:`. For more information, check out the sample app — this is the representative portion:

	ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
	[self.accountStore requestAccountTyped:accountType withOptions:nil completion:^(BOOL didFinish, ACAccount *account, NSError *error) {
		if (account) {
			//	use it!
		}
	}];

### Masquerading

If you need to process additional information on your backend service, you’ll want to get oAuth credentials. As long as your application is sharing the same set of client identifiers (“secrets”, huh) with your backend service, you can reuse the credentials.

To retrieve these credentials, SocialAuth invokes [Twitter’s Reverse Auth](https://dev.twitter.com/docs/ios/using-reverse-auth) or parses [Facebook’s oAuth 2.0 Query Parameter](https://tools.ietf.org/html/draft-ietf-oauth-v2-bearer-02#section-2.3). The application should implement credential retrieval right within the completion block of `-requestAccountTyped:withOptions:completion:`.

Before you retrieve the credentials, you can optionally call `-renewCredentialsForAccount:completion:` to renew the credentials if you know it’s a Facebook account. SocialAuth exposes `-retrieveCredentialsForAccount:withOptions:completion:` which will retrieve the underlying oAuth credentials and funnel them back to you.

## Behavior Matrix

Access State | No Accounts | One Account | Many Accounts
------------ | ----------- | ----------- | -------------
Never Granted or Denied | Bails on Settings | Asks for Permission | Asks for Permission
Explicitly Granted | Bails on Settings | Succeeds with Account | Presents Picker
Explicitly Denied | Propagates Error | Propagates Error | Propagates Error

* **Bails on Settings:** SocialAuth will present an UIAlertView asking the customer to go sign in thru Settings.app. SocialAuth *does not* invoke the callback in this case.
* **Asks for Permission:** SocialAuth will trigger a permission dialog and ask the customer for permission. After the permission is explicitly granted or denied, SocialAuth’s behavior follows the columns belonging to either *Explicitly Granted* or *Explicitly Denied* in the matrix.
* **Succeeds with Account:** SocialAuth will directly invoke the callback with the account.
* **Presents Picker:** SocialAuth will present an *internal* `UIActionSheet` that can be used to select an appropriate account. Once the action sheet finishes, SocialAuth invokes the callback with either the selected account or `nil` if the customer has hit *Cancel*.
* **Propagates Error:** SocialAuth invokes the callback directly with the `NSError` object presented thru `ACAccountStore`.

## Marginal Voodoo

* If you’re working with Facebook, make sure you told them about the Bundle ID.
* If you’re working with Twitter and are running into issues, try twiddling Read Only to Read/Write and turning Sign in With Twitter on.

## License

This is free and unencumbered software released into the public domain. A copy of the license is attached in the repository.