//
//  PathfinderTableView.m
//  Pathfinder
//
//  Created by opiopan on 2012/12/09.
//
//

#import "PathfinderTableView.h"
#import "Document.h"

@implementation PathfinderTableView

@synthesize qlDelegate;

- (void)keyDown:(NSEvent *)theEvent
{
    NSString* key = [theEvent charactersIgnoringModifiers];
    if([key isEqual:@" "]) {
        if ([self selectedRow] != -1){
            [qlDelegate togglePreviewPanel:self];
        }
    } else {
        [super keyDown:theEvent];
    }
}

@end
