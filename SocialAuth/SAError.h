#import <Foundation/Foundation.h>

extern NSString * const SAErrorDomain;

typedef enum SAErrorCode {
    SAErrorUnknown = 1,
    SAErrorHaltAndCatchFire
			//	Something hacky is wrong.
			//	Forgive us for only taking two extremes.
} SAErrorCode;
