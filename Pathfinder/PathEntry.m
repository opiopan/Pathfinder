//
//  PathEntry.m
//  Pathfinder
//
//  Created by opiopan on 2012/11/25.
//
//

#import "PathEntry.h"

@implementation PathEntry
{
    NSString* base;
}

@synthesize isDirectory;
@synthesize name;
@synthesize path;

- (id) initWithPhrase:(NSString *)phrase base:(NSString*)baseDir
{
    self = [self init];
    if (self){
        NSRange rType = {0, 1};
        isDirectory = [[phrase substringWithRange:rType] isEqualToString:@"D"];
        path = [[phrase substringFromIndex:2] stringByDeletingLastPathComponent];
        name = [[phrase substringFromIndex:2] lastPathComponent];
        base = baseDir;
    }
    
    return self;
}

- (NSString*) absolutePath
{
    NSMutableString* apath = [NSMutableString stringWithCapacity:256];
    if ([path characterAtIndex:0] == '/'){
        [apath appendFormat:@"%@/%@", path, name];
    }else{
        [apath appendFormat:@"%@/%@/%@", base, path, name];
    }
    
    return apath;
}

// QLPreviewItem非形式プロトコル実装
- (NSURL *)previewItemURL
{
    return [NSURL fileURLWithPath:[self absolutePath]];
}

- (NSString *)previewItemTitle
{
    return name;
}

@end
