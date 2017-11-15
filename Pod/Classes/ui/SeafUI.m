//
//  SeafUI.m
//  seafilePro
//
//  Created by Scott Corscadden on 2016-12-15.
//  Copyright © 2016 Seafile. All rights reserved.
//

#import "SeafUI.h"

static id <SeafAppDelegateProxy>proxy = nil;

@implementation SeafUI

+ (void)setAppDelegateProxy:(id <SeafAppDelegateProxy>)p
{
    proxy = p;
}

/**
 * @return A convenience helper casted to the protocol we're interested in.
 */
+ (id <SeafAppDelegateProxy>)appdelegate
{
#if !defined(SF_APP_EXTENSIONS)
    return proxy ?: (id <SeafAppDelegateProxy>)[[UIApplication sharedApplication] delegate];
#endif
    return nil;
}

@end
