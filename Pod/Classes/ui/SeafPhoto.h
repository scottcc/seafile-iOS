//
//  SeafPhoto.h
//  seafilePro
//
//  Created by Wang Wei on 10/17/15.
//  Copyright © 2015 Seafile. All rights reserved.
//
@import MWPhotoBrowserPlus;

#import "SeafPreView.h"
@interface SeafPhoto : NSObject<MWPhoto>
@property (retain, readonly) id<SeafPreView> file;


- (id)initWithSeafPreviewIem:(id<SeafPreView>)file;

/// If an image has been updated, calling this will allow MWPhotoBrowser to notice the updated one.
- (void)refreshImage;

- (void)setProgress: (float)progress;
- (void)complete:(BOOL)updated error:(NSError *)error;
@end
