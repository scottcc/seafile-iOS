//
//  SeafMasterViewController.m
//  seafile
//
//  Created by Wei Wang on 7/7/12.
//  Copyright (c) 2012 Seafile Ltd. All rights reserved.
//
#import <MessageUI/MFMailComposeViewController.h>

@import MWPhotoBrowserPlus;
@import SVPullToRefreshPlus;

#import "SeafGlobal.h"
#import "SeafFileViewController.h"
#import "SeafDetailViewController.h"
#import "SeafDirViewController.h"
#import "SeafFile.h"
#import "SeafRepos.h"
#import "SeafCell.h"
#import "SeafActionSheet.h"
#import "SeafPhoto.h"
#import "SeafPhotoThumb.h"
#import "SeafStorage.h"
#import "SeafDataTaskManager.h"
#import "SeafUI.h"

#import "FileSizeFormatter.h"
#import "SeafDateFormatter.h"
#import "ExtentedString.h"
#import "UIViewController+Extend.h"
#import "SVProgressHUD.h"
#import "Debug.h"

#import "QBImagePickerController.h"

enum {
    STATE_INIT = 0,
    STATE_LOADING,
    STATE_DELETE,
    STATE_MKDIR,
    STATE_CREATE,
    STATE_RENAME,
    STATE_PASSWORD,
    STATE_MOVE,
    STATE_COPY,
    STATE_SHARE_EMAIL,
    STATE_SHARE_LINK,
};

#define STR_12 NSLocalizedString(@"A file with the same name already exists, do you want to overwrite?", @"Seafile")
#define STR_13 NSLocalizedString(@"Files with the same name already exist, do you want to overwrite?", @"Seafile")

@interface SeafFileViewController ()<QBImagePickerControllerDelegate, UIPopoverControllerDelegate, SeafUploadDelegate, SeafDirDelegate, SeafShareDelegate, UISearchBarDelegate, UISearchDisplayDelegate, MFMailComposeViewControllerDelegate, SWTableViewCellDelegate, MWPhotoBrowserDelegate, SeafilePHPhotoFileViewController>
- (UITableViewCell *)getSeafFileCell:(SeafFile *)sfile forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)getSeafDirCell:(SeafDir *)sdir forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)getSeafRepoCell:(SeafRepo *)srepo forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath;

@property (strong) id<SeafItem> curEntry;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *loadingView;

@property (strong) UIBarButtonItem *selectAllItem;
@property (strong) UIBarButtonItem *selectNoneItem;
@property (strong) UIBarButtonItem *photoItem;
@property (strong) UIBarButtonItem *doneItem;
@property (strong) UIBarButtonItem *editItem;
@property (strong) NSArray *rightItems;

@property (retain) SWTableViewCell *selectedCell;
@property (retain) NSIndexPath *selectedindex;
@property (readonly) NSArray *editToolItems;

@property int state;

@property(nonatomic,strong) UIPopoverController *popoverController;
@property (retain) NSDateFormatter *formatter;

@property(nonatomic, strong, readwrite) UISearchBar *searchBar;
@property(nonatomic, strong) UISearchDisplayController *strongSearchDisplayController;

@property (strong) NSMutableArray *searchResults;

@property (strong, retain) NSArray *photos;
@property (strong, retain) NSArray *thumbs;
@property BOOL inPhotoBrowser;

@property SeafUploadFile *ufile;
@property (nonatomic, copy, readwrite) void (^pullToRefreshBlock)(void);

/// This is only created/held while it's used, then it's nilified.
@property (strong, nonatomic) id <CustomImagePicker> customImagePicker;

@end

@implementation SeafFileViewController

@synthesize connection = _connection;
@synthesize directory = _directory;
@synthesize curEntry = _curEntry;
@synthesize selectAllItem = _selectAllItem, selectNoneItem = _selectNoneItem;
@synthesize selectedindex = _selectedindex;
@synthesize selectedCell = _selectedCell;

@synthesize editToolItems = _editToolItems;

@synthesize popoverController;

static SeafDetailViewControllerResolver detailViewControllerResolver = ^SeafDetailViewController *{ return nil; };
static NSMutableArray <NSString *> *sheetSkippedItems;
static id <CustomImagePicker> (^customImagePickerFactoryBlock)(UIViewController *, id <SeafilePHPhotoFileViewController>) = nil;
static BOOL pullToRefreshAutomaticallyAfterUpload = NO;

+ (void)initialize
{
    if (self == [SeafFileViewController class]) {
        sheetSkippedItems = [NSMutableArray new];
    }
}

+ (void)setShouldPullToRefreshAutomaticallyAfterUpload:(BOOL)refreshAutomatically
{
    pullToRefreshAutomaticallyAfterUpload = refreshAutomatically;
}

+ (NSArray <NSString *> *)sheetSkippedItems
{
    return [sheetSkippedItems copy];
}
+ (void)setSheetSkippedItems:(NSArray <NSString *> *)skippedItems
{
    [sheetSkippedItems removeAllObjects];
    if (skippedItems) {
        [sheetSkippedItems addObjectsFromArray:skippedItems];
    }
}

+ (void)setSeafDetailViewControllerResolver:(SeafDetailViewControllerResolver)resolver
{
    NSAssert(resolver != NULL, @"You must provide a way to create the SeafDetailViewController");
    detailViewControllerResolver = resolver;
}

+ (void)setCustomImagePickerFactoryBlock:(id <CustomImagePicker> (^)(UIViewController *, id <SeafilePHPhotoFileViewController>))block
{
    customImagePickerFactoryBlock = [block copy];
}

- (SeafDetailViewController *)detailViewController
{
    return detailViewControllerResolver();
}

// Note this only shows up if the directory/thing-on-this-controller is editable to begin with
- (NSArray *)editToolItems
{
    if (!_editToolItems) {
        int i;
        UIBarButtonItem *flexibleFpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        UIBarButtonItem *fixedSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];

        NSArray *itemsTitles = [NSArray arrayWithObjects:S_MKDIR, S_NEWFILE, NSLocalizedString(@"Copy", @"Seafile"), NSLocalizedString(@"Move", @"Seafile"), S_DELETE, NSLocalizedString(@"PasteTo", @"Seafile"), NSLocalizedString(@"MoveTo", @"Seafile"), STR_CANCEL, nil ];

        UIBarButtonItem *items[EDITOP_NUM];
        items[0] = flexibleFpaceItem;

        fixedSpaceItem.width = 38.0f;;
        for (i = 1; i < itemsTitles.count + 1; ++i) {
            items[i] = [[UIBarButtonItem alloc] initWithTitle:[itemsTitles objectAtIndex:i-1] style:UIBarButtonItemStylePlain target:self action:@selector(editOperation:)];
            items[i].tag = i;
        }

        _editToolItems = [NSArray arrayWithObjects:items[EDITOP_COPY], items[EDITOP_MOVE], items[EDITOP_SPACE], items[EDITOP_DELETE], nil ];
    }
    return _editToolItems;
}

- (void)setConnection:(SeafConnection *)conn
{
    [self.detailViewController setPreViewItem:nil master:nil];
    [conn loadRepos:self];
    [self setDirectory:(SeafDir *)conn.rootFolder];
}

- (void)showLoadingView
{
    if (!self.loadingView) {
        self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.loadingView.color = [UIColor darkTextColor];
        self.loadingView.hidesWhenStopped = YES;
        [self.view addSubview:self.loadingView];
    }
    self.loadingView.center = self.view.center;
    [self.loadingView startAnimating];
}

- (void)dismissLoadingView
{
    [self.loadingView stopAnimating];
}

- (void)awakeFromNib
{
    if (IsIpad()) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView registerNib:[UINib nibWithNibName:@"SeafCell" bundle:SeafileBundle()]
         forCellReuseIdentifier:@"SeafCell"];
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeAll;

    self.formatter = [[NSDateFormatter alloc] init];
    [self.formatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 55.0;
    self.state = STATE_INIT;

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    // SCC_CONFIRM - might need the adjustment to offsets still...
    // self.searchBar.searchTextPositionAdjustment = UIOffsetMake(0, 0);
    Debug("repoId:%@, %@, path:%@, loading ... cached:%d %@\n", _directory.repoId, _directory.name, _directory.path, _directory.hasCache, _directory.ooid);
    self.searchBar.delegate = self;
    self.searchBar.barTintColor = [UIColor colorWithRed:240/255.0 green:239/255.0 blue:246/255.0 alpha:1.0];
    [self.searchBar sizeToFit];
    UIImageView *barImageView = [[[self.searchBar.subviews firstObject] subviews] firstObject];
    barImageView.layer.borderColor = [UIColor colorWithRed:240/255.0 green:239/255.0 blue:246/255.0 alpha:1.0].CGColor;
    barImageView.layer.borderWidth = 1;

    self.strongSearchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];
    self.searchDisplayController.searchResultsDataSource = self;
    self.searchDisplayController.searchResultsDelegate = self;
    self.searchDisplayController.delegate = self;
    self.searchDisplayController.searchResultsTableView.rowHeight = UITableViewAutomaticDimension;
    self.searchDisplayController.searchResultsTableView.estimatedRowHeight = 50.0;
    self.searchDisplayController.searchResultsTableView.sectionHeaderHeight = 0;

    UIView *bView = [[UIView alloc] initWithFrame:self.tableView.frame];
    bView.backgroundColor = [UIColor whiteColor];
    self.tableView.backgroundView = bView;

    self.tableView.tableHeaderView = self.searchBar;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.allowsMultipleSelection = NO;

    self.navigationController.navigationBar.tintColor = BAR_COLOR;
    [self.navigationController setToolbarHidden:YES animated:NO];

    Debug(@"%@", self.view);
    [self refreshView];
}

- (void)noneSelected:(BOOL)none
{
    if (none) {
        self.navigationItem.leftBarButtonItem = _selectAllItem;
        NSArray *items = self.toolbarItems;
        [[items objectAtIndex:0] setEnabled:NO];
        [[items objectAtIndex:1] setEnabled:NO];
        [[items objectAtIndex:3] setEnabled:NO];
    } else {
        self.navigationItem.leftBarButtonItem = _selectNoneItem;
        NSArray *items = self.toolbarItems;
        [[items objectAtIndex:0] setEnabled:YES];
        [[items objectAtIndex:1] setEnabled:YES];
        [[items objectAtIndex:3] setEnabled:YES];
    }
}

- (void)checkPreviewFileExist
{
    if ([self.detailViewController.preViewItem isKindOfClass:[SeafFile class]]) {
        SeafFile *sfile = (SeafFile *)self.detailViewController.preViewItem;
        NSString *parent = [sfile.path stringByDeletingLastPathComponent];
        BOOL deleted = YES;
        if (![_directory isKindOfClass:[SeafRepos class]] && _directory.repoId == sfile.repoId && [parent isEqualToString:_directory.path]) {
            for (SeafBase *entry in _directory.allItems) {
                if (entry == sfile) {
                    deleted = NO;
                    break;
                }
            }
            if (deleted)
                [self.detailViewController setPreViewItem:nil master:nil];
        }
    }
}

- (void)initSeafPhotos
{
    NSMutableArray *seafPhotos = [NSMutableArray array];
    NSMutableArray *seafThumbs = [NSMutableArray array];

    for (id entry in _directory.allItems) {
        if ([entry conformsToProtocol:@protocol(SeafPreView)]
            && [(id<SeafPreView>)entry isImageFile]) {
            id<SeafPreView> file = entry;
            [file setDelegate:self];
            [seafPhotos addObject:[[SeafPhoto alloc] initWithSeafPreviewIem:entry]];
            [seafThumbs addObject:[[SeafPhotoThumb alloc] initWithSeafFile:entry]];
        }
    }
    self.photos = [NSArray arrayWithArray:seafPhotos];
    self.thumbs = [NSArray arrayWithArray:seafThumbs];
}

- (void)refreshView
{
    if (!_directory)
        return;
    if ([_directory isKindOfClass:[SeafRepos class]]) {
        self.searchBar.placeholder = NSLocalizedString(@"Search", @"Seafile");
    } else {
        self.searchBar.placeholder = NSLocalizedString(@"Search files in this library", @"Seafile");
    }

    [self initSeafPhotos];
    for (SeafUploadFile *file in _directory.uploadFiles) {
        file.delegate = self;
    }
    [self.tableView reloadData];
    if (IsIpad() && self.detailViewController.preViewItem) {
        [self checkPreviewFileExist];
    }
    if (self.editing) {
        if (![self.tableView indexPathsForSelectedRows])
            [self noneSelected:YES];
        else
            [self noneSelected:NO];
    }
    if (_directory && !_directory.hasCache) {
        Debug("no cache, load %@ from server.", _directory.path);
        [self showLoadingView];
        self.state = STATE_LOADING;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self setLoadingView:nil];
    _directory = nil;
    _curEntry = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if (!self.isVisible)
        [_directory unload];
}
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)selectAll:(id)sender
{
    int row;
    long count = _directory.allItems.count;
    for (row = 0; row < count; ++row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        NSObject *entry  = [self getDentrybyIndexPath:indexPath tableView:self.tableView];
        if (![entry isKindOfClass:[SeafUploadFile class]])
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    }
    [self noneSelected:NO];
}

- (void)selectNone:(id)sender
{
    long count = _directory.allItems.count;
    for (int row = 0; row < count; ++row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    [self noneSelected:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    if (editing) {
        if (![self checkNetworkStatus]) return;
        [self.navigationController.toolbar sizeToFit];
        [self setToolbarItems:self.editToolItems];
        [self noneSelected:YES];
        [self.photoItem setEnabled:NO];
        [self.navigationController setToolbarHidden:NO animated:YES];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        [self.navigationController setToolbarHidden:YES animated:YES];
        //if(!IsIpad())  self.tabBarController.tabBar.hidden = NO;
        [self.photoItem setEnabled:YES];
    }

    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

- (void)addPhotos:(id)sender
{
    if(self.popoverController)
        return;
    if([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusRestricted ||
       [ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusDenied) {
        return [self alertWithTitle:NSLocalizedString(@"This app does not have access to your photos and videos.", @"Seafile") message:NSLocalizedString(@"You can enable access in Privacy Settings", @"Seafile")];
    }

    if (customImagePickerFactoryBlock != nil) {
        self.customImagePicker = customImagePickerFactoryBlock(self, self);
        [self.customImagePicker presentImagePickerSheet:(self.photoItem ?: sender)];
        return;
    }
    
    QBImagePickerController *imagePickerController = [[QBImagePickerController alloc] init];
    imagePickerController.title = NSLocalizedString(@"Photos", @"Seafile");
    imagePickerController.delegate = self;
    imagePickerController.allowsMultipleSelection = YES;
    imagePickerController.filterType = QBImagePickerControllerFilterTypeNone;

    if (IsIpad()) {
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:imagePickerController];
        self.popoverController = [[UIPopoverController alloc] initWithContentViewController:navigationController];
        self.popoverController.delegate = self;
        [self.popoverController presentPopoverFromBarButtonItem:self.photoItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [[SeafUI appdelegate] showDetailView:imagePickerController];
    }
}

- (void)editDone:(id)sender
{
    [self setEditing:NO animated:YES];
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.rightBarButtonItems = self.rightItems;
}

- (void)editStart:(id)sender
{
    [self setEditing:YES animated:YES];
    if (self.editing) {
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = self.doneItem;
        if (IsIpad() && self.popoverController) {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
    }
}

- (void)editSheet:(id)sender
{
    NSMutableArray *titles = nil;
    if ([_directory isKindOfClass:[SeafRepos class]]) {
        titles = [NSMutableArray arrayWithObjects:S_SORT_NAME, S_SORT_MTIME, nil];
    } else if (_directory.editable) {
        titles = [NSMutableArray arrayWithObjects:S_EDIT, S_NEWFILE, S_MKDIR, S_SORT_NAME, S_SORT_MTIME, S_PHOTOS_ALBUM, nil];
        if ([sheetSkippedItems containsObject:@"S_NEWFILE"]) {
            [titles removeObject:S_NEWFILE];
        }
        if (self.photos.count >= 3) [titles addObject:S_PHOTOS_BROWSER];
    } else {
        titles = [NSMutableArray arrayWithObjects:S_SORT_NAME, S_SORT_MTIME, S_PHOTOS_ALBUM, nil];
        if (self.photos.count >= 3) [titles addObject:S_PHOTOS_BROWSER];
    }
    [self showAlertWithAction:titles fromBarItem:self.editItem withTitle:nil];
}

- (void)initNavigationItems:(SeafDir *)directory
{
    if (![directory isKindOfClass:[SeafRepos class]] && directory.editable) {
        self.photoItem = [self getBarItem:@"plus".navItemImgName action:@selector(addPhotos:)size:20];
        self.doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editDone:)];
        self.editItem = [self getBarItemAutoSize:@"ellipsis".navItemImgName action:@selector(editSheet:)];
        UIBarButtonItem *space = [self getSpaceBarItem:16.0];
        self.rightItems = [NSArray arrayWithObjects: self.editItem, space, self.photoItem, nil];

        _selectAllItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select All", @"Seafile") style:UIBarButtonItemStylePlain target:self action:@selector(selectAll:)];
        _selectNoneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select None", @"Seafile") style:UIBarButtonItemStylePlain target:self action:@selector(selectNone:)];
    } else {
        self.editItem = [self getBarItemAutoSize:@"ellipsis".navItemImgName action:@selector(editSheet:)];
        self.rightItems = [NSArray arrayWithObjects: self.editItem, nil];
    }
    self.navigationItem.rightBarButtonItems = self.rightItems;
}

- (SeafDir *)directory
{
    return _directory;
}

- (void)hideSearchBar:(SeafConnection *)conn
{
    if (conn.isSearchEnabled) {
        self.tableView.tableHeaderView = self.searchBar;
    } else {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)setDirectory:(SeafDir *)directory
{
    [self hideSearchBar:directory->connection];
    [self initNavigationItems:directory];

    _directory = directory;
    _connection = directory->connection;
    self.title = directory.name;
    [_directory loadContent:false];
    Debug("repoId:%@, %@, path:%@, loading ... cached:%d %@, editable:%d\n", _directory.repoId, _directory.name, _directory.path, _directory.hasCache, _directory.ooid, _directory.editable);
    if (![_directory isKindOfClass:[SeafRepos class]])
        self.tableView.sectionHeaderHeight = 0;
    [_directory setDelegate:self];
    [self refreshView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (self.loadingView.isAnimating) {
        CGRect viewBounds = self.view.bounds;
        self.loadingView.center = CGPointMake(CGRectGetMidX(viewBounds), CGRectGetMidY(viewBounds));
    }
}

- (void)checkUploadfiles
{
    [_connection checkSyncDst:_directory];
    NSArray *uploadFiles = _directory.uploadFiles;
#if DEBUG
    if (uploadFiles.count > 0)
        Debug("Upload %lu, state=%d", (unsigned long)uploadFiles.count, self.state);
#endif
    for (SeafUploadFile *file in uploadFiles) {
        file.delegate = self;
        if (!file.uploaded && !file.uploading) {
            Debug("background upload %@", file.name);
            [SeafDataTaskManager.sharedObject addUploadTask:file];
        }
    }
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self checkUploadfiles];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (IsIpad() && self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }
}

- (void (^)(void))pullToRefreshBlock
{
    if (!_pullToRefreshBlock) {
        __weak typeof(self) weakSelf = self;
        _pullToRefreshBlock = [^{
            [weakSelf.tableView reloadData];
            if (weakSelf.searchDisplayController.active)
                return;
            if (![weakSelf checkNetworkStatus]) {
                [weakSelf performSelector:@selector(doneLoadingTableViewData) withObject:nil afterDelay:0.1];
                return;
            }
            
            weakSelf.state = STATE_LOADING;
            weakSelf.directory.delegate = weakSelf;
            [weakSelf.directory loadContent:YES];
        } copy];
    }
    return _pullToRefreshBlock;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([_directory hasCache]) {
        [[SeafUI appdelegate] checkOpenLinkAfterAHalfSecond:self];
    }
    // This must be added here, not in viewDidLoad, see SVPullToRefresh author's recommendations:
    //  https://github.com/samvermette/SVPullToRefresh/issues/230
    __weak typeof(self) weakSelf = self;
    [self.tableView addPullToRefresh:[SVArrowPullToRefreshView class] withActionHandler:self.pullToRefreshBlock];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView != self.tableView || ![_directory isKindOfClass:[SeafRepos class]]) {
        return 1;
    }
    return [[((SeafRepos *)_directory)repoGroups] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView != self.tableView)
        return self.searchResults.count;

    if (![_directory isKindOfClass:[SeafRepos class]]) {
        return _directory.allItems.count;
    }
    NSArray *repos =  [[((SeafRepos *)_directory) repoGroups] objectAtIndex:section];
    return repos.count;
}

- (SeafCell *)getCell:(NSString *)CellIdentifier forTableView:(UITableView *)tableView
{
    SeafCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSArray *cells = [SeafileBundle() loadNibNamed:CellIdentifier owner:self options:nil];
        cell = [cells objectAtIndex:0];
    }
    [cell reset];

    return cell;
}

- (SeafCell *)getCellForTableView:(UITableView *)tableView
{
    return [self getCell:@"SeafCell" forTableView:tableView];
}

#pragma mark - Sheet
- (BOOL)shouldShowActionSheetWithIndexPath:(NSIndexPath *)indexPath
{
    return [self sheetTitlesForIndexPath:indexPath].count > 0;
}

- (NSArray <NSString *> *)sheetTitlesForIndexPath:(NSIndexPath *)indexPath
{
    id entry = [self getDentrybyIndexPath:indexPath tableView:self.tableView];
    SeafCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSArray *titles;
    if ([entry isKindOfClass:[SeafRepo class]]) {
        SeafRepo *repo = (SeafRepo *)entry;
        NSMutableArray *modTitles = [NSMutableArray new];
        if (![sheetSkippedItems containsObject:@"S_DOWNLOAD"]) {
            [modTitles addObject:S_DOWNLOAD];
        }
        if (repo.encrypted) {
            [modTitles addObject:S_RESET_PASSWORD];
        }
        titles = [modTitles copy];
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        NSMutableArray *modTitles = [@[S_DOWNLOAD, S_DELETE, S_RENAME, S_SHARE_EMAIL, S_SHARE_LINK] mutableCopy];
        if (!((SeafDir *)entry).editable) {
            [modTitles removeObjectsInArray:@[S_DELETE, S_RENAME]]; // no mods for you!
        }
        if ([sheetSkippedItems containsObject:@"S_DOWNLOAD"]) {
            [modTitles removeObject:S_DOWNLOAD];
        }
        titles = [modTitles copy];
    } else if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *file = (SeafFile *)entry;
        
        NSMutableArray *modTitles = [NSMutableArray new];
        if (![sheetSkippedItems containsObject:@"S_STAR"]) {
            NSString *star = file.isStarred ? S_UNSTAR : S_STAR;
            [modTitles addObject:star];
        }
        
        if (file.mpath)
            [modTitles addObjectsFromArray:@[S_DELETE, S_UPLOAD, S_SHARE_EMAIL, S_SHARE_LINK]];
        else
            [modTitles addObjectsFromArray:@[S_DELETE, S_REDOWNLOAD, S_RENAME, S_SHARE_EMAIL, S_SHARE_LINK]];
        
        if (!file.editable) {
            [modTitles removeObjectsInArray:@[S_DELETE, S_RENAME, S_UPLOAD]]; // no mods for you!
        }
        if ([sheetSkippedItems containsObject:@"S_REDOWNLOAD"]) {
            [modTitles removeObject:S_REDOWNLOAD];
        }
        titles = [modTitles copy];
    } else if ([entry isKindOfClass:[SeafUploadFile class]]) {
        // SCC_CONFIRM: Do we need to remove S_DELETE if not editable?
        NSMutableArray *modTitles = [NSMutableArray arrayWithObjects:S_DOWNLOAD, S_DELETE, S_RENAME, S_SHARE_EMAIL, S_SHARE_LINK, nil];
        if ([sheetSkippedItems containsObject:@"S_DOWNLOAD"]) {
            [modTitles removeObject:S_DOWNLOAD];
        }
        titles = [modTitles copy];
    }
    return titles;
}

- (void)showActionSheetWithIndexPath:(NSIndexPath *)indexPath
{
    _selectedindex = indexPath;
    SeafCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSArray *titles = [self sheetTitlesForIndexPath:indexPath];
    [self showSheetWithTitles:titles andFromView:cell];
}

- (void)showAlertWithIndexPath:(NSIndexPath *)indexPath
{
    _selectedindex = indexPath;
    SeafCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSArray *titles = [self sheetTitlesForIndexPath:indexPath];
    [self showAlertWithAction:titles fromView:cell.moreButton withTitle:nil];
}

- (void)showSheetWithTitles:(NSArray*)titles andFromView:(id)view
{
    SeafActionSheetSection *section = [SeafActionSheetSection sectionWithTitle:nil message:nil buttonTitles:titles buttonStyle:SFActionSheetButtonStyleDefault];
    NSArray *sections;
    if (IsIpad()) {
        sections = @[section];
    }else{
        sections = @[section,[SeafActionSheetSection cancelSection]];
    }

    SeafActionSheet *actionSheet = [SeafActionSheet actionSheetWithSections:sections];
    actionSheet.insets = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);

    [actionSheet setButtonPressedBlock:^(SeafActionSheet *actionSheet, NSIndexPath *indexPath){
        [actionSheet dismissAnimated:YES];
        if (indexPath.section == 0) {
            [self handleAction:titles[indexPath.row]];
        }
    }];

    if (IsIpad()) {
        [actionSheet setOutsidePressBlock:^(SeafActionSheet *sheet) {
            [sheet dismissAnimated:YES];
        }];
        CGPoint point = CGPointZero;

        if ([view isKindOfClass:[SeafCell class]]) {
            SeafCell *cell = (SeafCell*)view;
            point = (CGPoint){CGRectGetMidX(cell.moreButton.frame), CGRectGetMaxY(cell.moreButton.frame) - cell.moreButton.frame.size.height/2};
            point = [self.navigationController.view convertPoint:point fromView:cell];
        } else if ([view isKindOfClass:[UIBarButtonItem class]]) {
            UIBarButtonItem *item = (UIBarButtonItem*)view;
            UIView *itemView = [item valueForKey:@"view"];
            point = (CGPoint){CGRectGetMidX(itemView.frame), CGRectGetMaxY(itemView.frame) + itemView.frame.size.height};
        }

        [actionSheet showFromPoint:point inView:self.navigationController.view arrowDirection:SFActionSheetArrowDirectionTop animated:YES];
    } else {
        UIView *topView = [[[UIApplication sharedApplication] keyWindow].subviews firstObject];
        [actionSheet showInView:topView animated:YES];
    }
}

- (void)showAlertWithAction:(NSArray *)arr fromBarItem:(UIBarButtonItem *)item withTitle:(NSString *)title
{
    UIAlertController *alert = [self generateAlert:arr withTitle:title handler:^(UIAlertAction *action) {
        [self handleAction:action.title];
    }];

    alert.popoverPresentationController.barButtonItem = item;
    [self presentViewController:alert animated:true completion:nil];
}

+ (UIViewController *)topViewController
{
    return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

+ (UIViewController *)topViewController:(UIViewController *)rootViewController
{
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return [self topViewController:[navigationController.viewControllers lastObject]];
    }
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)rootViewController;
        return [self topViewController:tabController.selectedViewController];
    }
    if (rootViewController.presentedViewController) {
        return [self topViewController:rootViewController];
    }
    return rootViewController;
}

- (void)showAlertWithAction:(NSArray *)arr fromView:(UIView *)view withTitle:(NSString *)title
{
    UIAlertController *alert = [self generateAlert:arr withTitle:title handler:^(UIAlertAction *action) {
        [self handleAction:action.title];
    }];
    
    alert.popoverPresentationController.sourceView = view;
    alert.popoverPresentationController.sourceRect = CGRectMake(0.0f, view.center.y, 0.0f, 0.0f);
    // NOTE! You can't assume YOU (this instance) is *the* topmost view controller. You might be in whatever
    //       form of collections of whatnot window arrangements. Hence the topMost.. based methods.
//    [self presentViewController:alert animated:true completion:nil];
    UIViewController *topViewController = [SeafFileViewController topViewController];
    [topViewController presentViewController:alert animated:true completion:nil];
}

- (UITableViewCell *)getSeafUploadFileCell:(SeafUploadFile *)file forTableView:(UITableView *)tableView
{
    file.delegate = self;
    SeafCell *cell = [self getCellForTableView:tableView];
    cell.textLabel.text = file.name;
    cell.imageView.image = file.icon;
    if (file.uploading) {
        cell.progressView.hidden = false;
        [cell.progressView setProgress:file.uProgress];
    } else {
        NSString *sizeStr = [FileSizeFormatter stringFromLongLong:file.filesize];
        NSDictionary *dict = [file uploadAttr];
        if (dict) {
            int utime = [[dict objectForKey:@"utime"] intValue];
            BOOL result = [[dict objectForKey:@"result"] boolValue];
            if (result)
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@, Uploaded %@", @"Seafile"), sizeStr, [SeafDateFormatter stringFromLongLong:utime]];
            else {
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@, waiting to upload", @"Seafile"), sizeStr];
            }
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@, waiting to upload", @"Seafile"), sizeStr];
        }
        [self updateCellDownloadStatus:cell isDownloading:false waiting:false cached:false];
    }
    return cell;
}

- (void)updateCellDownloadStatus:(SeafCell *)cell file:(SeafFile *)sfile waiting:(BOOL)waiting
{
    [self updateCellDownloadStatus:cell isDownloading:sfile.isDownloading waiting:waiting cached:sfile.hasCache];
}

- (void)updateCellDownloadStatus:(SeafCell *)cell isDownloading:(BOOL )isDownloading waiting:(BOOL)waiting cached:(BOOL)cached
{
    if (!cell) return;
    if (isDownloading && cell.downloadingIndicator.isAnimating)
        return;
    //Debug("... %@ cached:%d %d %d", cell.textLabel.text, cached, waiting, isDownloading);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (cached || waiting || isDownloading) {
            cell.cacheStatusView.hidden = false;
            [cell.cacheStatusWidthConstraint setConstant:21.0f];

            if (isDownloading) {
                [cell.downloadingIndicator startAnimating];
            } else {
                [cell.downloadingIndicator stopAnimating];
                NSString *downloadImageNmae = waiting ? @"download_waiting" : @"download_finished";
                cell.downloadStatusImageView.image = [UIImage imageNamed:downloadImageNmae];
            }
            cell.downloadStatusImageView.hidden = isDownloading;
            cell.downloadingIndicator.hidden = !isDownloading;
        } else {
            [cell.downloadingIndicator stopAnimating];
            cell.cacheStatusView.hidden = true;
            [cell.cacheStatusWidthConstraint setConstant:0.0f];
        }
        [cell layoutIfNeeded];
    });
}

- (void)updateCellContent:(SeafCell *)cell file:(SeafFile *)sfile
{
    cell.textLabel.text = sfile.name;
    cell.detailTextLabel.text = sfile.detailText;
    cell.imageView.image = sfile.icon;
    cell.badgeLabel.text = nil;
    [self updateCellDownloadStatus:cell file:sfile waiting:false];
}

- (SeafCell *)getSeafFileCell:(SeafFile *)sfile forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath
{
    [sfile loadCache];
    SeafCell *cell = [self getCellForTableView:tableView];
    cell.cellIndexPath = indexPath;
    // Do we hide the more ... button in the cell? We only show it if there is
    // at least one action you could perform.
    cell.moreButton.hidden = ![self shouldShowActionSheetWithIndexPath:indexPath];
    cell.moreButtonBlock = ^(NSIndexPath *indexPath) {
        Debug(@"%@", indexPath);
        [self showAlertWithIndexPath:indexPath];
    };
    [self updateCellContent:cell file:sfile];
    sfile.delegate = self;
    sfile.udelegate = self;
    if (tableView != self.tableView) {// For search results
        SeafRepo *repo = [_connection getRepo:sfile.repoId];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@, %@", repo.name, sfile.path.stringByDeletingLastPathComponent, sfile.detailText];
    }
    return cell;
}

- (SeafCell *)getSeafDirCell:(SeafDir *)sdir forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath
{
    SeafCell *cell = (SeafCell *)[self getCell:@"SeafDirCell" forTableView:tableView];
    cell.textLabel.text = sdir.name;
    cell.detailTextLabel.text = @"";
    cell.imageView.image = sdir.icon;
    cell.cellIndexPath = indexPath;
    cell.moreButton.hidden = ![self shouldShowActionSheetWithIndexPath:indexPath];
    cell.moreButtonBlock = ^(NSIndexPath *indexPath) {
        Debug(@"%@", indexPath);
        [self showAlertWithIndexPath:indexPath];
    };
    sdir.delegate = self;
    return cell;
}

- (SeafCell *)getSeafRepoCell:(SeafRepo *)srepo forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath
{
    SeafCell *cell = [self getCellForTableView:tableView];
    cell.detailTextLabel.text = srepo.detailText;
    cell.imageView.image = srepo.icon;
    cell.textLabel.text = srepo.name;
    [cell.cacheStatusWidthConstraint setConstant:0.0f];
    cell.cellIndexPath = indexPath;
    cell.moreButton.hidden = ![self shouldShowActionSheetWithIndexPath:indexPath];
    cell.moreButtonBlock = ^(NSIndexPath *indexPath) {
        Debug(@"%@", indexPath);
        [self showAlertWithIndexPath:indexPath];
    };
    srepo.delegate = self;

    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSObject *entry = [self getDentrybyIndexPath:indexPath tableView:tableView];
    if (!entry) return [[UITableViewCell alloc] init];

    if (tableView != self.tableView) {
        // For search results.
        return [self getSeafFileCell:(SeafFile *)entry forTableView:tableView andIndexPath:indexPath];
    }
    if ([entry isKindOfClass:[SeafRepo class]]) {
        return [self getSeafRepoCell:(SeafRepo *)entry forTableView:tableView andIndexPath:indexPath];
    } else if ([entry isKindOfClass:[SeafFile class]]) {
        return [self getSeafFileCell:(SeafFile *)entry forTableView:tableView andIndexPath:indexPath];
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        return [self getSeafDirCell:(SeafDir *)entry forTableView:tableView andIndexPath: indexPath];
    } else {
        return [self getSeafUploadFileCell:(SeafUploadFile *)entry forTableView:tableView];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView != self.tableView) return indexPath;
    NSObject *entry  = [self getDentrybyIndexPath:indexPath tableView:tableView];
    if (tableView.editing && [entry isKindOfClass:[SeafUploadFile class]])
        return nil;
    return indexPath;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView != self.tableView) return NO;
    NSObject *entry  = [self getDentrybyIndexPath:indexPath tableView:tableView];
    // This is the binnj "editable override" flag check.
    if (([entry isKindOfClass:[SeafDir class]] && !((SeafDir *)entry).editable) ||
        ([entry isKindOfClass:[SeafFile class]] && !((SeafFile *)entry).editable)) {
        return NO;
    }
    return ![entry isKindOfClass:[SeafUploadFile class]];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)popupSetRepoPassword:(SeafRepo *)repo
{
    self.state = STATE_PASSWORD;
    [self popupSetRepoPassword:repo handler:^{
            [SVProgressHUD dismiss];
            self.state = STATE_INIT;
            SeafFileViewController *controller = [[UIStoryboard storyboardWithName:@"FolderView_iPad" bundle:SeafileBundle()] instantiateViewControllerWithIdentifier:@"MASTERVC"];
            [self.navigationController pushViewController:controller animated:YES];
            [controller setDirectory:(SeafDir *)repo];
    }];
}

- (void)popupMkdirView
{
    self.state = STATE_MKDIR;
    _directory.delegate = self;
    [self popupInputView:S_MKDIR placeholder:NSLocalizedString(@"New folder name", @"Seafile") secure:false handler:^(NSString *input) {
        if (!input || input.length == 0) {
            [self alertWithTitle:NSLocalizedString(@"Folder name must not be empty", @"Seafile")];
            return;
        }
        if (![input isValidFileName]) {
            [self alertWithTitle:NSLocalizedString(@"Folder name invalid", @"Seafile")];
            return;
        }
        [_directory mkdir:input];
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Creating folder ...", @"Seafile")];
    }];
}

- (void)popupCreateView
{
    self.state = STATE_CREATE;
    _directory.delegate = self;
    [self popupInputView:S_NEWFILE placeholder:NSLocalizedString(@"New file name", @"Seafile") secure:false handler:^(NSString *input) {
        if (!input || input.length == 0) {
            [self alertWithTitle:NSLocalizedString(@"File name must not be empty", @"Seafile")];
            return;
        }
        if (![input isValidFileName]) {
            [self alertWithTitle:NSLocalizedString(@"File name invalid", @"Seafile")];
            return;
        }
        [_directory createFile:input];
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Creating file ...", @"Seafile")];
    }];
}

- (void)popupRenameView:(NSString *)newName
{
    self.state = STATE_RENAME;
    [self popupInputView:S_RENAME placeholder:newName secure:false handler:^(NSString *input) {
        if (!input || input.length == 0) {
            [self alertWithTitle:NSLocalizedString(@"File name must not be empty", @"Seafile")];
            return;
        }
        if (![input isValidFileName]) {
            [self alertWithTitle:NSLocalizedString(@"File name invalid", @"Seafile")];
            return;
        }
        NSString *priorExtension = newName.pathExtension;
        // SCC: Ensure the same file extension is used! Otherwise you can rename foo.jpg to bar
        //      and it will no longer display quite right, loses preview, etc.
        if (priorExtension.length > 0 && ![priorExtension isEqualToString:input.pathExtension]) {
            input = [input stringByAppendingPathExtension:priorExtension];
        }
        
        [_directory renameFile:(SeafFile *)_curEntry newName:input];
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Renaming file ...", @"Seafile")];
    }];
}

- (void)popupDirChooseView:(SeafUploadFile *)file
{
    self.ufile = file;
    UIViewController *controller = [[SeafDirViewController alloc] initWithSeafDir:self.connection.rootFolder delegate:self chooseRepo:false];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    [navController setModalPresentationStyle:UIModalPresentationFormSheet];
    [[SeafUI appdelegate].window.rootViewController presentViewController:navController animated:YES completion:nil];
    if (IsIpad()) {
        CGRect frame = navController.view.superview.frame;
        navController.view.superview.frame = CGRectMake(frame.origin.x+frame.size.width/2-320/2, frame.origin.y+frame.size.height/2-500/2, 320, 500);
    }
}

- (SeafBase *)getDentrybyIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
    if (!indexPath) return nil;
    @try {
        if (tableView != self.tableView) {
            return [self.searchResults objectAtIndex:indexPath.row];
        } else if (![_directory isKindOfClass:[SeafRepos class]])
            return (indexPath.row < _directory.allItems.count ? [_directory.allItems objectAtIndex:[indexPath row]] : nil);
        NSArray *repos = [[((SeafRepos *)_directory) repoGroups] objectAtIndex:[indexPath section]];
        return [repos objectAtIndex:[indexPath row]];
    } @catch(NSException *exception) {
        return nil;
    }
}

- (BOOL)isCurrentFileImage:(id<SeafPreView>)item
{
    if (![item conformsToProtocol:@protocol(SeafPreView)])
        return NO;
    return item.isImageFile;
}

- (NSArray *)getCurrentFileImagesInTableView:(UITableView *)tableView
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    NSArray *items = (tableView == self.tableView) ? _directory.allItems : self.searchResults;
    for (id entry in items) {
        if ([entry conformsToProtocol:@protocol(SeafPreView)]
            && [(id<SeafPreView>)entry isImageFile])
            [arr addObject:entry];
    }
    return arr;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.navigationController.topViewController != self)   return;
    _selectedindex = indexPath;
    if (tableView.editing == YES) {
        return [self noneSelected:NO];
    }
    _curEntry = [self getDentrybyIndexPath:indexPath tableView:tableView];
    Debug("Select %@", _curEntry.name);
    if (!_curEntry) {
        return [tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
    }
    if ([_curEntry isKindOfClass:[SeafRepo class]] && [(SeafRepo *)_curEntry passwordRequired]) {
        return [self popupSetRepoPassword:(SeafRepo *)_curEntry];
    }
    [_curEntry setDelegate:self];
    if ([_curEntry conformsToProtocol:@protocol(SeafPreView)]) {
        if ([_curEntry isKindOfClass:[SeafFile class]] && ![(SeafFile *)_curEntry hasCache]) {
            SeafCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            [self updateCellDownloadStatus:cell file:(SeafFile *)_curEntry waiting:true];
        }

        id<SeafPreView> item = (id<SeafPreView>)_curEntry;

        if ([self isCurrentFileImage:item]) {
            [self.detailViewController setPreViewPhotos:[self getCurrentFileImagesInTableView:tableView] current:item master:self];
        } else {
            [self.detailViewController setPreViewItem:item master:self];
        }
        // Why would we only show previews on the phone and not iPad? Who knows! So we comment out the
        // disabling below.
//        if (!IsIpad()) {
        if (self.detailViewController.state == PREVIEW_QL_MODAL) { // Use fullscreen preview for doc, xls, etc.
            [self presentOrPushDetailViewController:item animated:YES completion:nil];
        } else {
            [[SeafUI appdelegate] showDetailView:self.detailViewController];
        }
//        }
    } else if ([_curEntry isKindOfClass:[SeafDir class]]) {
        SeafFileViewController *controller = [[UIStoryboard storyboardWithName:@"FolderView_iPad" bundle:SeafileBundle()] instantiateViewControllerWithIdentifier:@"MASTERVC"];
        [controller setDirectory:(SeafDir *)_curEntry];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)presentOrPushDetailViewController:(id <SeafPreView>)item
                                 animated:(BOOL)animated
                               completion:(void (^)(void))completion
{
    if (item.editable &&
        item.isPDFFile &&
        [SeafDetailViewController editPDFBlock] != nil &&
        [_curEntry isKindOfClass:[SeafFile class]])
    {
        SeafFile *seafFile = (SeafFile *)item;
        UIViewController *pdfViewController = [SeafDetailViewController editPDFBlock](self.detailViewController,
                                                                                      seafFile,
                                                                                      seafFile.exportURL);
        // Can't do this as we have no nav bars up top, need to push directly
        //   [self presentViewController:pdfViewController animated:animated completion:completion];
        
        // If we have a completion block, we have to wrap this with CATransaction calls
        if (completion) {
            [CATransaction begin];
        }
        [self.navigationController pushViewController:pdfViewController animated:animated];
        if (completion) {
            [CATransaction setCompletionBlock:completion];
            [CATransaction commit];
        }
    }
    else {
        // We only need to call reloadData if there is a presentingViewController on the qlViewController
        if (self.detailViewController.qlViewController.presentingViewController) {
            [self.detailViewController.qlViewController reloadData];
        }
        [self presentViewController:self.detailViewController.qlViewController animated:animated completion:completion];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.editing == YES) {
        if (![tableView indexPathsForSelectedRows])
            [self noneSelected:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (![_directory isKindOfClass:[SeafRepos class]]) {
        return 0.01;
    } else {
        return 24;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.searchResults || tableView != self.tableView || ![_directory isKindOfClass:[SeafRepos class]])
        return nil;

    NSString *text = nil;
    if (section == 0) {
        text = NSLocalizedString(@"My Own Libraries", @"Seafile");
    } else {
        NSArray *repos =  [[((SeafRepos *)_directory)repoGroups] objectAtIndex:section];
        SeafRepo *repo = (SeafRepo *)[repos objectAtIndex:0];
        if (!repo) {
            text = @"";
        } else if ([repo.type isEqualToString:SHARE_REPO]) {
            text = NSLocalizedString(@"Shared to me", @"Seafile");
        } else {
            if ([repo.owner isEqualToString:ORG_REPO]) {
                text = NSLocalizedString(@"Organization", @"Seafile");
            } else {
                text = repo.owner;
            }
        }
    }
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 3, tableView.bounds.size.width - 10, 18)];
    label.font = [UIFont systemFontOfSize:12];
    label.text = text;
    label.textColor = [UIColor darkTextColor];
    label.backgroundColor = [UIColor clearColor];
    [headerView setBackgroundColor:[UIColor colorWithRed:246/255.0 green:246/255.0 blue:250/255.0 alpha:1.0]];
    [headerView addSubview:label];
    return headerView;
}

#pragma mark - SeafDentryDelegate
- (SeafPhoto *)getSeafPhoto:(id<SeafPreView>)photo {
    if (!self.inPhotoBrowser || ![photo isImageFile])
        return nil;
    for (SeafPhoto *sphoto in self.photos) {
        if (sphoto.file == photo) {
            return sphoto;
        }
    }
    return nil;
}

- (void)download:(SeafBase *)entry progress:(float)progress
{
    if ([entry isKindOfClass:[SeafFile class]]) {
        [self.detailViewController download:entry progress:progress];
        SeafPhoto *photo = [self getSeafPhoto:(id<SeafPreView>)entry];
        [photo setProgress:progress];
        SeafCell *cell = [self getEntryCell:(SeafFile *)entry indexPath:nil];
        [self updateCellDownloadStatus:cell file:(SeafFile *)entry waiting:false];
    }
}

- (void)download:(SeafBase *)entry complete:(BOOL)updated
{
    if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *file = (SeafFile *)entry;
        [self updateEntryCell:file];
        [self.detailViewController download:file complete:updated];
        SeafPhoto *photo = [self getSeafPhoto:(id<SeafPreView>)entry];
        [photo complete:updated error:nil];
    } else if (entry == _directory) {
        [self dismissLoadingView];
        [SVProgressHUD dismiss];
        [self doneLoadingTableViewData];
        if (self.state == STATE_DELETE && !IsIpad()) {
            [self.detailViewController goBack:nil];
        }

        [self dismissLoadingView];
        if (updated) {
            [self refreshView];
            [[SeafUI appdelegate] checkOpenLinkAfterAHalfSecond:self];
        } else {
            //[self.tableView reloadData];
        }
        self.state = STATE_INIT;
    }
}

- (void)download:(SeafBase *)entry failed:(NSError *)error
{
    if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *file = (SeafFile *)entry;
        [self updateEntryCell:file];
        [self.detailViewController download:entry failed:error];
        SeafPhoto *photo = [self getSeafPhoto:file];
        return [photo complete:false error:error];
    }

    NSCAssert([entry isKindOfClass:[SeafDir class]], @"entry must be SeafDir");
    Debug("state=%d %@,%@, %@\n", self.state, entry.path, entry.name, _directory.path);
    if (entry == _directory) {
        [self doneLoadingTableViewData];
        switch (self.state) {
            case STATE_DELETE:
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to delete files", @"Seafile")];
                break;
            case STATE_MKDIR:
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to create folder", @"Seafile")];
                [self performSelector:@selector(popupMkdirView) withObject:nil afterDelay:1.0];
                break;
            case STATE_CREATE:
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to create file", @"Seafile")];
                [self performSelector:@selector(popupCreateView) withObject:nil afterDelay:1.0];
                break;
            case STATE_COPY:
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to copy files", @"Seafile")];
                break;
            case STATE_MOVE:
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to move files", @"Seafile")];
                break;
            case STATE_RENAME: {
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to rename file", @"Seafile")];
                SeafFile *file = (SeafFile *)_curEntry;
                [self performSelector:@selector(popupRenameView:) withObject:file.name afterDelay:1.0];
                break;
            }
            case STATE_LOADING:
                if (!_directory.hasCache) {
                    [self dismissLoadingView];
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to load files", @"Seafile")];
                } else
                    [SVProgressHUD dismiss];
                break;
            default:
                break;
        }
        self.state = STATE_INIT;
        [self dismissLoadingView];
    }
}

- (void)doneLoadingTableViewData
{
    [self.tableView.pullToRefreshView stopAnimating];
}

#pragma mark - edit files
- (void)editOperation:(id)sender
{
    SeafFileViewController *appDelegateFileVC = [SeafUI appdelegate].fileVC;
    // Alright kids, gather 'round. It appears that the expectation below
    // is that if an editOperation is being called on this object *AND*
    // the AppDelegate version is DIFFERENT then we use the AppDelegate one
    // INSTEAD.
    
    // However. However. For some crazy people who use nearly all of the wonderful
    // UI in this project, the _directory object held in the AppDelegate version
    //     /may not have the repoId set/
    // Thus we check that first, and ONLY swap to AppDelegate's instance if it
    // has a valid repoId (and thus can compose the correct URL for move/copy files).
    
    if (self != appDelegateFileVC &&
        appDelegateFileVC.directory.repoId.length > 0) {
        // forward edit operation to new instance of fileVC?
        return [appDelegateFileVC editOperation:sender];
    }

    switch ([sender tag]) {
        case EDITOP_MKDIR:
            [self popupMkdirView];
            break;

        case EDITOP_CREATE:
            [self popupCreateView];
            break;

        case EDITOP_COPY:
            self.state = STATE_COPY;
            [self popupDirChooseView:nil];
            break;
        case EDITOP_MOVE:
            self.state = STATE_MOVE;
            [self popupDirChooseView:nil];
            break;
        case EDITOP_DELETE: {
            NSArray *idxs = [self.tableView indexPathsForSelectedRows];
            if (!idxs) return;
            NSMutableArray *entries = [[NSMutableArray alloc] init];
            for (NSIndexPath *indexPath in idxs) {
                [entries addObject:[_directory.allItems objectAtIndex:indexPath.row]];
            }
            self.state = STATE_DELETE;
            _directory.delegate = self;
            [_directory delEntries:entries];
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Deleting files ...", @"Seafile")];
            break;
        }
        default:
            break;
    }
}

- (void)deleteFile:(SeafFile *)file
{
    NSArray *entries = [NSArray arrayWithObject:file];
    self.state = STATE_DELETE;
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Deleting file ...", @"Seafile")];
    _directory.delegate = self;
    [_directory delEntries:entries];
}

- (void)deleteDir:(SeafDir *)dir
{
    NSArray *entries = [NSArray arrayWithObject:dir];
    self.state = STATE_DELETE;
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Deleting directory ...", @"Seafile")];
    _directory.delegate = self;
    [_directory delEntries:entries];
}

- (void)redownloadFile:(SeafFile *)file
{
    [file cancel];
    [file deleteCache];
    [self.detailViewController setPreViewItem:nil master:nil];
    [self tableView:self.tableView didSelectRowAtIndexPath:_selectedindex];
}

- (void)downloadDir:(SeafDir *)dir
{
    Debug("download dir: %@ %@", dir.repoId, dir.path);
    [SVProgressHUD showSuccessWithStatus:[NSLocalizedString(@"Start to download folder: ", @"Seafile") stringByAppendingString:dir.name]];
    [_connection performSelectorInBackground:@selector(downloadDir:) withObject:dir];
}

- (void)downloadRepo:(SeafRepo *)repo
{
    Debug("download repo: %@ %@", repo.repoId, repo.path);
    [SVProgressHUD showSuccessWithStatus:[NSLocalizedString(@"Start to download library: ", @"Seafile") stringByAppendingString:repo.name]];
    [_connection performSelectorInBackground:@selector(downloadDir:) withObject:repo];
}

- (void)saveImageToAlbum:(SeafFile *)file
{
    UIImage *img = [UIImage imageWithContentsOfFile:file.cachePath];
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
    dispatch_semaphore_wait(SeafGlobal.sharedObject.saveAlbumSem, timeout);
    Info("Write image file %@ %@ to album", file.name, file.cachePath);
    UIImageWriteToSavedPhotosAlbum(img, self, @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), (void *)CFBridgingRetain(file));
}

- (void)savePhotosToAlbum
{
    SeafFileDidDownloadBlock block = ^(SeafFile *file, BOOL result) {
        if (!result) {
            return Warning("Failed to donwload file %@", file.path);
        }
        [file setFileDownloadedBlock:nil];
        [self performSelectorInBackground:@selector(saveImageToAlbum:) withObject:file];
    };
    for (id entry in _directory.allItems) {
        if (![entry isKindOfClass:[SeafFile class]]) continue;
        SeafFile *file = (SeafFile *)entry;
        if (!file.isImageFile) continue;
        [file loadCache];
        NSString *path = file.cachePath;
        if (!path) {
            [file setFileDownloadedBlock:block];
            [SeafDataTaskManager.sharedObject addFileDownloadTask:file];
        } else {
            block(file, true);
        }
    }
    [SVProgressHUD showInfoWithStatus:S_SAVING_PHOTOS_ALBUM];
}

- (void)browserAllPhotos
{
    MWPhotoBrowser *_mwPhotoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    _mwPhotoBrowser.displayActionButton = false;
    _mwPhotoBrowser.displayNavArrows = true;
    _mwPhotoBrowser.displaySelectionButtons = false;
    _mwPhotoBrowser.alwaysShowControls = false;
    _mwPhotoBrowser.zoomPhotosToFill = YES;
    _mwPhotoBrowser.enableGrid = true;
    _mwPhotoBrowser.startOnGrid = true;
    _mwPhotoBrowser.enableSwipeToDismiss = false;
    _mwPhotoBrowser.preLoadNumLeft = 0;
    _mwPhotoBrowser.preLoadNumRight = 1;

    self.inPhotoBrowser = true;

    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:_mwPhotoBrowser];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nc animated:YES completion:nil];
}

- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void *)ctxInfo
{
    SeafFile *file = (__bridge SeafFile *)ctxInfo;
    Info("Finish write image file %@ %@ to album", file.name, file.cachePath);
    dispatch_semaphore_signal(SeafGlobal.sharedObject.saveAlbumSem);
    if (error) {
        Warning("Failed to save file %@ to album: %@", file.name, error);
        [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:NSLocalizedString(@"Failed to save %@ to album", @"Seafile"), file.name]];
    }
}

- (void)renameFile:(SeafFile *)file
{
    if (!file.editable) return;
    _curEntry = file;
    [self popupRenameView:file.name];
}

- (void)reloadIndex:(NSIndexPath *)indexPath
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (indexPath) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (!cell) return;
            @try {
                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            } @catch(NSException *exception) {
                Warning("Failed to reload cell %@: %@", indexPath, exception);
            }
        } else
            [self.tableView reloadData];
    });
}

- (void)deleteEntry:(id)entry
{
    self.state = STATE_DELETE;
    if ([entry isKindOfClass:[SeafUploadFile class]]) {
        if (self.detailViewController.preViewItem == entry)
            self.detailViewController.preViewItem = nil;
        Debug("Remove SeafUploadFile %@", ((SeafUploadFile *)entry).name);
        [self.directory->connection removeUploadfile:(SeafUploadFile *)entry];
        [self.tableView reloadData];
    } else if ([entry isKindOfClass:[SeafFile class]])
        [self deleteFile:(SeafFile*)entry];
    else if ([entry isKindOfClass:[SeafDir class]])
        [self deleteDir: (SeafDir*)entry];
}

- (void)handleAction:(NSString *)title
{
    Debug("handle action title:%@, %@", title, _selectedCell);
    if (_selectedCell) {
        _selectedCell = nil;
    }

    if ([S_NEWFILE isEqualToString:title]) {
        [self popupCreateView];
    } else if ([S_MKDIR isEqualToString:title]) {
        [self popupMkdirView];
    } else if ([S_DOWNLOAD isEqualToString:title]) {
        SeafDir *dir = (SeafDir *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [self downloadDir:dir];
    } else if ([S_PHOTOS_ALBUM isEqualToString:title]) {
        [self savePhotosToAlbum];
    } else if ([S_PHOTOS_BROWSER isEqualToString:title]) {
        [self browserAllPhotos];
    } else if ([S_EDIT isEqualToString:title]) {
        [self editStart:nil];
    } else if ([S_DELETE isEqualToString:title]) {
        SeafBase *entry = (SeafBase *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [self deleteEntry:entry];
    } else if ([S_REDOWNLOAD isEqualToString:title]) {
        SeafFile *file = (SeafFile *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [self redownloadFile:file];
    } else if ([S_RENAME isEqualToString:title]) {
        SeafFile *file = (SeafFile *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [self renameFile:file];
    } else if ([S_UPLOAD isEqualToString:title]) {
        SeafFile *file = (SeafFile *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [file update:self];
        [self reloadIndex:_selectedindex];
    } else if ([S_SHARE_EMAIL isEqualToString:title]) {
        self.state = STATE_SHARE_EMAIL;
        SeafBase *entry = (SeafBase *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        if (!entry.shareLink) {
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Generate share link ...", @"Seafile")];
            [entry generateShareLink:self];
        } else {
            [self generateSharelink:entry WithResult:YES];
        }
    } else if ([S_SHARE_LINK isEqualToString:title]) {
        self.state = STATE_SHARE_LINK;
        SeafBase *entry = (SeafBase *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        if (!entry.shareLink) {
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Generate share link ...", @"Seafile")];
            [entry generateShareLink:self];
        } else {
            [self generateSharelink:entry WithResult:YES];
        }
    } else if ([S_SORT_NAME isEqualToString:title]) {
        [_directory reSortItemsByName];
        [self.tableView reloadData];
    } else if ([S_SORT_MTIME isEqualToString:title]) {
        [_directory reSortItemsByMtime];
        [self.tableView reloadData];
    } else if ([S_RESET_PASSWORD isEqualToString:title]) {
        SeafRepo *repo = (SeafRepo *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [repo->connection saveRepo:repo.repoId password:nil];
        [self popupSetRepoPassword:repo];
    } else if ([S_CLEAR_REPO_PASSWORD isEqualToString:title]) {
        SeafRepo *repo = (SeafRepo *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [repo->connection saveRepo:repo.repoId password:nil];
        [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"Clear library password successfully.", @"Seafile")];
    } else if ([S_STAR isEqualToString:title]) {
        SeafFile *file = (SeafFile *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [file setStarred:YES];
    }else if ([S_UNSTAR isEqualToString:title]) {
        SeafFile *file = (SeafFile *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
        [file setStarred:NO];
    }
}

- (void)backgroundUpload:(SeafUploadFile *)ufile
{
    [SeafDataTaskManager.sharedObject addUploadTask:ufile];
}

- (void)uploadFile:(SeafUploadFile *)ufile toDir:(SeafDir *)dir overwrite:(BOOL)overwrite
{
    ufile.overwrite = overwrite;
    [dir addUploadFile:ufile flush:true];
    [NSThread detachNewThreadSelector:@selector(backgroundUpload:) toTarget:self withObject:ufile];
}

- (void)uploadFile:(SeafUploadFile *)ufile toDir:(SeafDir *)dir
{
    if ([dir nameExist:ufile.name]) {
        [self alertWithTitle:STR_12 message:nil yes:^{
            [self uploadFile:ufile toDir:dir overwrite:true];
        } no:^{
            [self uploadFile:ufile toDir:dir overwrite:false];
        }];
    } else
        [self uploadFile:ufile toDir:dir overwrite:false];
}

- (void)uploadFile:(SeafUploadFile *)file
{
    file.delegate = self;
    [self popupDirChooseView:file];
}

#pragma mark - SeafDirDelegate
- (void)chooseDir:(UIViewController *)c dir:(SeafDir *)dir
{
    [c.navigationController dismissViewControllerAnimated:YES completion:nil];
    if (self.ufile) {
        return [self uploadFile:self.ufile toDir:dir];
    }
    NSArray *idxs = [self.tableView indexPathsForSelectedRows];
    if (!idxs) return;
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in idxs) {
        [entries addObject:[_directory.allItems objectAtIndex:indexPath.row]];
    }
    _directory.delegate = self;
    if (self.state == STATE_COPY) {
        [_directory copyEntries:entries dstDir:dir];
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Copying files ...", @"Seafile")];
    } else {
        [_directory moveEntries:entries dstDir:dir];
        [SVProgressHUD showWithStatus:NSLocalizedString(@"Moving files ...", @"Seafile")];
    }
}
- (void)cancelChoose:(UIViewController *)c
{
    [c.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - QBImagePickerControllerDelegate
- (NSMutableSet *)getExistedNameSet
{
    NSMutableSet *nameSet = [[NSMutableSet alloc] init];
    for (id obj in _directory.allItems) {
        NSString *name = nil;
        if ([obj conformsToProtocol:@protocol(SeafPreView)]) {
            name = ((id<SeafPreView>)obj).name;
        } else if ([obj isKindOfClass:[SeafBase class]]) {
            name = ((SeafBase *)obj).name;
        }
        [nameSet addObject:name];
    }
    return nameSet;
}

- (NSString *)getUniqueFilename:(NSString *)name ext:(NSString *)ext nameSet:(NSMutableSet *)nameSet
{
    for (int i = 1; i < 999; ++i) {
        NSString *filename = [NSString stringWithFormat:@"%@ (%d).%@", name, i, ext];
        if (![nameSet containsObject:filename])
            return filename;
    }
    NSString *date = [self.formatter stringFromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%@-%@.%@", name, date, ext];
}

- (void)uploadPickedAssets:(NSArray *)assets overwrite:(BOOL)overwrite
{
    NSMutableSet *nameSet = overwrite ? [NSMutableSet new] : [self getExistedNameSet];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString *uploadDir = [self.connection uniqueUploadDir];
    for (ALAsset *asset in assets) {
        NSString *filename = [Utils assertName:asset];
        Debug("Upload picked file : %@", filename);
        if (!overwrite && [nameSet containsObject:filename]) {
            NSString *name = filename.stringByDeletingPathExtension;
            NSString *ext = filename.pathExtension;
            filename = [self getUniqueFilename:name ext:ext nameSet:nameSet];
        }
        [nameSet addObject:filename];
        NSString *path = [uploadDir stringByAppendingPathComponent:filename];
        SeafUploadFile *file =  [self.connection getUploadfile:path];
        file.overwrite = overwrite;
        [file setAsset:asset url:asset.defaultRepresentation.url];
        file.delegate = self;
        [files addObject:file];
        [self.directory addUploadFile:file flush:false];
    }
    [SeafUploadFile saveAttrs];
    [self.tableView reloadData];
    for (SeafUploadFile *file in files) {
        [SeafDataTaskManager.sharedObject addUploadTask:file];
    }
}

- (void)uploadPickedPHAssets:(NSArray <PHAsset *> *)phAssets overwrite:(BOOL)overwrite
{
    NSMutableSet *nameSet = overwrite ? [NSMutableSet new] : [self getExistedNameSet];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString *uploadDir = [self.connection uniqueUploadDir];
    for (PHAsset *phAsset in phAssets) {
        NSString *filename = [Utils assertPHAssetName:phAsset];
        Debug("Upload picked file : %@", filename);
        if (!overwrite && [nameSet containsObject:filename]) {
            NSString *name = filename.stringByDeletingPathExtension;
            NSString *ext = filename.pathExtension;
            filename = [self getUniqueFilename:name ext:ext nameSet:nameSet];
        }
        [nameSet addObject:filename];
        NSString *path = [uploadDir stringByAppendingPathComponent:filename];
        SeafUploadFile *file =  [self.connection getUploadfile:path];
        file.overwrite = overwrite;
        [file setPHAsset:phAsset];
        file.delegate = self;
        [files addObject:file];
        [self.directory addUploadFile:file flush:false];
    }
    [SeafUploadFile saveAttrs];
    [self.tableView reloadData];
    for (SeafUploadFile *file in files) {
        [SeafDataTaskManager.sharedObject addUploadTask:file];
    }
}

- (void)uploadPickedAssetsUrl:(NSArray *)urls overwrite:(BOOL)overwrite
{
    if (urls.count == 0) return;
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    NSURL *last = [urls objectAtIndex:urls.count-1];
    for (NSURL *url in urls) {
        [SeafDataTaskManager.sharedObject assetForURL:url
                                  resultBlock:^(ALAsset *asset) {
                                      if (assets) [assets addObject:asset];
                                      if (url == last) [self uploadPickedAssets:assets overwrite:overwrite];
                                  } failureBlock:^(NSError *error) {
                                      if (url == last) [self uploadPickedAssets:assets overwrite:overwrite];
                                  }];
    }
}

- (void)dismissImagePickerController:(UIViewController *)imagePickerController
{
    if (IsIpad()) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    } else {
        [imagePickerController.navigationController dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    [self dismissImagePickerController:imagePickerController];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets
{
    if (assets.count == 0) return;
    NSSet *nameSet = [self getExistedNameSet];
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    int duplicated = 0;
    for (ALAsset *asset in assets) {
        NSURL *url = asset.defaultRepresentation.url;
        if (url) {
            NSString *filename = [Utils assertName:asset];
            if ([nameSet containsObject:filename])
                duplicated++;
            [urls addObject:url];
        } else
            Warning("Failed to get asset url %@", asset);
    }
    [self dismissImagePickerController:imagePickerController];
    if (duplicated > 0) {
        NSString *title = duplicated == 1 ? STR_12 : STR_13;
        [self alertWithTitle:title message:nil yes:^{
            [self uploadPickedAssetsUrl:urls overwrite:true];
        } no:^{
            [self uploadPickedAssetsUrl:urls overwrite:false];
        }];
    } else
        [self uploadPickedAssetsUrl:urls overwrite:false];
}

#pragma mark - SeafilePHPhotoFileViewController

- (void)phAssetImagePickerControllerDidCancel;
{
    self.customImagePicker = nil;
}

- (void)phAssetImagePickerControllerDidSelectAssets:(NSArray <PHAsset *> *)phAssets
{
    if (phAssets.count == 0) return;
    NSSet *nameSet = [self getExistedNameSet];
    NSMutableArray <PHAsset *> *pickedAssets = [[NSMutableArray alloc] init];
    int duplicated = 0;
    for (PHAsset *phAsset in phAssets) {
        NSString *filename = [Utils assertPHAssetName:phAsset];
        if ([nameSet containsObject:filename])
            duplicated++;
        [pickedAssets addObject:phAsset];
    }
    if (duplicated > 0) {
        NSString *title = duplicated == 1 ? STR_12 : STR_13;
        [self alertWithTitle:title message:nil yes:^{
            [self uploadPickedPHAssets:pickedAssets overwrite:true];
        } no:^{
            [self uploadPickedPHAssets:pickedAssets overwrite:false];
        }];
    }
    else {
        [self uploadPickedPHAssets:pickedAssets overwrite:false];
    }
    self.customImagePicker = nil;
}

#pragma mark - UIPopoverControllerDelegate
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popoverController = nil;
}

#pragma mark - SeafFileUpdateDelegate
- (void)updateProgress:(SeafFile *)file progress:(float)progress
{
    [self updateEntryCell:file];
}
- (void)updateComplete:(nonnull SeafFile * )file result:(BOOL)res
{
    [self updateEntryCell:file];
}

#pragma mark - SeafUploadDelegate
- (void)updateFileCell:(SeafUploadFile *)file result:(BOOL)res progress:(float)progress completed:(BOOL)completed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = nil;
        SeafCell *cell = [self getEntryCell:file indexPath:&indexPath];
        if (!cell) return;
        if (!completed && res) {
            cell.progressView.hidden = false;
            cell.detailTextLabel.text = nil;
            [cell.progressView setProgress:progress];
        } else if (indexPath) {
            [self reloadIndex:indexPath];
        }
    });
}

- (void)uploadProgress:(SeafUploadFile *)file progress:(float)progress
{
    [self updateFileCell:file result:true progress:progress completed:false];
}

- (void)uploadComplete:(BOOL)success file:(SeafUploadFile *)file oid:(NSString *)oid
{
    if (!success) {
        return [self updateFileCell:file result:false progress:0 completed:true];
    }
    [self updateFileCell:file result:YES progress:1.0f completed:YES];
    if (self.isVisible) {
        [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:NSLocalizedString(@"File '%@' uploaded success", @"Seafile"), file.name]];
        if (pullToRefreshAutomaticallyAfterUpload && self.pullToRefreshBlock != NULL) {
            __weak SeafFileViewController *welf = self;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                welf.pullToRefreshBlock();
            });
        }
    }
}

#pragma mark - UISearchDisplayDelegate
#define SEARCH_STATE_INIT NSLocalizedString(@"Click \"Search\" to start", @"Seafile")
#define SEARCH_STATE_SEARCHING NSLocalizedString(@"Searching", @"Seafile")
#define SEARCH_STATE_NORESULTS NSLocalizedString(@"No Results", @"Seafile")

- (void)setSearchState:(UISearchDisplayController *)controller state:(NSString *)state
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.001*NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        for (UIView* v in controller.searchResultsTableView.subviews) {
            if ([v isKindOfClass: [UILabel class]] &&
                ([[(UILabel*)v text] isEqualToString:SEARCH_STATE_NORESULTS]
                 || [[(UILabel*)v text] isEqualToString:SEARCH_STATE_INIT]
                 || [[(UILabel*)v text] isEqualToString:SEARCH_STATE_SEARCHING])) {
                    [(UILabel*)v setText:state];
                    v.frame = CGRectMake(0, 132, controller.searchResultsTableView.frame.size.width, 50);
                    break;
                }
        }
    });
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
    self.searchResults = [[NSMutableArray alloc] init];
    [self.searchDisplayController.searchResultsTableView reloadData];
    [self setSearchState:self.searchDisplayController state:SEARCH_STATE_INIT];
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    self.searchResults = nil;
    if ([_directory isKindOfClass:[SeafRepos class]]) {
        self.tableView.sectionHeaderHeight = HEADER_HEIGHT;
        [self.tableView reloadData];
    }
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    self.searchResults = [[NSMutableArray alloc] init];
    [self setSearchState:controller state:SEARCH_STATE_INIT];
    return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    tableView.sectionHeaderHeight = 0;
    [self setSearchState:controller state:SEARCH_STATE_INIT];
}

#pragma mark - UISearchBarDelegate
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    Debug("search %@", searchBar.text);
    [self setSearchState:self.searchDisplayController state:SEARCH_STATE_SEARCHING];
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Searching ...", @"Seafile")];
    NSString *repoId = [_directory isKindOfClass:[SeafRepos class]] ? nil : _directory.repoId;
    [_connection search:searchBar.text repo:repoId success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSMutableArray *results) {
        [SVProgressHUD dismiss];
        if (results.count == 0)
            [self setSearchState:self.searchDisplayController state:SEARCH_STATE_NORESULTS];
        else {
            self.searchResults = results;
            [self.searchDisplayController.searchResultsTableView reloadData];
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSError *error) {
        if (response.statusCode == 404) {
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Search is not supported on the server", @"Seafile")];
        } else
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to search", @"Seafile")];
    }];
}

- (NSUInteger)indexOfEntry:(id<SeafPreView>)entry
{
    NSArray *arr = self.searchResults != nil ? self.searchResults : _directory.allItems;
    return [arr indexOfObject:entry];
}
- (UITableView *)currentTableView
{
    return self.searchResults != nil ? self.searchDisplayController.searchResultsTableView : self.tableView;
}

- (void)photoSelectedChanged:(id<SeafPreView>)from to:(id<SeafPreView>)to;
{
    NSUInteger index = [self indexOfEntry:to];
    if (index == NSNotFound)
        return;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [[self currentTableView] selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
}

- (SeafCell *)getEntryCell:(id)entry indexPath:(NSIndexPath **)indexPath
{
    NSUInteger index = [self indexOfEntry:entry];
    if (index == NSNotFound)
        return nil;
    @try {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        if (indexPath) *indexPath = path;
        return (SeafCell *)[[self currentTableView] cellForRowAtIndexPath:path];
    } @catch(NSException *exception) {
        Warning("Something wrong %@", exception);
        return nil;
    }
}

- (void)updateEntryCell:(SeafFile *)entry
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            SeafCell *cell = [self getEntryCell:entry indexPath:nil];
            [self updateCellContent:cell file:entry];
        } @catch(NSException *exception) {
        }
    });
}

#pragma mark - SeafShareDelegate
- (void)generateSharelink:(SeafBase *)entry WithResult:(BOOL)success
{
    SeafBase *base = (SeafBase *)[self getDentrybyIndexPath:_selectedindex tableView:self.tableView];
    if (entry != base) {
        [SVProgressHUD dismiss];
        return;
    }

    if (!success) {
        if ([entry isKindOfClass:[SeafFile class]])
            [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:NSLocalizedString(@"Failed to generate share link of file '%@'", @"Seafile"), entry.name]];
        else
            [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:NSLocalizedString(@"Failed to generate share link of directory '%@'", @"Seafile"), entry.name]];
        return;
    }
    [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"Generate share link success", @"Seafile")];

    if (self.state == STATE_SHARE_EMAIL) {
        [self sendMailInApp:entry];
    } else if (self.state == STATE_SHARE_LINK){
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:entry.shareLink];
    }
}

#pragma mark - sena mail inside app
- (void)sendMailInApp:(SeafBase *)entry
{
    Class mailClass = (NSClassFromString(@"MFMailComposeViewController"));
    if (!mailClass) {
        [self alertWithTitle:NSLocalizedString(@"This function is not supportted yet，you can copy it to the pasteboard and send mail by yourself", @"Seafile")];
        return;
    }
    if (![mailClass canSendMail]) {
        [self alertWithTitle:NSLocalizedString(@"The mail account has not been set yet", @"Seafile")];
        return;
    }

    MFMailComposeViewController *mailPicker = [SeafUI appdelegate].globalMailComposer;
    mailPicker.mailComposeDelegate = self;
    NSString *emailSubject, *emailBody;
    if ([entry isKindOfClass:[SeafFile class]]) {
        emailSubject = [NSString stringWithFormat:NSLocalizedString(@"File '%@' is shared with you using %@", @"Seafile"), entry.name, APP_NAME];
        emailBody = [NSString stringWithFormat:NSLocalizedString(@"Hi,<br/><br/>Here is a link to <b>'%@'</b> in my %@:<br/><br/> <a href=\"%@\">%@</a>\n\n", @"Seafile"), entry.name, APP_NAME, entry.shareLink, entry.shareLink];
    } else {
        emailSubject = [NSString stringWithFormat:NSLocalizedString(@"Directory '%@' is shared with you using %@", @"Seafile"), entry.name, APP_NAME];
        emailBody = [NSString stringWithFormat:NSLocalizedString(@"Hi,<br/><br/>Here is a link to directory <b>'%@'</b> in my %@:<br/><br/> <a href=\"%@\">%@</a>\n\n", @"Seafile"), entry.name, APP_NAME, entry.shareLink, entry.shareLink];
    }
    [mailPicker setSubject:emailSubject];
    [mailPicker setMessageBody:emailBody isHTML:YES];
    [self presentViewController:mailPicker animated:YES completion:nil];
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    NSString *msg;
    switch (result) {
        case MFMailComposeResultCancelled:
            msg = @"cancalled";
            break;
        case MFMailComposeResultSaved:
            msg = @"saved";
            break;
        case MFMailComposeResultSent:
            msg = @"sent";
            break;
        case MFMailComposeResultFailed:
            msg = @"failed";
            break;
        default:
            msg = @"";
            break;
    }
    Debug("share file:send mail %@\n", msg);
    [self dismissViewControllerAnimated:YES completion:^{
        [[SeafUI appdelegate] cycleTheGlobalMailComposer];
    }];
}

#pragma mark - MWPhotoBrowserDelegate
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    if (!self.photos) return 0;
    return self.photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.photos.count) {
        return [self.photos objectAtIndex:index];
    }
    return nil;
}

- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index
{
    if (index < self.photos.count) {
        SeafPhoto *photo = [self.photos objectAtIndex:index];
        return photo.file.name;
    } else {
        Warning("index %lu out of bound %lu, %@", (unsigned long)index, (unsigned long)self.photos.count, self.photos);
        return nil;
    }
}
- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index
{
    if (index < self.thumbs.count)
        return [self.thumbs objectAtIndex:index];
    return nil;
}

- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser
{
    [photoBrowser dismissViewControllerAnimated:YES completion:nil];
    self.inPhotoBrowser = false;
}

- (BOOL)goTo:(NSString *)repo path:(NSString *)path
{
    if (![_directory hasCache] || !self.isVisible)
        return TRUE;
    Debug("repo: %@, path: %@, current: %@", repo, path, _directory.path);
    if ([self.directory isKindOfClass:[SeafRepos class]]) {
        for (int i = 0; i < ((SeafRepos *)_directory).repoGroups.count; ++i) {
            NSArray *repos = [((SeafRepos *)_directory).repoGroups objectAtIndex:i];
            for (int j = 0; j < repos.count; ++j) {
                SeafRepo *r = [repos objectAtIndex:j];
                if ([r.repoId isEqualToString:repo]) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j inSection:i];
                    [self.tableView selectRowAtIndexPath:indexPath animated:true scrollPosition:UITableViewScrollPositionMiddle];
                    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
                    return TRUE;
                }
            }
        }
        Debug("Repo %@ not found.", repo);
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to find library", @"Seafile")];
    } else {
        if ([@"/" isEqualToString:path])
            return FALSE;
        for (int i = 0; i < _directory.allItems.count; ++i) {
            SeafBase *b = [_directory.allItems objectAtIndex:i];
            NSString *p = b.path;
            if ([b isKindOfClass:[SeafDir class]]) {
                p = [p stringByAppendingString:@"/"];
            }
            BOOL found = [p isEqualToString:path];
            if (found || [path hasPrefix:p]) {
                Debug("found=%d, path:%@, p:%@", found, path, p);
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
                [self.tableView selectRowAtIndexPath:indexPath animated:true scrollPosition:UITableViewScrollPositionMiddle];
                [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
                return !found;
            }
        }
        Debug("file %@/%@ not found", repo, path);
        [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:NSLocalizedString(@"Failed to find %@", @"Seafile"), path]];
    }
    return FALSE;
}

@end
