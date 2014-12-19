#import "BTThreeDSecureAuthenticationViewController.h"
#import "BTClient+Testing.h"

@interface BTThreeDSecureViewController_AcceptanceSpecHelper : NSObject <BTThreeDSecureAuthenticationViewControllerDelegate>

@property (nonatomic, strong) BTClient *client;
@property (nonatomic, strong) BTThreeDSecureAuthenticationViewController *threeDSecureViewController;
@property (nonatomic, strong) BTThreeDSecureLookupResult *lookup;
@property (nonatomic, copy) NSString *originalNonce;

@property (nonatomic, copy) void (^authenticateBlock)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus));
@property (nonatomic, copy) void (^finishBlock)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController);
@property (nonatomic, copy) void (^failureBlock)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, NSError *error);
@end

@implementation BTThreeDSecureViewController_AcceptanceSpecHelper

+ (instancetype)helper {
    BTThreeDSecureViewController_AcceptanceSpecHelper *helper = [[self alloc] init];
    waitUntil(^(DoneCallback done) {
        [BTClient testClientWithConfiguration:@{ BTClientTestConfigurationKeyMerchantIdentifier:@"integration_merchant_id",
                                                 BTClientTestConfigurationKeyPublicKey:@"integration_public_key",
                                                 BTClientTestConfigurationKeyCustomer:@YES,
                                                 BTClientTestConfigurationKeyClientTokenVersion: @2,
                                                 BTClientTestConfigurationKeyMerchantAccountIdentifier: @"three_d_secure_merchant_account", }
                                   completion:^(BTClient *client) {
                                       helper.client = client;
                                       done();
                                   }];
    });

    return helper;
}

- (void)lookupCard:(NSString *)number completion:(void (^)(BTThreeDSecureLookupResult *, BTCardPaymentMethod *))completion {
    BTClientCardRequest *request = [[BTClientCardRequest alloc] init];
    request.number = number;
    request.expirationMonth = @"12";
    request.expirationYear = @"2020";
    request.shouldValidate = YES;

    [self.client saveCardWithRequest:request
                             success:^(BTPaymentMethod *card) {
                                 NSString *originalNonce = card.nonce;
                                 self.originalNonce = originalNonce;
                                 [self.client lookupNonceForThreeDSecure:originalNonce
                                                       transactionAmount:[NSDecimalNumber decimalNumberWithString:@"1"]
                                                                 success:^(BTThreeDSecureLookupResult *threeDSecureLookup, BTCardPaymentMethod *card) {
                                                                     completion(threeDSecureLookup, card);
                                                                 } failure:^(NSError *error) {
                                                                     completion(nil, nil);
                                                                 }];
                             } failure:^(__unused NSError *error) {
                                 completion(nil, nil);
                             }];
}

- (void)fetchThreeDSecureVerificationInfo:(NSString *)nonce completion:(void (^)(NSDictionary *response))completion {
    [self.client fetchNonceThreeDSecureVerificationInfo:nonce
                                                success:^(NSDictionary *threeDSecureInfo){
                                                    completion(threeDSecureInfo);
                                                } failure:^(__unused NSError *error){
                                                    completion(nil);
                                                }];
}

- (void)lookupNumber:(NSString *)number
               andDo:(void (^)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController))testBlock
     didAuthenticate:(void (^)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus status)))authenticateBlock
             didFail:(void (^)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, NSError *error))failureBlock
           didFinish:(void (^)(BTThreeDSecureAuthenticationViewController *threeDSecureViewController))finishBlock {

    waitUntil(^(DoneCallback done) {
        [self lookupCard:number
              completion:^(BTThreeDSecureLookupResult *threeDSecureLookup, BTCardPaymentMethod *lookupCard){
                  self.lookup = threeDSecureLookup;
                  done();
              }];
    });

    self.threeDSecureViewController = [[BTThreeDSecureAuthenticationViewController alloc] initWithLookup:self.lookup];

    self.authenticateBlock = authenticateBlock;
    self.finishBlock = finishBlock;
    self.failureBlock = failureBlock;

    self.threeDSecureViewController.delegate = self;

    if (testBlock) {
        testBlock(self.threeDSecureViewController);
    }
}

#pragma mark ThreeDSecureViewControllerDelegate

- (void)threeDSecureViewController:(BTThreeDSecureAuthenticationViewController *)viewController
              didAuthenticateCard:(BTCardPaymentMethod *)card
                        completion:(void (^)(BTThreeDSecureViewControllerCompletionStatus))completionBlock {
    if (self.authenticateBlock) {
        self.authenticateBlock(viewController, self.lookup, card, completionBlock);
    } else {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:@"BTThreeDSecureViewController_AcceptanceSpecHelper received an unexpected call to threeDSecureViewController:didAuthenticateNonce:completion:"
                               userInfo:nil] raise];
    }
}

- (void)threeDSecureViewController:(BTThreeDSecureAuthenticationViewController *)viewController didFailWithError:(NSError *)error {
    if (self.failureBlock) {
        self.failureBlock(viewController, error);
    } else {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:@"BTThreeDSecureViewController_AcceptanceSpecHelper received an unexpected call to threeDSecureViewController:didFailWithError:"
                               userInfo:nil] raise];
    }
}

- (void)threeDSecureViewControllerDidFinish:(BTThreeDSecureAuthenticationViewController *)viewController {
    if (self.finishBlock) {
        self.finishBlock(viewController);
    } else {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:@"BTThreeDSecureViewController_AcceptanceSpecHelper received an unexpected call to threeDSecureViewControllerDidFinish:"
                               userInfo:nil] raise];
    }
}

@end

SpecBegin(BTThreeDSecureViewController_Acceptance)

describe(@"3D Secure View Controller", ^{
    __block BTThreeDSecureViewController_AcceptanceSpecHelper *helper;
    beforeEach(^{
        helper = [BTThreeDSecureViewController_AcceptanceSpecHelper helper];
    });

    context(@"developer perspective", ^{
        it(@"fails to load a view controller when lookup fails", ^{
            BTThreeDSecureLookupResult *lookup = nil;
            BTThreeDSecureAuthenticationViewController *threeDSecureViewController = [[BTThreeDSecureAuthenticationViewController alloc] initWithLookup:lookup];

            expect(threeDSecureViewController).to.beNil();
        });

        it(@"fails to load a view controller when lookup does not require a user flow", ^{
            BTThreeDSecureLookupResult *lookup = [[BTThreeDSecureLookupResult alloc] init];
            BTThreeDSecureAuthenticationViewController *threeDSecureViewController = [[BTThreeDSecureAuthenticationViewController alloc] initWithLookup:lookup];

            expect(lookup.requiresUserAuthentication).to.beFalsy();
            expect(threeDSecureViewController).to.beNil();
        });

        it(@"calls didAuthenticate with the upgraded nonce (consuming the original nonce)", ^{
            __block BOOL calledDidAuthenticate = NO;
            [helper lookupNumber:@"4000000000000002"
                           andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                               [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                               [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                               [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                               [tester enterTextIntoCurrentFirstResponder:@"1234"];
                               [tester tapViewWithAccessibilityLabel:@"Submit"];
                           } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus)) {
                               calledDidAuthenticate = YES;
                               expect(card).to.beKindOf([BTCardPaymentMethod class]);
                               expect(card.nonce).to.beANonce();
                           } didFail:nil
                       didFinish:nil];

            [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                KIFTestWaitCondition(calledDidAuthenticate, error, @"Did not call didAuthenticate");
                return KIFTestStepResultSuccess;
            }];
        });

        it(@"calls didFinish after didAuthenticate calls its completion with success", ^{
            __block BOOL calledDidAuthenticate = NO;
            __block BOOL calledDidFinish = NO;
            [helper lookupNumber:@"4000000000000002"
                           andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                               [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                               [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                               [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                               [tester enterTextIntoCurrentFirstResponder:@"1234"];
                               [tester tapViewWithAccessibilityLabel:@"Submit"];
                           } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus)) {
                               calledDidAuthenticate = YES;
                               expect(calledDidFinish).to.beFalsy();
                               completion(BTThreeDSecureViewControllerCompletionStatusSuccess);
                           } didFail:nil
                       didFinish:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                           calledDidFinish = YES;
                           expect(calledDidAuthenticate).to.beTruthy();
                       }];

            [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                KIFTestWaitCondition(calledDidAuthenticate, error, @"Did not call didAuthenticate");
                KIFTestWaitCondition(calledDidFinish, error, @"Did not call didFinish");
                return KIFTestStepResultSuccess;
            }];
        });

        it(@"calls didFail when authentication fails (leaving the original nonce transactable)", ^{
            __block BOOL calledDidFail = NO;
            __block BOOL calledDidFinish = NO;
            [helper lookupNumber:@"4000000000000010"
                           andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                               [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                               [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                               [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                               [tester enterTextIntoCurrentFirstResponder:@"1234"];
                               [tester tapViewWithAccessibilityLabel:@"Submit"];
                           } didAuthenticate:nil
                         didFail:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, NSError *error) {
                             expect(error.domain).to.equal(BTThreeDSecureErrorDomain);
                             expect(error.code).to.equal(BTThreeDSecureFailedAuthenticationErrorCode);
                             calledDidFail = YES;
                         }
                       didFinish:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                           expect(calledDidFail).to.beTruthy();
                           calledDidFinish = YES;
                       }];

            [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                KIFTestWaitCondition(calledDidFail, error, @"Did not call didFail");
                KIFTestWaitCondition(calledDidFinish, error, @"Did not call didFinish");
                return KIFTestStepResultSuccess;
            }];
        });
    });

    describe(@"user flows - (enrolled, authenticated, signature verified)", ^{
        context(@"cardholder enrolled, successful authentication, successful signature verification - Y,Y,Y", ^{
            it(@"successfully authenticates a user when they enter their password", ^{
                __block BOOL checkedNonce = NO;
                [helper lookupNumber:@"4000000000000002"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                                   [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                                   [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                                   [tester enterTextIntoCurrentFirstResponder:@"1234"];
                                   [tester tapViewWithAccessibilityLabel:@"Submit"];
                               } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus)) {
                                   [helper fetchThreeDSecureVerificationInfo:card.nonce
                                                                  completion:^(NSDictionary *response) {
                                                                      expect(response[@"reportStatus"]).to.equal(@"authenticate_successful");
                                                                      checkedNonce = YES;
                                                                  }];
                               } didFail:nil
                           didFinish:nil];

                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(checkedNonce, error, @"Did not check nonce");
                    return KIFTestStepResultSuccess;
                }];
            });
        });

        context(@"issuer not enrolled - N", ^{
            it(@"bypasses the entire authentication experience", ^{
                [helper lookupNumber:@"4000000000000051"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   expect(threeDSecureViewController).to.beNil();
                               } didAuthenticate:nil didFail:nil didFinish:nil];
            });
        });

        context(@"simulated cardinal error on lookup - error", ^{
            it(@"bypasses the entire authentication experience", ^{
                [helper lookupNumber:@"4000000000000077"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   expect(threeDSecureViewController).to.beNil();
                               } didAuthenticate:nil
                             didFail:nil
                           didFinish:nil];
            });
        });

        context(@"User enters incorrect password - Y,N,Y", ^{
            it(@"it presents the failure to the user and fails to authenticate the nonce", ^{
                __block BOOL calledDidFail;
                __block BOOL calledDidFinish;

                [helper lookupNumber:@"4000000000000028"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {

                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];


                                   [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                                   [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];
                                   [tester enterTextIntoCurrentFirstResponder:@"bad"];
                                   [tester tapViewWithAccessibilityLabel:@"Submit"];
                                   [tester waitForViewWithAccessibilityLabel:@"Account Authentication Blocked"];
                                   [tester tapViewWithAccessibilityLabel:@"Continue"];
                               } didAuthenticate:nil
                             didFail:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, NSError *error) {
                                 expect(error.domain).to.equal(BTThreeDSecureErrorDomain);
                                 expect(error.code).to.equal(BTThreeDSecureFailedAuthenticationErrorCode);
                                 expect(error.userInfo[BTThreeDSecureFieldErrorsKey][0][@"message"]).to.equal(@"Failed to authenticate, please try a different form of payment.");
                                 calledDidFail = YES;
                             } didFinish:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                 calledDidFinish = YES;
                             }];

                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(calledDidFail, error, @"Did not call didFail");
                    KIFTestWaitCondition(calledDidFinish, error, @"Did not call didFinish");
                    return KIFTestStepResultSuccess;
                }];
            });
        });

        context(@"User attempted to enter a password - Y,A,Y", ^{
            it(@"displays a loading indication to the user and successfully authenticates the nonce", ^{
                __block BOOL checkedNonce;

                [helper lookupNumber:@"4000000000000101"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];
                               } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus status)) {
                                   [helper fetchThreeDSecureVerificationInfo:card.nonce
                                                                  completion:^(NSDictionary *response) {
                                                                      expect(response[@"reportStatus"]).to.equal(@"authenticate_successful_issuer_not_participating");
                                                                      checkedNonce = YES;
                                                                  }];
                               } didFail:nil
                           didFinish:nil];

                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(checkedNonce, error, @"Did not check nonce");
                    return KIFTestStepResultSuccess;
                }];
            });
        });

        context(@"Signature verification fails - Y,Y,N", ^{
            it(@"accepts a password but resuts in an failed verification", ^{
                __block BOOL calledDidFail = NO;
                __block BOOL calledDidFinish = NO;

                [helper lookupNumber:@"4000000000000010"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                                   [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                                   [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                                   [tester enterTextIntoCurrentFirstResponder:@"1234"];
                                   [tester tapViewWithAccessibilityLabel:@"Submit"];
                               } didAuthenticate:nil
                             didFail:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, NSError *error) {
                                 expect(error.domain).to.equal(BTThreeDSecureErrorDomain);
                                 expect(error.code).to.equal(BTThreeDSecureFailedAuthenticationErrorCode);
                                 expect(error.userInfo[BTThreeDSecureFieldErrorsKey][0][@"message"]).to.equal(@"Failed to authenticate, please try a different form of payment.");
                                 calledDidFail = YES;
                             }
                           didFinish:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                               calledDidFinish = YES;
                           }];

                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(calledDidFail, error, @"Did not call didFail");
                    KIFTestWaitCondition(calledDidFinish, error, @"Did not call didFinish");
                    return KIFTestStepResultSuccess;
                }];
            });
        });

        context(@"issuer is down - Y,U", ^{
            it(@"returns a nonce without asking user for authentication", ^{
                __block BOOL checkedNonce = NO;

                [helper lookupNumber:@"4000000000000036"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                                   [tester waitForViewWithAccessibilityLabel:@"System Error" traits:UIAccessibilityTraitStaticText];
                                   [tester tapViewWithAccessibilityLabel:@"Continue"];
                               } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus)) {
                                   [helper fetchThreeDSecureVerificationInfo:card.nonce completion:^(NSDictionary *response) {
                                       expect(response[@"reportStatus"]).to.equal(@"authenticate_unable_to_authenticate");
                                       checkedNonce = YES;
                                   }];
                               } didFail:nil didFinish:nil];

                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(checkedNonce, error, @"Did not check nonce");
                    return KIFTestStepResultSuccess;
                }];
            });
        });

        context(@"Early termination due to cardinal error - Y, Error", ^{
            it(@"accepts a password but fails to authenticate the nonce", ^{
                __block BOOL checkedNonce = NO;
                [helper lookupNumber:@"4000000000000093"
                               andDo:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController) {
                                   [system presentViewController:threeDSecureViewController withinNavigationControllerWithNavigationBarClass:nil toolbarClass:nil configurationBlock:nil];

                                   [tester waitForViewWithAccessibilityLabel:@"Please submit your Verified by Visa password." traits:UIAccessibilityTraitStaticText];
                                   [tester tapUIWebviewXPathElement:@"//input[@name=\"external.field.password\"]"];

                                   [tester enterTextIntoCurrentFirstResponder:@"1234"];
                                   [tester tapViewWithAccessibilityLabel:@"Submit"];
                               } didAuthenticate:^(BTThreeDSecureAuthenticationViewController *threeDSecureViewController, BTThreeDSecureLookupResult *lookup, BTCardPaymentMethod *card, void (^completion)(BTThreeDSecureViewControllerCompletionStatus)) {
                                   [helper fetchThreeDSecureVerificationInfo:card.nonce
                                                                  completion:^(NSDictionary *response) {
                                                                      expect(response[@"reportStatus"]).to.equal(@"authenticate_signature_verification_failed");
                                                                      checkedNonce = YES;
                                                                  }];
                               } didFail:nil
                           didFinish:nil];
                
                [system runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
                    KIFTestWaitCondition(checkedNonce, error, @"Did not check nonce");
                    return KIFTestStepResultSuccess;
                }];
            });
        });
    });
});

SpecEnd
