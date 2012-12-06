//
//  PinnedFileGenerator.h
//  Pathfinder
//
//  Created by opiopan on 2012/12/01.
//
//

#import <Foundation/Foundation.h>

@interface CreatingPinnedFileSheet : NSObject <NSWindowDelegate>

@property (strong) IBOutlet NSPanel *panel;
@property (weak) IBOutlet NSProgressIndicator *progress;

- (id) init;
- (void) beginSheetModalForWindow:(NSWindow*)window modalDelegate:(id)delegate
                   didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo;
- (void) endSheet;

@end
