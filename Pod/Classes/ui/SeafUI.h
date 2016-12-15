//
//  SeafUI.h
//  seafilePro
//
//  Created by Scott Corscadden on 2016-12-15.
//  Copyright © 2016 Seafile. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SeafConnection.h"

@class SeafFileViewController;
@class MFMailComposeViewController;

@protocol SeafAppDelegateProxy <UIApplicationDelegate, SeafConnectionDelegate>
- (void)checkOpenLinkAfterAHalfSecond:(SeafFileViewController *)c;
- (void)showDetailView:(UIViewController *) c;
- (SeafFileViewController *)fileVC;
- (MFMailComposeViewController *)globalMailComposer;
- (void)cycleTheGlobalMailComposer;
@end

@interface SeafUI : NSObject

+ (id <SeafAppDelegateProxy>)appdelegate;

@end
