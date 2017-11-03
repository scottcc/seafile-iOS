//
//  SeafMasterViewController.h
//  seafile
//
//  Created by Wei Wang on 7/7/12.
//  Copyright (c) 2012 Seafile Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>


enum {
    EDITOP_SPACE = 0,
    EDITOP_MKDIR = 1,
    EDITOP_CREATE,
    EDITOP_COPY,
    EDITOP_MOVE,
    EDITOP_DELETE,
    EDITOP_PASTE,
    EDITOP_MOVETO,
    EDITOP_CANCEL,
    EDITOP_NUM,
};

#define S_MKDIR NSLocalizedString(@"New Folder", @"Seafile")
#define S_NEWFILE NSLocalizedString(@"New File", @"Seafile")
#define S_SORT_NAME NSLocalizedString(@"Sort by Name", @"Seafile")
#define S_SORT_MTIME NSLocalizedString(@"Sort by Last Modifed Time", @"Seafile")

#define S_STAR NSLocalizedString(@"Star", @"Seafile")
#define S_UNSTAR NSLocalizedString(@"Unstar", @"Seafile")

#define S_RENAME NSLocalizedString(@"Rename", @"Seafile")
#define S_EDIT NSLocalizedString(@"Edit", @"Seafile")
#define S_DELETE NSLocalizedString(@"Delete", @"Seafile")
#define S_MORE NSLocalizedString(@"More", @"Seafile")
#define S_DOWNLOAD NSLocalizedString(@"Download", @"Seafile")
#define S_PHOTOS_ALBUM NSLocalizedString(@"Save all photos to album", @"Seafile")
#define S_SAVING_PHOTOS_ALBUM NSLocalizedString(@"Saving all photos to album", @"Seafile")

#define S_PHOTOS_BROWSER NSLocalizedString(@"Open photo browser", @"Seafile")

#define S_SHARE_EMAIL NSLocalizedString(@"Send share link via email", @"Seafile")
#define S_SHARE_LINK NSLocalizedString(@"Copy share link to clipboard", @"Seafile")
#define S_REDOWNLOAD NSLocalizedString(@"Redownload", @"Seafile")
#define S_UPLOAD NSLocalizedString(@"Upload", @"Seafile")
#define S_RESET_PASSWORD NSLocalizedString(@"Reset repo password", @"Seafile")
#define S_CLEAR_REPO_PASSWORD NSLocalizedString(@"Clear password", @"Seafile")


@class SeafDetailViewController;
@class SeafFileViewController;

#import <CoreData/CoreData.h>

#import "SeafDir.h"
#import "SeafFile.h"
#import "SeafUI.h"

typedef SeafDetailViewController *(^SeafDetailViewControllerResolver)(void);

/// These two methods will be available to the `CustomImagePicker` delegate.
@protocol SeafilePHPhotoFileViewController
- (void)phAssetImagePickerControllerDidCancel;
- (void)phAssetImagePickerControllerDidSelectAssets:(NSArray <PHAsset *> *)phAssets;
@end

/// Setting a `CustomImagePicker` as the `customImagePicker` property of SeafFileViewController will
/// enable a swap-in replacement with the newer PHPhotos library used.
@protocol CustomImagePicker
/// This will be called when "Add Photos" is touched. After that, one of the two `SeafilePHPhotoFileViewController` methods will
/// be called. The CustomImagePicker takes care of dismissing itself.
- (void)presentImagePickerSheet;
@end

@interface SeafFileViewController : UITableViewController <SeafDentryDelegate, SeafFileUpdateDelegate> {
}

@property (strong, nonatomic) SeafConnection *connection;

/// @brief Handy for setting before display, or getting to allow reloading content
@property (strong, nonatomic) SeafDir *directory;

@property (strong, readonly) SeafDetailViewController *detailViewController;

/// If this factory is set, it will be called when the "Add Photos" action is initiated and
/// will pass itself to it (as the presenting view controller) and an explicit protocol reference
+ (void)setCustomImagePickerFactoryBlock:(id <CustomImagePicker> (^)(SeafFileViewController *, id <SeafilePHPhotoFileViewController>))customImagePickerFactoryBlock;

+ (void)setSeafDetailViewControllerResolver:(SeafDetailViewControllerResolver)resolver;
/// If set, these will be compared to the macros, ie pass in @[@"S_STAR", @"S_DOWNLOAD"] etc.
+ (void)setSheetSkippedItems:(NSArray <NSString *> *)skippedItems;
+ (NSArray <NSString *> *)sheetSkippedItems;

- (void)refreshView;
- (void)uploadFile:(SeafUploadFile *)file;
- (void)deleteFile:(SeafFile *)file;
- (void)uploadFile:(SeafUploadFile *)ufile toDir:(SeafDir *)dir overwrite:(BOOL)overwrite;

- (void)photoSelectedChanged:(id<SeafPreView>)preViewItem to:(id<SeafPreView>)to;

- (BOOL)goTo:(NSString *)repo path:(NSString *)path;

@end
