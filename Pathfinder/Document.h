//
//  Document.h
//  Pathfinder
//
//  Created by opiopan on 12/05/13.
//  Copyright (c) 2012年 opiopan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SerchFieldWithProgressCell.h"

@interface Document : NSDocument

@property (weak) IBOutlet NSTableView*                searchResult;
@property (weak) IBOutlet SerchFieldWithProgressCell* searchField;
@property (weak) IBOutlet NSSearchField*              searchFieldControl;
@property (weak) IBOutlet NSToolbar*                  toolbar;

- (IBAction)onSearchFieldChange:(id)sender;

@end
