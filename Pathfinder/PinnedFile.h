//
//  PinnedFile.h
//  Pathfinder
//
//  Created by opiopan on 2012/12/01.
//
//

#import <Foundation/Foundation.h>

@interface PinnedFile : NSObject

@property (readonly) NSURL* url;

- (id)initWithDirectory:(NSURL*)dir;
+ (PinnedFile*)pinnedFileWithDirectory:(NSURL*)dir;

- (BOOL)exist;
- (void)createPinnedFileModalForWindow:(NSWindow*)modalWindow
                         modalDelegate:(id)delegate didEndSelector:(SEL)selector;
- (void)remove;

@end
