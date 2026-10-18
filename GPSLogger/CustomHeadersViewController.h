//
//  CustomHeadersViewController.h
//  GPSLogger
//

#import <UIKit/UIKit.h>

@interface CustomHeadersViewController : UITableViewController

// Headers to start editing with, as an array of @{@"key": ..., @"value": ...} dictionaries
@property (nonatomic, copy) NSArray *initialHeaders;

// Called with the edited headers when this screen is dismissed. Nothing is saved here;
// the caller decides when to persist them.
@property (nonatomic, copy) void (^completionHandler)(NSArray *headers);

@end
