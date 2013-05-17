#import <objc/runtime.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>

@interface SAAccountStore : ACAccountStore

- (void) requestAccountTyped:(ACAccountType *)accountType withOptions:(NSDictionary *)options completion:(void(^)(BOOL didFinish, ACAccount *account, NSError *error))block;

@end
