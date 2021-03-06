#import "BTMockApplePayPaymentAuthorizationViewController.h"

#import "BTMockApplePayPaymentAuthorizationView.h"
#import "BTLogger_Internal.h"

@interface BTMockApplePayPaymentAuthorizationViewController () <BTMockApplePayPaymentAuthorizationViewDelegate>

@end

@implementation BTMockApplePayPaymentAuthorizationViewController

- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)request {
    self = [super init];
    if (self) {
        [[BTLogger sharedLogger] debug:@"Initializing BTMockApplePayPaymentAuthorizationViewController with PKRequest merchantIdentifier: %@; items: %@", request.merchantIdentifier, request.paymentSummaryItems ];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    BTMockApplePayPaymentAuthorizationView *authorizationView = [[BTMockApplePayPaymentAuthorizationView alloc] initWithDelegate:self];
    authorizationView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:authorizationView];

    NSDictionary *views = @{ @"authorizationView": authorizationView };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[authorizationView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[authorizationView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
}

+ (BOOL)canMakePayments {
    NSOperatingSystemVersion v;
    v.majorVersion = 8;
    v.minorVersion = 1;
    v.patchVersion = 0;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 8.0, watchOS 2.0, *)) {
#endif
    return [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)] && [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:v];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    }
    return NO;
#endif
}

- (void)cancel:(__unused id)sender {
    [self.delegate mockApplePayPaymentAuthorizationViewControllerDidFinish:self];
}

#pragma mark Mock Payment Authorization View Delegate

- (void)mockApplePayPaymentAuthorizationViewDidCancel:(__unused BTMockApplePayPaymentAuthorizationView *)view {
    [self.delegate mockApplePayPaymentAuthorizationViewControllerDidFinish:self];
}

- (void)mockApplePayPaymentAuthorizationViewDidSucceed:(__unused BTMockApplePayPaymentAuthorizationView *)view NS_AVAILABLE_IOS(8_0) {
    [self.delegate mockApplePayPaymentAuthorizationViewController:self
                                             didAuthorizePayment:nil
                                                      completion:^(__unused PKPaymentAuthorizationStatus status) {
                                                          [self.delegate mockApplePayPaymentAuthorizationViewControllerDidFinish:self];
                                                      }];
}

@end
