//
//  PathEntry.h
//  Pathfinder
//
//  Created by opiopan on 2012/11/25.
//
//

#import <Foundation/Foundation.h>

@interface PathEntry : NSObject

@property (assign, readonly) BOOL      isDirectory;
@property (strong, readonly) NSString* name;
@property (strong, readonly) NSString* path;

- (id) initWithPhrase:(NSString *)phrase base:(NSString*)baseDir;
- (NSString*) absolutePath;

@end
