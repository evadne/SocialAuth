#import <OAuthCore/OAuthCore.h>
#import <Social/Social.h>
#import <QuartzCore/QuartzCore.h>
#import "SAAccountStore.h"
#import "SAError.h"
#import "SAUtilities.h"
#import "UIActionSheet+SABlockRegistry.h"

@interface SAComposeViewController : SLComposeViewController
+ (instancetype) composeViewControllerForServiceType:(NSString *)serviceType;
@end

@implementation SAComposeViewController
+ (instancetype) composeViewControllerForServiceType:(NSString *)serviceType {
	return (SAComposeViewController *)[super composeViewControllerForServiceType:serviceType];
}
- (void) loadView {
	self.view = [[UIView alloc] initWithFrame:CGRectZero];
}
@end

@implementation SAAccountStore

+ (UIViewController *) persistentViewController {

	static UIViewController *viewController = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		viewController = [UIViewController new];
		viewController.view.frame = CGRectZero;
		viewController.view.autoresizingMask = UIViewAutoresizingNone;
		[UIApplication.sharedApplication.keyWindow addSubview:viewController.view];
	});
	
	return viewController;

}

- (void) requestAccountTyped:(ACAccountType *)accountType withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, ACAccount *account, NSError *error))block {

	void (^requestAccountCreation)(void) = ^ {
		
		NSString *serviceType = @{
			ACAccountTypeIdentifierTwitter: SLServiceTypeTwitter,
			ACAccountTypeIdentifierFacebook: SLServiceTypeFacebook,
			ACAccountTypeIdentifierSinaWeibo: SLServiceTypeSinaWeibo
		}[accountType.identifier];
		
		UIViewController *persistentViewController = [[self class] persistentViewController];
		SAComposeViewController *composeViewController = [SAComposeViewController composeViewControllerForServiceType:serviceType];
		
		void (^splunk)(void) = ^ {
			for (UIView *view in persistentViewController.view.window.subviews) {
				if ([view isKindOfClass:[UIImageView class]]) {
					if ([view.layer.animationKeys count]) {
						[view.layer removeAllAnimations];
						view.alpha = 0;
					}
				}
			}
			composeViewController.view.alpha = 0;
		};

		[CATransaction begin];
		[persistentViewController dismissViewControllerAnimated:NO completion:nil];
		[persistentViewController presentViewController:composeViewController animated:NO completion:splunk];
		[persistentViewController.view.window endEditing:NO];
		splunk();
		[CATransaction commit];
		
	};
	
	void (^requestAccountSelection)(NSArray *accounts, void(^)(ACAccount *)) = ^ (NSArray *accounts, void(^callback)(ACAccount *selectedAccount)) {
				
		static const void * kActionSheetKeepAlive = &kActionSheetKeepAlive;
		if (objc_getAssociatedObject(self, kActionSheetKeepAlive))
			return;	//	already selecting - callback from the previous interaction session will fire.
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Please choose an account." delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		
		for (ACAccount *account in accounts) {
			[actionSheet sa_addBlock:^{
				callback(account);
				objc_setAssociatedObject(self, kActionSheetKeepAlive, nil, OBJC_ASSOCIATION_ASSIGN);
			} withTitle:account.accountDescription];
		};
		
		[actionSheet sa_addBlock:^{
			callback(nil);
			objc_setAssociatedObject(self, kActionSheetKeepAlive, nil, OBJC_ASSOCIATION_ASSIGN);
		} withTitle:@"Cancel"];
		
		actionSheet.cancelButtonIndex = actionSheet.numberOfButtons - 1;
		[actionSheet showInView:UIApplication.sharedApplication.keyWindow];
		
		objc_setAssociatedObject(self, kActionSheetKeepAlive, actionSheet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		
	};
	
	void (^processAccounts)(void) = ^ {
		NSArray *accounts = [self accountsWithAccountType:accountType];
		if (accounts.count > 1) {
			requestAccountSelection(accounts, ^(ACAccount *account) {
				block(!!account, account, nil);
			});
		} else {
			block(YES, accounts.lastObject, nil);
		}
	};
	
	//	Always request access.
	//	Do not skimp. Facebook hates that.
	
	[self requestAccessToAccountsWithType:accountType options:options completion:^(BOOL granted, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *persistentViewController = [[self class] persistentViewController];
			[persistentViewController dismissViewControllerAnimated:NO completion:nil];
			if (granted) {
				processAccounts();
			} else if (error.code == ACErrorAccountNotFound) {
				requestAccountCreation();
			} else {
				block(NO, nil, error);
			}
		});
	}];

}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	
	((void(^)(void))([actionSheet sa_blockWithIndex:buttonIndex] ?: ^{}))();
	
}

- (void) retrieveCredentialsForAccount:(ACAccount *)account withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, NSDictionary *credentials, NSError *error))block {

	NSCParameterAssert(account);
	NSCParameterAssert(block);

	NSString *typeIdentifier = account.accountType.identifier;
	
	if ([typeIdentifier isEqualToString:ACAccountTypeIdentifierTwitter]) {
		
		//	Use Reverse Auth. https://dev.twitter.com/docs/ios/using-reverse-auth
		//	We’re not doing anything fancy here except fixing a bug
		//	that Twitter sneakily fixed in OAuthCore
		
		NSString *consumerKey = options[SATwitterConsumerKey];
		NSString *consumerSecret = options[SATwitterConsumerSecret];
		NSCParameterAssert(consumerKey && consumerSecret);
		
		NSURLRequest *tokenRequest = ((^{
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.twitter.com/oauth/request_token"]];
			[request setHTTPMethod:@"POST"];
			[request setHTTPBody:[@"x_auth_mode=reverse_auth&" dataUsingEncoding:NSUTF8StringEncoding]];
			[request setValue:OAuthorizationHeader(request.URL, request.HTTPMethod, request.HTTPBody, consumerKey, consumerSecret, nil, nil) forHTTPHeaderField:@"Authorization"];
			[request setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
			[request setHTTPShouldHandleCookies:NO];
			return request;
		})());
		
		[NSURLConnection sendAsynchronousRequest:tokenRequest queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
			
			if (error || !data) {
				block(NO, nil, [NSError errorWithDomain:SAErrorDomain code:SAErrorHaltAndCatchFire userInfo:@{
					NSLocalizedDescriptionKey: @"Reverse Auth Failure",
					NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@ could not trigger Twitter Reverse Auth for account %@ with type %@. %@", NSStringFromClass([self class]), account, account.accountType.accountTypeDescription, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]
				}]);
				return;
			}
			
			SLRequest *reauthRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"] parameters:@{
				@"x_reverse_auth_target": consumerKey,
				@"x_reverse_auth_parameters": [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
			}];
			
			[reauthRequest setAccount:account];
			[reauthRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
				NSDictionary *answer = SAQueryParameters([[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
				NSString *token = answer[@"oauth_token"];
				NSString *secret = answer[@"oauth_token_secret"];
				if (token && secret) {
					block(YES, @{
						SATwitterAccessToken: token,
						SATwitterAccessTokenSecret: secret
					}, nil);
				} else {
					block(NO, nil, [NSError errorWithDomain:SAErrorDomain code:SAErrorHaltAndCatchFire userInfo:@{
						NSLocalizedDescriptionKey: @"Reverse Auth Uncertainty",
						NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@ could not confidently finish Twitter Reverse Auth for account %@ with type %@. %@", NSStringFromClass([self class]), account, account.accountType.accountTypeDescription, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]
					}]);
				}
			}];

		}];
		
		return;
		
	}
	
	if ([typeIdentifier isEqualToString:ACAccountTypeIdentifierFacebook]) {
		
		//	Facebook is using oAuth 2.0 which signs requests on a query parameter over HTTPS.
		//	We can extract this from the public API contract.
		
		//	Note that the official Facebook SDK actually accesses ACAccount.credentials which runs against Apple’s admonitions (https://github.com/facebook/facebook-ios-sdk/blob/4778430b98574e4919d0a24c367f340029c97e6a/src/FBSystemAccountStoreAdapter.m#L96 - there are 13 occurances) might be wise to avoid that.
		
		SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://graph.facebook.com/me"] parameters:nil];
		request.account = account;
				
		[request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
			
			NSDictionary *query = SAQueryParameters(request.preparedURLRequest.URL.query);
			NSString *token = query[@"access_token"];
		
			block(!!token, [NSDictionary dictionaryWithObjectsAndKeys:
				token, SAFacebookAccessToken,
			nil], token ? nil : [NSError errorWithDomain:SAErrorDomain code:SAErrorHaltAndCatchFire userInfo:@{
				NSLocalizedDescriptionKey: @"Can’t Find Access Token",
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@ can not extract access_token from the Graph API /me query any more. :( It is looking at a request %@ for account %@ with type %@.", NSStringFromClass([self class]), request, account, account.accountType.accountTypeDescription]
			}]);
			
		}];
		
		return;
		
	}

	block(NO, nil, [NSError errorWithDomain:SAErrorDomain code:SAErrorHaltAndCatchFire userInfo:@{
		NSLocalizedDescriptionKey: @"Can’t Retrieve Credentials",
		NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"%@ does not understand how to retrieve credentials for accounts of type %@.", NSStringFromClass([self class]), account.accountType.accountTypeDescription]
	}]);
	return;

}

@end

NSString * const SATwitterConsumerKey = @"SATwitterConsumerKey";
NSString * const SATwitterConsumerSecret = @"SATwitterConsumerSecret";

NSString * const SAFacebookAccessToken = @"SAFacebookAccessToken";
NSString * const SATwitterAccessToken = @"SATwitterAccessToken";
NSString * const SATwitterAccessTokenSecret = @"SATwitterAccessTokenSecret";
