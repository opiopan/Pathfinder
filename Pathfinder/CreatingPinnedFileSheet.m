//
//  PinnedFileGenerator.m
//  Pathfinder
//
//  Created by opiopan on 2012/12/01.
//
//

#import "CreatingPinnedFileSheet.h"

@implementation CreatingPinnedFileSheet

@synthesize panel;
@synthesize progress;

- (id)init
{
    self = [super init];
    if (self){
        [NSBundle loadNibNamed:@"CreatingPinnedFile" owner:self];
    }
    
    return self;
}

- (void) beginSheetModalForWindow:(NSWindow*)window modalDelegate:(id)delegate
                   didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo
{
    [progress startAnimation:nil];
    [[NSApplication sharedApplication] beginSheet:panel
                                   modalForWindow:window
                                    modalDelegate:delegate
                                   didEndSelector:didEndSelector
                                      contextInfo:contextInfo];
}

- (void) endSheet
{
    [panel close];
	[[NSApplication sharedApplication] endSheet:panel returnCode:NSOKButton];
}

@end
