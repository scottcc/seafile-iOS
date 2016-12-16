//
//  SeafUI.h
//  seafilePro
//
//  Created by Scott Corscadden on 2016-12-15.
//  Copyright © 2016 Seafile. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SeafConnection.h"

@class SeafDetailViewController;
@class SeafStarredFilesViewController;
@class SeafFileViewController;
@class MFMailComposeViewController;

typedef SeafDetailViewController *(^SeafDetailViewControllerResolver)(void);

#define S_UPLOAD NSLocalizedString(@"Upload", @"Seafile")
#define S_REDOWNLOAD NSLocalizedString(@"Redownload", @"Seafile")

@protocol SeafAppDelegateProxy <UIApplicationDelegate, SeafConnectionDelegate>
- (SeafFileViewController *)fileVC;
- (SeafStarredFilesViewController *)starredVC;

- (void)checkOpenLinkAfterAHalfSecond:(SeafFileViewController *)c;
- (void)showDetailView:(UIViewController *) c;
- (MFMailComposeViewController *)globalMailComposer;
- (void)cycleTheGlobalMailComposer;
@end

@interface SeafUI : NSObject

+ (id <SeafAppDelegateProxy>)appdelegate;

@end
