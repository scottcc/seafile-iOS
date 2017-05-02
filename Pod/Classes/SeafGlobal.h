//
//  SeafGlobal.h
//  seafilePro
//
//  Created by Wang Wei on 11/9/14.
//  Copyright (c) 2014 Seafile. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "SeafConnection.h"
#import "SeafPreView.h"
#import "SeafUI.h"

#define OBJECTS_DIR @"objects"
#define AVATARS_DIR @"avatars"
#define CERTS_DIR @"certs"
#define BLOCKS_DIR @"blocks"
#define UPLOADS_DIR @"uploads"
#define EDIT_DIR @"edit"
#define THUMB_DIR @"thumb"
#define TEMP_DIR @"temp"

#define THUMB_SIZE 96

@interface SeafGlobal : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (readonly) ALAssetsLibrary *assetsLibrary;

@property (readonly) BOOL allowInvalidCert;

@property (retain) NSMutableArray *conns;
@property (readwrite) SeafConnection *connection;
@property (readonly) NSString *platformVersion;
@property (readonly) dispatch_semaphore_t saveAlbumSem;
@property (readwrite) BOOL isAppExtension;

+ (SeafGlobal *)sharedObject;
/// @note   If not called, `group.com.seafile.seafilePro` is used
+ (void)setGroupName:(NSString *)groupName;
+ (NSString *)appId;
/// @note   If not called, `com.seafile.seafilePro` is used
+ (void)setAppId:(NSString *)appId;

- (void)ensureDocumentDirectories;
- (NSString *)applicationDocumentsDirectory;
- (NSString *)tempDir;
- (NSString *)uploadsDir;
- (NSString *)avatarsDir;
- (NSString *)certsDir;
- (NSString *)editDir;
- (NSString *)thumbsDir;
- (NSString *)objectsDir;
- (NSString *)blocksDir;
- (NSString *)documentStorageDir;
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

- (NSString *)documentPath:(NSString*)fileId;
- (NSString *)blockPath:(NSString*)blkId;

- (void)loadSettings:(NSUserDefaults *)standardUserDefaults;

- (BOOL)isCertInUse:(NSData*)clientIdentityKey;
- (void)loadAccounts;
- (bool)saveAccounts;
- (SeafConnection *)getConnection:(NSString *)url username:(NSString *)username;

- (void)startTimer;

- (void)saveContext;
- (void)deleteAllObjects: (NSString *)entityDescription;

- (void)incDownloadnum;
- (void)decDownloadnum;
- (unsigned long)uploadingnum;
- (unsigned long)downloadingnum;

- (void)finishDownload:(id<SeafDownloadDelegate>)file result:(BOOL)result;
- (void)finishUpload:(SeafUploadFile *)file result:(BOOL)result;

- (void)addUploadTask:(SeafUploadFile *)file;
- (void)addDownloadTask:(id<SeafDownloadDelegate>)file;
- (void)removeBackgroundUpload:(SeafUploadFile *)file;
- (void)removeBackgroundDownload:(id<SeafDownloadDelegate>)file;
- (void)clearAutoSyncPhotos:(SeafConnection *)conn;
- (void)clearAutoSyncVideos:(SeafConnection *)conn;

- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (id)objectForKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;
- (BOOL)synchronize;

- (void)migrate;
- (void)assetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;

- (NSComparisonResult)compare:(id<SeafSortable>)obj1 with:(id<SeafSortable>)obj2;

- (UIImage *)imageFromPath:(NSString *)path withMaxSize:(float)length cachePath:(NSString *)cachePath;

- (NSString *)uniqueDirUnder:(NSString *)dir;
- (NSString *)uniqueUploadDir;
- (void)addExportFile:(NSURL *)url data:(NSDictionary *)dict;
- (void)removeExportFile:(NSURL *)url;
- (NSDictionary *)getExportFile:(NSURL *)url;
- (void)clearExportFiles;

- (void)clearCache;

- (NSDictionary *)getAllSecIdentities;
- (BOOL)importCert:(NSString *)certificatePath password:(NSString *)keyPassword;
- (BOOL)removeIdentity:(SecIdentityRef)identity forPersistentRef:(CFDataRef)persistentRef;
- (void)chooseCertFrom:(NSDictionary *)dict handler:(void (^)(CFDataRef persistentRef, SecIdentityRef identity)) completeHandler from:(UIViewController *)c;
- (NSURLCredential *)getCredentialForKey:(NSData *)key;

@end

