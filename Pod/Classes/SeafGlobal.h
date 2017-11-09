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

#define SEAFILE_SUITE_NAME @"group.com.seafile.seafilePro"
#define APP_ID @"com.seafile.seafilePro"

#define WS(weakSelf)  __weak __typeof(&*self)weakSelf = self;

/**
 Synthsize a weak or strong reference.
 
 Example:
 @weakify(self)
 [self doSomething^{
 @strongify(self)
 if (!self) return;
 ...
 }];
 */

#ifndef weakify
    #if DEBUG
        #if __has_feature(objc_arc)
            #define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
        #endif
    #else
        #if __has_feature(objc_arc)
            #define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
        #endif
    #endif
#endif

#ifndef strongify
    #if DEBUG
        #if __has_feature(objc_arc)
            #define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
        #else
            #define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
        #endif
    #else
        #if __has_feature(objc_arc)
            #define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
        #else
            #define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
        #endif
    #endif
#endif

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

- (BOOL)isCertInUse:(NSData*)clientIdentityKey;
- (void)loadAccounts;
- (bool)saveAccounts;
- (SeafConnection *)getConnection:(NSString *)url username:(NSString *)username;

- (void)startTimer;

- (void)migrate;

@end

