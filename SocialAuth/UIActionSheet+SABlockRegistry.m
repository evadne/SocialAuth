#import "UIActionSheet+SABlockRegistry.h"

@implementation UIActionSheet (SABlockRegistry)

- (NSMutableDictionary *) sa_blockRegistry {
	static const void * kBlockRegistry = &kBlockRegistry;
	NSMutableDictionary *answer = objc_getAssociatedObject(self, kBlockRegistry);
	if (!answer) {
		answer = [NSMutableDictionary dictionary];
		objc_setAssociatedObject(self, kBlockRegistry, answer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return answer;
}

- (NSUInteger) sa_addBlock:(void(^)(void))block withTitle:(NSString *)title {
	NSUInteger index = [(UIActionSheet *)self addButtonWithTitle:title];
	[self sa_blockRegistry][@(index)] = [block copy];
	return index;
}

- (void(^)(void)) sa_blockWithIndex:(NSUInteger)index {
	return [self sa_blockRegistry][@(index)];
}

@end
