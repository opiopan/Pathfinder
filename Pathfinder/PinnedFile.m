//
//  PinnedFile.m
//  Pathfinder
//
//  Created by opiopan on 2012/12/01.
//
//

#include <sys/stat.h>
#include <unistd.h>
#import "PinnedFile.h"
#import "CreatingPinnedFileSheet.h"
#import "ChildProcess.h"

@implementation PinnedFile
{
    NSWindow*                modalWindow;
    id                       modalDelegate;
    SEL                      endSelector;
    CreatingPinnedFileSheet* sheet;
    BOOL                     succeedToCreate;
}

@synthesize url;

static const NSString* PINNED_PFLIST=@".Pathfinder.pflist";

//-----------------------------------------------------------------------------------------
// オブジェクト初期化
//-----------------------------------------------------------------------------------------
- (id) initWithDirectory:(NSURL *)dir
{
    self = [self init];
    if (self){
        url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                      [dir path], PINNED_PFLIST]];
        sheet = nil;
    }
    return self;
}

+ (PinnedFile*) pinnedFileWithDirectory:(NSURL *)dir
{
    return [[PinnedFile alloc] initWithDirectory:dir];
}

//-----------------------------------------------------------------------------------------
// ピン留めファイルの存在確認
//-----------------------------------------------------------------------------------------
- (BOOL)exist
{
    struct stat statbuf;
    int rc = stat([[url path] UTF8String], &statbuf);
    return (rc == 0 && (statbuf.st_mode & S_IFMT) == S_IFREG);
}

//-----------------------------------------------------------------------------------------
// ピン留めファイル作成
//-----------------------------------------------------------------------------------------
- (void)createPinnedFileModalForWindow:(NSWindow*)window
                         modalDelegate:(id)delegate didEndSelector:(SEL)selector;
{
    modalWindow = window;
    modalDelegate = delegate;
    endSelector = selector;
    sheet = [[CreatingPinnedFileSheet alloc] init];
    [sheet beginSheetModalForWindow:window modalDelegate:self
                     didEndSelector:@selector(didEndSheetWithContext:) contextInfo:nil];
    
    [self performSelectorInBackground:@selector(createPinnedFileInBackground) withObject:nil];
}

- (void)createPinnedFileInBackground
{
    @autoreleasepool {
        NSString* toolDir = [ChildProcess escapedString:[[[NSBundle mainBundle] executablePath]
                                                         stringByDeletingLastPathComponent]];
        NSString* targetDir = [ChildProcess escapedString:[[url path] stringByDeletingLastPathComponent]];
        NSString* pinnedFile = [ChildProcess escapedString:[url path]];
        ChildProcess* cmd = [ChildProcess childProcessWithFormat:@"%@/filelist %@ > %@",
                             toolDir, targetDir, pinnedFile];
        succeedToCreate = ([cmd execute] == 0);
        
        [self performSelectorOnMainThread:@selector(didEndCreatingPinnedFile)
                               withObject:nil waitUntilDone:NO];
    }
}

- (void)didEndCreatingPinnedFile
{
    [sheet endSheet];
}

- (void)didEndSheetWithContext:(void*)context
{
    sheet = nil;
    if (!succeedToCreate){
        NSBeginCriticalAlertSheet(NSLocalizedString(@"Error", nil), NSLocalizedString(@"OK", nil), nil, nil,
                                  modalWindow, self, nil, nil, nil,
                                  NSLocalizedString(@"An error occured while creating a pinned file.", nil));
    }
    [modalDelegate performSelector:endSelector withObject:nil afterDelay:0.0f];
}

//-----------------------------------------------------------------------------------------
// ピン留めファイル作成
//-----------------------------------------------------------------------------------------
- (void)remove
{
    unlink([[url path] UTF8String]);
}

@end
