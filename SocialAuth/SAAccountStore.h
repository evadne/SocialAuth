#import <objc/runtime.h>
#import <Accounts/Accounts.h>

@interface SAAccountStore : ACAccountStore

- (void) requestAccountTyped:(ACAccountType *)accountType withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, ACAccount *account, NSError *error))block;

- (void) retrieveCredentialsForAccount:(ACAccount *)account withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, NSDictionary *credentials, NSError *error))block;

@end

extern NSString * const SATwitterConsumerKey;	//	option key
extern NSString * const SATwitterConsumerSecret;	//	option key

extern NSString * const SAFacebookAccessToken;	//	credentials key
extern NSString * const SATwitterAccessToken;	//	credentials key
extern NSString * const SATwitterAccessTokenSecret;	//	credentials key
