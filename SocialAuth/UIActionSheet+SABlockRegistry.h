#import <objc/runtime.h>
#import <UIKit/UIKit.h>

@interface UIActionSheet (SABlockRegistry)

- (NSUInteger) sa_addBlock:(void(^)(void))block withTitle:(NSString *)title;
- (void(^)(void)) sa_blockWithIndex:(NSUInteger)index;

@end
