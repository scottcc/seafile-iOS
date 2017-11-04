//
//  SeafDetailViewController.h
//  seafile
//
//  Created by Wei Wang on 7/7/12.
//  Copyright (c) 2012 Seafile Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SeafFile.h"

enum PREVIEW_STATE {
    PREVIEW_NONE = 0,
    PREVIEW_QL_SUBVIEW,
    PREVIEW_QL_MODAL,
    PREVIEW_WEBVIEW,
    PREVIEW_WEBVIEW_JS,
    PREVIEW_DOWNLOADING,
    PREVIEW_PHOTO,
    PREVIEW_FAILED
};

@interface SeafDetailViewController : UIViewController <UISplitViewControllerDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource, SeafShareDelegate, SeafDentryDelegate>

@property (readonly) int state;

@property (nonatomic) id<SeafPreView> preViewItem;
@property (nonatomic) UIViewController<SeafDentryDelegate> *masterVc;
@property (retain) QLPreviewController *qlViewController;
/// Default is 10 MB, set to <= zero to disable (not recommended!)
@property (nonatomic) int maxEditFilesizeMB;

+ (void)setPrefersQuickLookModal:(BOOL)prefersQuickLookModal;

+ (UIViewController * (^)(SeafDetailViewController *, SeafFile *, UIImage *))editImageBlock;
/// If this block is set, it will allow editing images.
+ (void)setEditImageBlock:(UIViewController * (^)(SeafDetailViewController *, SeafFile *, UIImage *))editImageBlock;

- (void)refreshView;
/// Does nothing if not in PREVIEW_PHOTO state, otherwise reloads the image from cache
/// and instructs the photo viewer to reload its data.
/// @note: Also calls `[self refreshView]`.
- (void)refreshCurrentPhotoImage;
- (void)setPreViewItem:(id<SeafPreView>)item master:(UIViewController<SeafDentryDelegate> *)c;

- (void)setPreViewPhotos:(NSArray *)items current:(id<SeafPreView>)item master:(UIViewController<SeafDentryDelegate> *)c;

- (void)goBack:(id)sender;

@end
