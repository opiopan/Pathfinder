//
//  SerchFieldWithProgressCell.m
//  Pathfinder
//
//  Created by opiopan on 2012/11/26.
//
//

#import "SerchFieldWithProgressCell.h"

@implementation SerchFieldWithProgressCell
{
    NSProgressIndicator __weak* progress;
    NSButtonCell*               cancelButton;
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView
{
	[super drawInteriorWithFrame:aRect inView:controlView];
    
    if (progress){
        NSRect progressRect = NSMakeRect(aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height);
        progressRect.origin.x += aRect.size.width - 20;
        progressRect.origin.y += 3;
        progressRect.size.width -= (aRect.size.width - 20);
        
        /*
        NSColor* color = [NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        [color setFill];
        NSBezierPath* path = [NSBezierPath bezierPathWithRect:progressRect];
        [path fill];
         */
        
        [progress setFrame:progressRect];
        [progress sizeToFit];
    }
}

- (void)setProgress:(NSProgressIndicator *)newProgress
{
	progress = newProgress;
	[progress sizeToFit];
    if (progress){
        cancelButton = [self cancelButtonCell];
        [self setCancelButtonCell:nil];
    }else{
        [self setCancelButtonCell:cancelButton];
    }
}


@end
