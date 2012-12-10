//
//  Document.m
//  Pathfinder
//
//  Created by opiopan on 12/05/13.
//  Copyright (c) 2012年 opiopan. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

#import "Document.h"
#import "PathEntry.h"
#import "PinnedFile.h"
#import "ChildProcess.h"

@implementation Document
{
    NSProgressIndicator*    progressView;

    BOOL            isFolder;
    BOOL            isPinned;
    PinnedFile*     pinnedFile;
    NSString*       baseDir;
    NSMutableArray* pathList;
    BOOL            isUpdatingList;
    
    NSIndexSet*     selectedIndexes;
    
    // 検索スレッド内で参照する変数
    NSString*       target;
    NSString*       keyword;
    NSString*       toolDir;
    NSString*       searchError;
    
    QLPreviewPanel* previewPanel;
}

@synthesize searchResult;
@synthesize searchField;
@synthesize searchFieldControl;
@synthesize toolbar;
@synthesize pinButton;
@synthesize selectedIndexes;

//-----------------------------------------------------------------------------------------
// NSDocument クラスメソッド：ドキュメントの振る舞い
//-----------------------------------------------------------------------------------------
+ (BOOL)autosavesDrafts
{
    return NO;
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

+ (BOOL)preservesVersions
{
    return NO;
}

+ (BOOL)usesUbiquitousStorage
{
    return NO;
}

//-----------------------------------------------------------------------------------------
// オブジェクト初期化
//-----------------------------------------------------------------------------------------
- (id)init
{
    self = [super init];
    if (self) {
        pinnedFile = nil;
        isUpdatingList = NO;
        pathList = nil;
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    // Dragging sourceの登録
    NSArray* dragSourceCapability = [NSArray arrayWithObject:NSFilenamesPboardType];
    [searchResult registerForDraggedTypes:dragSourceCapability];
    [searchResult setDraggingSourceOperationMask:NSDragOperationAll forLocal:NO];
    
    // 検索結果テーブルのアクション登録
    [searchResult setTarget:self];
    [searchResult setDoubleAction:@selector(performOpenItemsAction:)];
    
    // Pinボタンの状態設定
    [pinButton setState:isPinned ? NSOnState : NSOffState];
    
    // Quick Lock用delegate登録
    searchResult.qlDelegate = self;
}

//----------------------------------------------------------------------
// エラーメッセージシート
//----------------------------------------------------------------------
- (void)beginErrorSheetWithTitle:(NSString *)title message:(NSString *)message
{
    NSBeginCriticalAlertSheet(title, @"", @"", @"", [self windowForSheet], self,
                              nil, nil,
                              nil, @"%@", message);
}

//-----------------------------------------------------------------------------------------
// ドキュメントロード
//-----------------------------------------------------------------------------------------
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:@"public.folder"]){
        isFolder = YES;
        pinnedFile = [PinnedFile pinnedFileWithDirectory:absoluteURL];
        isPinned = [pinnedFile exist];
    }else{
        isFolder = NO;
        isPinned = YES;
    }
    baseDir = [[absoluteURL path] stringByDeletingLastPathComponent];
    
    return YES;    
}

//-----------------------------------------------------------------------------------------
// 検索結果リストのデータソース実装
//-----------------------------------------------------------------------------------------
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (isUpdatingList || !pathList){
        return 0;
    }else{
        return [pathList count];
    }
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
    if (isUpdatingList || !pathList || [pathList count] <= rowIndex){
        return nil;
    }
    
    PathEntry* pe = [pathList objectAtIndex:rowIndex];
    
    if ([[aTableColumn identifier] isEqualToString:@"icon"]){
        if (pe.isDirectory){
            return [[NSWorkspace sharedWorkspace] iconForFile:@"/var"];
        }else{
            return [[NSWorkspace sharedWorkspace] iconForFileType:[pe.name pathExtension]];
        }
    }else if ([[aTableColumn identifier] isEqualToString:@"name"]){
        return pe.name;
    }else if ([[aTableColumn identifier] isEqualToString:@"directory"]){
        return pe.path;
    }
    
    return nil;
}

//-----------------------------------------------------------------------------------------
// 検索リストのDragging source実装
//-----------------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView*)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSMutableArray* items = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
    
    NSUInteger index = [rowIndexes firstIndex];
    
    while (index != NSNotFound){
        PathEntry* pe = [pathList objectAtIndex:index];
        
        NSString* path = [pe absolutePath];
        [items addObject:[NSURL fileURLWithPath:path]];
        
        index = [rowIndexes indexGreaterThanIndex:index];
    }
    
    [pboard writeObjects:items];
    
    return YES;
}

//-----------------------------------------------------------------------------------------
// 検索結果リストのbindings (選択リスト)
//-----------------------------------------------------------------------------------------
- (NSIndexSet*)selectedIndexes
{
    return selectedIndexes;
}

- (void) setSelectedIndexes:(NSIndexSet*)indexes
{
    if (indexes != selectedIndexes){
        selectedIndexes = indexes;
        [previewPanel reloadData];
    }
}

//-----------------------------------------------------------------------------------------
// 検索結果リスト生成
//-----------------------------------------------------------------------------------------
- (void)createPathList
{
    @autoreleasepool {
        // 検索コマンド文字列生成
        ChildProcess* cmd = [[ChildProcess alloc] init];
        NSString* escapedTarget = [ChildProcess escapedString:target];
        if (isPinned){
            // ピン留めファイルから検索
            if (isFolder){
                [cmd appendCommandWithFormat:@"cat %@/%@ | %@/searchFile all ",
                 escapedTarget, [[pinnedFile.url path] lastPathComponent], toolDir];
            }else{
                [cmd appendCommandWithFormat:@"cat %a | %@/searchFile all ", escapedTarget, toolDir];
            }
        }else{
            // フォルダを探索
            [cmd appendCommandWithFormat:@"%@/filelist %@ | %@/searchFile all ", toolDir, escapedTarget, toolDir];
        }
        [cmd appendCommandWithString:[ChildProcess escapedString:keyword]];
        
        // 検索コマンド起動
        if (![cmd executeForInput]){
            searchError = @"An error occurred when invoking search task.";
            goto END;
        }
        
        // 検索結果リスト生成
        for (NSString* line = [cmd nextLine]; line; line = [cmd nextLine]){
            PathEntry* pe = [[PathEntry alloc] initWithPhrase:line base:baseDir];
            [pathList addObject:pe];
        }
        
        // 検索コマンドの終了コード判定
        int rc = [cmd result];
        if (rc < 0 || !WIFEXITED(rc) || WEXITSTATUS(rc) != 0){
            searchError = @"An error occurred while searching files.";
            goto END;
        }

        // 完了通知
    END:
        [self performSelectorOnMainThread:@selector(finishCreaingPathList) withObject:nil waitUntilDone:NO];
    }
}

- (void)finishCreaingPathList
{
    if (searchError){
        [self beginErrorSheetWithTitle:@"Error" message:searchError];
        pathList = nil;
    }
    isUpdatingList = NO;
    
    [searchField setProgress:nil];
    [progressView removeFromSuperview];
    progressView = nil;
    
    [searchResult reloadData];
    [searchResult scrollToBeginningOfDocument:self];
}

//-----------------------------------------------------------------------------------------
// 検索フィールド変更（検索開始）
//-----------------------------------------------------------------------------------------
- (IBAction)onSearchFieldChange:(id)sender
{
    if (!isUpdatingList){
        if ([[sender stringValue] length]){
            isUpdatingList = YES;
            target = [[self fileURL] path];
            keyword = [sender stringValue];
            toolDir = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
            pathList = [NSMutableArray arrayWithCapacity:256];
            searchError = nil;
            
            progressView = [[NSProgressIndicator alloc] init];
            [progressView setStyle:NSProgressIndicatorSpinningStyle];
            [progressView setControlSize:NSSmallControlSize];
            [progressView startAnimation:nil];
            [progressView setHidden:NO];
            [searchField setProgress:progressView];
            [[searchField controlView] addSubview:progressView];
            
            [self performSelectorInBackground:@selector(createPathList) withObject:nil];
            [searchResult reloadData];
            [[self windowForSheet] makeFirstResponder:searchResult];
        }
    }else{
        [self beginErrorSheetWithTitle:@"Error" message:@"Another searching task has already invoked."];
    }
}

//-----------------------------------------------------------------------------------------
// 検索フィールドにフォーカス移動
//-----------------------------------------------------------------------------------------
- (void)performFindPanelAction:(id)sender
{
    // 検索フィールドの表示状況を調査
    BOOL isToolbarVisible = [toolbar isVisible];
    BOOL isSearchFieldOnToolbar = NO;
    BOOL isFlexSpaceOnToolbar = NO;
    NSArray* items = [toolbar items];
    for (int i = 0; i < [items count]; i++){
        NSString* identifier = [[items objectAtIndex:i] itemIdentifier];
        if ([identifier isEqualToString:@"SearchField"]){
            isSearchFieldOnToolbar = YES;
        }else if ([identifier isEqualToString:@"NSToolbarFlexibleSpaceItem"]){
            isFlexSpaceOnToolbar = YES;
        }
    }
    
    // ツールバー上に検索フィールドが存在しない場合は追加
    if (!isSearchFieldOnToolbar){
        if (!isFlexSpaceOnToolbar){
            [toolbar insertItemWithItemIdentifier:@"NSToolbarFlexibleSpaceItem"
                                          atIndex:[[toolbar items] count]];
        }
        [toolbar insertItemWithItemIdentifier:@"SearchField"
                                      atIndex:[[toolbar items] count]];
    }
    
    // ツールバー未表示の場合は表示
    if (!isToolbarVisible){
        [toolbar setVisible:YES];
    }
    
    // ツールバーの表示モードが「ラベルのみ」の場合はアイコンを表示
    if ([toolbar displayMode] == NSToolbarDisplayModeLabelOnly){
        [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    }
    
    // 検索フィールドをfirst responderに変更
    [[self windowForSheet] makeFirstResponder:searchFieldControl];
}

//-----------------------------------------------------------------------------------------
// 検索結果アイテムのオープン
//-----------------------------------------------------------------------------------------
- (void)performOpenItemsAction:(id)sender
{
    NSUInteger i = [selectedIndexes firstIndex];
    while (i != NSNotFound){
        PathEntry* pe = [pathList objectAtIndex:i];
        NSString* path = [pe absolutePath];
        [self openItem:path];

        i = [selectedIndexes indexGreaterThanIndex:i];
    }
}

//-----------------------------------------------------------------------------------------
// 検査結果が格納されるフォルダーのオープン
//-----------------------------------------------------------------------------------------
- (void)performOpenFolderAction:(id)sender
{
    NSUInteger i = [selectedIndexes firstIndex];
    while (i != NSNotFound){
        PathEntry* pe = [pathList objectAtIndex:i];
        NSString* path = [pe absolutePath];
        [self openItem:[path stringByDeletingLastPathComponent]];
        
        i = [selectedIndexes indexGreaterThanIndex:i];
    }
}

//-----------------------------------------------------------------------------------------
// アイテムのオープン（デフォルトアクションの実行)
//-----------------------------------------------------------------------------------------
- (void)openItem:(NSString*)path
{
    ChildProcess* cmd = [ChildProcess childProcessWithFormat:@"open %@", [ChildProcess escapedString:path]];
    [cmd execute];
}

//-----------------------------------------------------------------------------------------
// Pinボタン押下
//-----------------------------------------------------------------------------------------
- (IBAction)onPin:(id)sender
{
    if (isFolder){
        if (isPinned){
            // ピン留めファイルの削除確認
            NSBeginAlertSheet(@"Confirmation", @"No", @"Yes", nil,
                              [self windowForSheet], self,
                              nil, @selector(confirmDeletePinnedFileSheetEnd:returnCode:contextInfo:),
                              nil, @"Do you want to delete pinned file?");
        }else{
            if ([pinnedFile exist]){
                isPinned = YES;
            }else{
                // ピン留めファイル作成開始
                [pinnedFile createPinnedFileModalForWindow:[self windowForSheet]
                                             modalDelegate:self didEndSelector:@selector(onEndCreatingPinnedFile)];
            }
        }
    }
    
    [sender setState:isPinned ? NSOnState : NSOffState];
}

- (BOOL)confirmDeletePinnedFileSheetEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
    if (returnCode == NSAlertAlternateReturn){
        // ピン留めファイル削除
        [pinnedFile remove];
    }
    isPinned = NO;
    [pinButton setState:NSOffState];

    return YES;
}

- (void) onEndCreatingPinnedFile
{
    isPinned = [pinnedFile exist];
    [pinButton setState:isPinned ? NSOnState : NSOffState];
}

//-----------------------------------------------------------------------------------------
// Quick Look パネルの ON/OFF
//-----------------------------------------------------------------------------------------
- (void)togglePreviewPanel:(id)sender
{
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    } else {
        [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];
    if (action == @selector(togglePreviewPanel:)) {
        if ([selectedIndexes count] > 0){
            if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
                [menuItem setTitle:@"Close Quick Look panel"];
            } else {
                [menuItem setTitle:@"Open Quick Look panel"];
            }
            return YES;
        }else{
            return NO;
        }
    } else if (action == @selector(performOpenItemsAction:) || action == @selector(performOpenFolderAction:)){
        return [selectedIndexes count] > 0;
    }
    return YES;
}

//-----------------------------------------------------------------------------------------
// Quick Look サポート
//-----------------------------------------------------------------------------------------
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    previewPanel = panel;
    panel.delegate = self;
    panel.dataSource = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    previewPanel = nil;
}

//-----------------------------------------------------------------------------------------
// Quick Look データソース
//-----------------------------------------------------------------------------------------
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return [selectedIndexes count];
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    if (isUpdatingList || !pathList){
        return nil;
    }
    
    NSUInteger i = [selectedIndexes firstIndex];
    for (NSInteger j = 0; j < index && i != NSNotFound; j++){
        i = [selectedIndexes indexGreaterThanIndex:i];
    }
    
    return i == NSNotFound ? nil : [pathList objectAtIndex:i];
}

//-----------------------------------------------------------------------------------------
// Quick Look data delegate
//-----------------------------------------------------------------------------------------

// Quick Look パネルのイベントdelegate
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
{
    // redirect all key down events to the table view
    if ([event type] == NSKeyDown) {
        [searchResult keyDown:event];
        return YES;
    }
    return NO;
}

// Quick Look パネル拡大の始点、縮小の終点の矩形返却
static NSRect centerFitRect(NSImage *image, NSRect targetRect)
{
    NSSize imageSize = [image size];
    CGFloat aspectRatio = imageSize.width / imageSize.height;
    CGFloat newWidth = targetRect.size.height * aspectRatio;
    NSSize fitSize = NSMakeSize(newWidth, targetRect.size.height);
    CGFloat left = (targetRect.size.width - fitSize.width) * 0.5;
    return NSMakeRect(left, targetRect.origin.y, fitSize.width, fitSize.height);
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
    NSInteger col = [searchResult columnWithIdentifier:@"icon"];
    NSInteger row = [searchResult selectedRow];
    NSRect rect = [searchResult frameOfCellAtColumn:col row:row];
    NSCell *cell = [searchResult preparedCellAtColumn:col row:row];
    NSRect selectionFrame = [cell imageRectForBounds:rect];
    selectionFrame = centerFitRect([cell image], selectionFrame);
    
    if(!NSIntersectsRect([searchResult visibleRect], selectionFrame)) {
        return NSZeroRect;
    }
    
    NSView* currentview = searchResult;
    NSView* superview = [currentview superview];
    while (superview){
        selectionFrame = [currentview convertRect:selectionFrame toView:superview];
        currentview = superview;
        superview = [currentview superview];
    }
    selectionFrame.origin = [[searchResult window] convertBaseToScreen:selectionFrame.origin];
    
    return selectionFrame;
}

// Quick Look パネル拡大・縮小時のイメージ返却
- (id)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect
{
    PathEntry* pe = (PathEntry*)item;
    if (pe.isDirectory){
        return [[NSWorkspace sharedWorkspace] iconForFile:@"/var"];
    }else{
        return [[NSWorkspace sharedWorkspace] iconForFileType:[pe.name pathExtension]];
    }
}

@end
