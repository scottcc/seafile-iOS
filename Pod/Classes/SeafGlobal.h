//
//  SeafGlobal.h
//  seafilePro
//
//  Created by Wang Wei on 11/9/14.
//  Copyright (c) 2014 Seafile. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SeafConnection.h"
#import "SeafDbCacheProvider.h"
#import "SeafPreView.h"
#import "SeafUI.h"


#define SEAFILE_SUITE_NAME @"group.com.seafile.seafilePro"
#define APP_ID @"com.seafile.seafilePro"

@protocol SeafBackgroundMonitor <NSObject>
- (void)enterBackground;
- (void)enterForeground;
@end


@interface SeafGlobal : NSObject<SeafBackgroundMonitor>

@property (retain) NSMutableArray *conns;
@property (readwrite) SeafConnection *connection;
@property (readonly) dispatch_semaphore_t saveAlbumSem;
@property (readonly) SeafDbCacheProvider *cacheProvider;


+ (SeafGlobal *)sharedObject;
/// @note   If not called, `group.com.seafile.seafilePro` is used
+ (void)setGroupName:(NSString *)groupName;
+ (NSString *)appId;
/// @note   If not called, `com.seafile.seafilePro` is used
+ (void)setAppId:(NSString *)appId;

/**
 * @note    This will perform its execution on a background (non main) queue.
 * @param   appdelegate The proxy used to call back into [appdelegate checkBackgroundUploadStatus] once at the end.
 */
- (void)performDelayedInit:(id <SeafAppDelegateProxy>)appdelegate;
/**
 * @note    Safe to be called multiple times, is called by performDelayedInit but only registers
 *          if the app is authorized to access photos (otherwise a modal requesting permission pops up,
 *          which you may wish to control when that happens).
 */
- (void)registerPhotoObserver:(id <SeafAppDelegateProxy>)appdelegate;

- (BOOL)isCertInUse:(NSData*)clientIdentityKey;
- (void)loadAccounts;
- (bool)saveAccounts;
- (SeafConnection *)getConnection:(NSString *)url username:(NSString *)username;

- (void)startTimer;

- (void)migrate;

- (void)addExportFile:(NSURL *)url data:(NSDictionary *)dict;
- (void)removeExportFile:(NSURL *)url;
- (NSDictionary *)getExportFile:(NSURL *)url;
- (void)clearExportFiles;

@end

