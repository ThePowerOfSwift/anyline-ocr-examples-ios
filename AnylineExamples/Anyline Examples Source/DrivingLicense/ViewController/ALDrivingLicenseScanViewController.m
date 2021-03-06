//
//  ALDrivingLicenseScanViewController.m
//  AnylineExamples
//
//  Created by Daniel Albertini on 18.12.17.
//

#import "ALDrivingLicenseScanViewController.h"
#import "ALAppDemoLicenses.h"
#import "ALResultViewController.h"
#import <Anyline/Anyline.h>


// This is the license key for the examples project used to set up Aynline below
NSString * const kDrivingLicenseLicenseKey = kDemoAppLicenseKey;
@interface ALDrivingLicenseScanViewController ()<ALIDPluginDelegate, ALInfoDelegate>
// The Anyline module used to scan machine readable zones
@property (nonatomic, strong) ALIDScanViewPlugin *drivingLicenseScanViewPlugin;
@property (nonatomic, strong) ALIDScanPlugin *drivingLicenseScanPlugin;
@property (nullable, nonatomic, strong) ALScanView *scanView;

@end

@implementation ALDrivingLicenseScanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"Driving License";
    
    // Initializing the module. Its a UIView subclass. We set the frame to fill the whole screen
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame = CGRectMake(frame.origin.x, frame.origin.y + self.navigationController.navigationBar.frame.size.height, frame.size.width, frame.size.height - self.navigationController.navigationBar.frame.size.height);
    
    ALDrivingLicenseConfig *drivingLicenseConfig = [[ALDrivingLicenseConfig alloc] init];
    drivingLicenseConfig.scanMode = ALDrivingLicenseAuto;
    
    NSError *error = nil;
    self.drivingLicenseScanPlugin = [[ALIDScanPlugin alloc] initWithPluginID:@"ModuleID" licenseKey:kDrivingLicenseLicenseKey delegate:self idConfig:drivingLicenseConfig error:&error];
    NSAssert(self.drivingLicenseScanPlugin, @"Setup Error: %@", error.debugDescription);
    [self.drivingLicenseScanPlugin addInfoDelegate:self];
    
    self.drivingLicenseScanViewPlugin = [[ALIDScanViewPlugin alloc] initWithScanPlugin:self.drivingLicenseScanPlugin];
    NSAssert(self.drivingLicenseScanViewPlugin, @"Setup Error: %@", error.debugDescription);
    
    self.scanView = [[ALScanView alloc] initWithFrame:frame scanViewPlugin:self.drivingLicenseScanViewPlugin];
    
    self.scanView.flashButtonConfig.flashAlignment = ALFlashAlignmentTopLeft;
    
    self.controllerType = ALScanHistoryDrivingLicense;
    
    // After setup is complete we add the module to the view of this view controller
    [self.view addSubview:self.scanView];
    [self.view sendSubviewToBack:self.scanView];
    
    //Start Camera:
    [self.scanView startCamera];
    [self startListeningForMotion];
}

/*
 This method will be called once the view controller and its subviews have appeared on screen
 */
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // We use this subroutine to start Anyline. The reason it has its own subroutine is
    // so that we can later use it to restart the scanning process.
    [self startAnyline];
}

/*
 Cancel scanning to allow the module to clean up
 */
- (void)viewWillDisappear:(BOOL)animated {
    [self.drivingLicenseScanViewPlugin stopAndReturnError:nil];
}

/*
 This method is used to tell Anyline to start scanning. It gets called in
 viewDidAppear to start scanning the moment the view appears. Once a result
 is found scanning will stop automatically (you can change this behaviour
 with cancelOnResult:). When the user dismisses self.identificationView this
 method will get called again.
 */
- (void)startAnyline {
    NSError *error;
    BOOL success = [self.drivingLicenseScanViewPlugin startAndReturnError:&error];
    if( !success ) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Start Scanning Error: %@", error.debugDescription);
    }
}


#pragma mark -- AnylineOCRModuleDelegate

/*
 This is the main delegate method Anyline uses to report its results
 */
- (void)anylineIDScanPlugin:(ALIDScanPlugin *)anylineIDScanPlugin
              didFindResult:(ALIDResult *)scanResult {
    [self.drivingLicenseScanViewPlugin stopAndReturnError:nil];
    
    NSMutableString * result = [NSMutableString string];
    [result appendString:[NSString stringWithFormat:@"Document Number: %@\n", [scanResult.result documentNumber]]];
    [result appendString:[NSString stringWithFormat:@"Last Name: %@\n", [scanResult.result surNames]]];
    [result appendString:[NSString stringWithFormat:@"First Name: %@\n", [scanResult.result givenNames]]];
    [result appendString:[NSString stringWithFormat:@"Date of Birth: %@", [scanResult.result dayOfBirth]]];
    ;
    [super anylineDidFindResult:result barcodeResult:@"" image:scanResult.image scanPlugin:anylineIDScanPlugin viewPlugin:self.drivingLicenseScanViewPlugin completion:^{
        
        NSMutableArray <ALResultEntry*> *resultData = [[NSMutableArray alloc] init];

        [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Last Name" value:[scanResult.result surNames]]];
        [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"First Name" value:[scanResult.result givenNames]]];
        [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Date of Birth" value:[scanResult.result dayOfBirth]]];
        [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Document Number" value:[scanResult.result documentNumber]]];
       
        if ([scanResult.result placeOfBirth]) {
            [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Place of Birth" value:[scanResult.result placeOfBirth]]];
        }
        if ([scanResult.result issuingDate]) {
            [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Issuing Date" value:[scanResult.result issuingDate]]];
        }
        if ([(ALDrivingLicenseIdentification *)scanResult.result expirationDate]) {
            [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Expiration Date" value:[(ALDrivingLicenseIdentification *)scanResult.result expirationDate]]];
        }
        if ([scanResult.result authority]) {
            [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Authority" value:[scanResult.result authority]]];
        }
        if ([(ALDrivingLicenseIdentification *)scanResult.result categories]) {
            [resultData addObject:[[ALResultEntry alloc] initWithTitle:@"Categories" value:[(ALDrivingLicenseIdentification *)scanResult.result categories]]];
        }

        //Display the result
        ALResultViewController *vc = [[ALResultViewController alloc] initWithResultData:resultData image:scanResult.image optionalImageTitle:@"Detected Face Image" optionalImage:[scanResult.result faceImage]];
        
        [self.navigationController pushViewController:vc animated:YES];
    }];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSError *error = nil;
    BOOL success = [self.drivingLicenseScanViewPlugin startAndReturnError:&error];
    
    NSAssert(success, @"We failed starting: %@",error.debugDescription);
}

@end
