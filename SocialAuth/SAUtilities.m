#import "SAUtilities.h"

NSDictionary * SAQueryParameters (NSString *query) {

	NSArray *parameters = [query componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"=&"]];
	NSMutableDictionary *keyValueParm = [NSMutableDictionary dictionary];
	for (NSUInteger i = 0; i < [parameters count]; i += 2) {
		keyValueParm[parameters[i]] = parameters[i+1];
	}
	return keyValueParm;

}