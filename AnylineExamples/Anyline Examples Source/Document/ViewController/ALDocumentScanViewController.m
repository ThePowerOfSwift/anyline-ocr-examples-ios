
#import "ALDocumentScanViewController.h"
#import <Anyline/Anyline.h>
#import "NSUserDefaults+ALExamplesAdditions.h"
#import "ALRoundedView.h"
#import "ALAppDemoLicenses.h"

NSString * const kDocumentScanLicenseKey = kDemoAppLicenseKey;

@class AnylineDocumentModuleView;

@interface ALDocumentScanViewController () <ALDocumentScanPluginDelegate, ALInfoDelegate, ALDocumentInfoDelegate>

// The Anyline plugin used for Document
@property (nonatomic, strong) ALDocumentScanViewPlugin *documentScanViewPlugin;
@property (nonatomic, strong) ALDocumentScanPlugin *documentScanPlugin;
@property (nullable, nonatomic, strong) ALScanView *scanView;

@property (nonatomic, strong) ALRoundedView *roundedView;
@property (nonatomic, assign) NSInteger showingLabel;

@end

@implementation ALDocumentScanViewController

/*
 We will do our main setup in viewDidLoad. Its called once the view controller is getting ready to be displayed.
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
   
    [super viewDidLoad];
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
    self.title = NSLocalizedString(@"Scan Document", @"Scan Document");
    // Initializing the module. Its a UIView subclass. We set the frame to fill the whole screen
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame = CGRectMake(frame.origin.x, frame.origin.y + self.navigationController.navigationBar.frame.size.height, frame.size.width, frame.size.height - self.navigationController.navigationBar.frame.size.height);

    NSError *error = nil;
    
    self.documentScanPlugin = [[ALDocumentScanPlugin alloc] initWithPluginID:@"DOCUMENT" licenseKey:kDocumentScanLicenseKey delegate:self error:&error];;
    NSAssert(self.documentScanPlugin, @"Setup Error: %@", error.debugDescription);
    self.documentScanPlugin.justDetectCornersIfPossible = NO;
    [self.documentScanPlugin addInfoDelegate:self];
    
    self.documentScanViewPlugin = [[ALDocumentScanViewPlugin alloc] initWithScanPlugin:self.documentScanPlugin];
    NSAssert(self.documentScanViewPlugin, @"Setup Error: %@", error.debugDescription);
    
    [self.documentScanViewPlugin setValue:self forKey:@"tmpOutlineDelegate"];
    self.scanView = [[ALScanView alloc] initWithFrame:frame
                                       scanViewPlugin:self.documentScanViewPlugin
                                         cameraConfig:[ALCameraConfig defaultDocumentCameraConfig]
                                    flashButtonConfig:[ALFlashButtonConfig defaultFlashConfig]];
    
    // Stop scanning after a result has been found
    //    self.documentScanViewPlugin
    [self.documentScanPlugin setPostProcessingEnabled:YES];
    
    [self.documentScanPlugin enableReporting:[NSUserDefaults AL_reportingEnabled]];
    self.controllerType = ALScanHistoryDocument;
    self.documentScanViewPlugin.translatesAutoresizingMaskIntoConstraints = NO;
    
    // After setup is complete we add the module to the view of this view controller
    [self.view addSubview:self.scanView];
    [self.view sendSubviewToBack:self.scanView];
    
    //Start Camera:
    [self.scanView startCamera];
    [self startListeningForMotion];

    // This view notifies the user of any problems that occur while he is scanning
    self.roundedView = [[ALRoundedView alloc] initWithFrame:CGRectMake(20, 115, self.view.bounds.size.width - 40, 30)];
    self.roundedView.fillColor = [UIColor colorWithRed:98.0/255.0 green:39.0/255.0 blue:232.0/255.0 alpha:0.6];
    self.roundedView.textLabel.text = @"";
    self.roundedView.alpha = 0;
    [self.view addSubview:self.roundedView];
}

/*
 This method will be called once the view controller and its subviews have appeared on screen
 */
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /*
     This is the place where we tell Anyline to start receiving and displaying images from the camera.
     Success/error tells us if everything went fine.
     */
    NSError *error;
    BOOL success = [self.documentScanViewPlugin startAndReturnError:&error];
    if( !success ) {
        // Something went wrong. The error object contains the error description
        [[[UIAlertView alloc] initWithTitle:@"Start Scanning Error"
                                    message:error.debugDescription
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
    
    //Update Position of Warning Indicator
    [self updateWarningPosition:
     self.documentScanViewPlugin.cutoutRect.origin.y +
     self.documentScanViewPlugin.cutoutRect.size.height +
     self.documentScanViewPlugin.frame.origin.y - 100];
}

/*
 Cancel scanning to allow the module to clean up
 */
- (void)viewWillDisappear:(BOOL)animated {
    [self.documentScanViewPlugin stopAndReturnError:nil];
}

#pragma mark -- AnylineDocumentModuleDelegate

/*
 This is the main delegate method Anyline uses to report its scanned codes
 */
- (void)anylineDocumentScanPlugin:(ALDocumentScanPlugin *)anylineDocumentScanPlugin
                        hasResult:(UIImage *)transformedImage
                        fullImage:(UIImage *)fullFrame
                  documentCorners:(ALSquare *)corners {
    UIViewController *viewController = [[UIViewController alloc] init];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:viewController.view.bounds];
    imageView.center = CGPointMake(imageView.center.x, imageView.center.y + 30);
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = transformedImage;
    [viewController.view addSubview:imageView];
    [self.navigationController pushViewController:viewController animated:YES];
}

/*
 This method receives errors that occured during the scan.
 */
- (void)anylineDocumentScanPlugin:(ALDocumentScanPlugin *)anylineDocumentScanPlugin
  reportsPictureProcessingFailure:(ALDocumentError)error {
    [self showUserLabel:error];
}

/*
 This method receives errors that occured during the scan.
 */
- (void)anylineDocumentScanPlugin:(ALDocumentScanPlugin *)anylineDocumentScanPlugin
  reportsPreviewProcessingFailure:(ALDocumentError)error {
    [self showUserLabel:error];
}

#pragma mark -- Helper Methods

/*
 Shows a little round label at the bottom of the screen to inform the user what happended
 */
- (void)showUserLabel:(ALDocumentError)error {
    NSString *helpString = nil;
    switch (error) {
        case ALDocumentErrorNotSharp:
            helpString = @"Document not Sharp";
            break;
        case ALDocumentErrorSkewTooHigh:
            helpString = @"Wrong Perspective";
            break;
        case ALDocumentErrorImageTooDark:
            helpString = @"Too Dark";
            break;
        case ALDocumentErrorShakeDetected:
            helpString = @"Shake";
            break;
        default:
            break;
    }
    
    // The error is not in the list above or a label is on screen at the moment
    if(!helpString || self.showingLabel == 1) {
        return;
    }
    
    self.showingLabel = 1;
    self.roundedView.textLabel.text = helpString;
    
    
    // Animate the appearance of the label
    CGFloat fadeDuration = 0.8;
    [UIView animateWithDuration:fadeDuration animations:^{
        self.roundedView.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:fadeDuration animations:^{
            self.roundedView.alpha = 0;
        } completion:^(BOOL finished) {
            self.showingLabel = 0;
        }];
    }];
}

@end
