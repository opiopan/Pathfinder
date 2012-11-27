//
//  PathEntry.m
//  Pathfinder
//
//  Created by opiopan on 2012/11/25.
//
//

#import "PathEntry.h"

@implementation PathEntry

@synthesize isDirectory;
@synthesize name;
@synthesize path;

- (id) initWithPhrase:(NSString *)phrase
{
    self = [self init];
    if (self){
        NSRange rType = {0, 1};
        isDirectory = [[phrase substringWithRange:rType] isEqualToString:@"D"];
        path = [[phrase substringFromIndex:2] stringByDeletingLastPathComponent];
        name = [[phrase substringFromIndex:2] lastPathComponent];
    }
    
    return self;
}

- (NSString*) absolutePathWithBaseDirectory:(NSString*)base
{
    NSMutableString* apath = [NSMutableString stringWithCapacity:256];
    if ([path characterAtIndex:0] == '/'){
        [apath appendFormat:@"%@/%@", path, name];
    }else{
        [apath appendFormat:@"%@/%@/%@", base, path, name];
    }
    
    return apath;
}

@end
