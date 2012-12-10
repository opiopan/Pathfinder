//
//  Document.h
//  Pathfinder
//
//  Created by opiopan on 12/05/13.
//  Copyright (c) 2012年 opiopan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "SerchFieldWithProgressCell.h"
#import "PathfinderTableView.h"

@interface Document : NSDocument <QLPreviewPanelDataSource, QLPreviewPanelDelegate>

@property (weak) IBOutlet PathfinderTableView*        searchResult;
@property (weak) IBOutlet SerchFieldWithProgressCell* searchField;
@property (weak) IBOutlet NSSearchField*              searchFieldControl;
@property (weak) IBOutlet NSToolbar*                  toolbar;
@property (weak) IBOutlet NSButtonCell*               pinButton;
@property (copy)          NSIndexSet*                 selectedIndexes;

- (IBAction)onSearchFieldChange:(id)sender;
- (IBAction)onPin:(id)sender;

- (void)togglePreviewPanel:(id)sender;

@end
