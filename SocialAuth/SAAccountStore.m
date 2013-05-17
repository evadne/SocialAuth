#import "SAAccountStore.h"
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

		[persistentViewController dismissViewControllerAnimated:NO completion:nil];
		[persistentViewController presentViewController:composeViewController animated:NO completion:splunk];
		[persistentViewController.view.window endEditing:NO];
		splunk();
		
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
	
	if (accountType.accessGranted && [self accountsWithAccountType:accountType].count) {
		//	If access is granted, do not do a queue roundtrip.
		//	Proceed directly to the selector.
		processAccounts();
		return;
	}
	
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

@end
