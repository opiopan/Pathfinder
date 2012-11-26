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

@implementation Document
{
    NSProgressIndicator*    progressView;

    NSMutableArray* pathList;
    BOOL            isAbsolutePath;
    BOOL            isUpdatingList;
    
    // 検索スレッド内で参照する変数
    NSString*       target;
    NSString*       keyword;
    NSString*       toolDir;
    NSString*       searchError;
}

@synthesize searchResult;
@synthesize searchField;

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
        isUpdatingList = NO;
        pathList = nil;
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
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
    [searchResult setDoubleAction:@selector(onSearchResultDouble:)];
}

//----------------------------------------------------------------------
// エラーメッセージシート
//----------------------------------------------------------------------
- (void)beginErrorSheetWithTitle:(NSString *)title message:(NSString *)message
{
    NSBeginCriticalAlertSheet(title, @"", @"", @"", nil, self,
                              nil, nil,
                              nil, @"%@", message);
}


//-----------------------------------------------------------------------------------------
// ドキュメントロード
//-----------------------------------------------------------------------------------------
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
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
        
        NSMutableString* path = [NSMutableString stringWithCapacity:256];
        if (isAbsolutePath){
            [path appendFormat:@"%@/%@", pe.path, pe.name];
        }else{
            [path appendFormat:@"%@/%@/%@", [[[self fileURL] path] stringByDeletingLastPathComponent], pe.path, pe.name];
        }
        [items addObject:[NSURL fileURLWithPath:path]];
        
        index = [rowIndexes indexGreaterThanIndex:index];
    }
    
    [pboard writeObjects:items];
    
    return YES;
}

//-----------------------------------------------------------------------------------------
// 検索結果リスト生成
//-----------------------------------------------------------------------------------------
- (void)createPathListWithKey
{
    @autoreleasepool {
        // 検索コマンド文字列生成
        NSMutableString* cmd = [NSMutableString stringWithCapacity:1024];
        char escapedStr[1024];
        [self escapeShellStringWithSource:[target UTF8String]
                              destination:escapedStr length:sizeof(escapedStr)];
        [cmd appendFormat:@"cat %s | %@/searchFile all ", escapedStr, toolDir];
        [self escapeShellStringWithSource:[keyword UTF8String]
                              destination:escapedStr length:sizeof(escapedStr)];
        [cmd appendString:[NSString stringWithUTF8String:escapedStr]];
        
        // 検索コマンド起動
        FILE* in = popen([cmd UTF8String], "r");
        if (!in){
            searchError = @"An error occurred when invoking search task.";
            goto END;
        }
        
        // 検索結果リスト生成
        char line[2048];
        while (fgets(line, sizeof(line), in)){
            size_t length = strlen(line);
            if (line[length - 1] == '\n'){
                line[length - 1] = 0;
            }
            isAbsolutePath = (line[0] == '/');
            PathEntry* pe = [[PathEntry alloc] initWithPhrase:[NSString stringWithUTF8String:line]];
            [pathList addObject:pe];
        }
        
        // 検索コマンドの終了コード判定
        int rc = pclose(in);
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

- (void)escapeShellStringWithSource:(const char*)src destination:(char*)dest length:(int)length
{
    int i = 0;
    for (; *src && i < length - 1; i++, src++){
        if (*src == ' ' || *src == '(' || *src == ')' || *src == '&' ||
            *src == '\\' || *src == '|' || *src == '<' || *src == '>'||
            *src == '*' || *src == '[' || *src == ']'){
            if (i + 1 >= length - 1){
                break;
            }
            dest[i++] = '\\';
        }
        dest[i] = *src;
    }
    dest[i] = 0;
}

//-----------------------------------------------------------------------------------------
// 検索フィールド変更
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
            
            [self performSelectorInBackground:@selector(createPathListWithKey) withObject:nil];
            [searchResult reloadData];
        }
    }else{
        [self beginErrorSheetWithTitle:@"Error" message:@"Another searching task has Already invoked."];
    }
}

//-----------------------------------------------------------------------------------------
// 検索アクセラレータへの応答
//-----------------------------------------------------------------------------------------
- (void)performFindPanelAction:(id)sender
{
}

//-----------------------------------------------------------------------------------------
// 検索結果テーブルでのダブルクリック
//-----------------------------------------------------------------------------------------
- (void)onSearchResultDouble:(id)sender
{
}

@end
