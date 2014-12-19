#import "BTThreeDSecure.h"

#import "BTThreeDSecureAuthenticationViewController.h"

@interface BTThreeDSecure () <BTThreeDSecureAuthenticationViewControllerDelegate>
@property (nonatomic, strong) BTClient *client;
@property (nonatomic, strong) BTCardPaymentMethod *upgradedPaymentMethod;
@end

@implementation BTThreeDSecure

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"init is not available for BTThreeDSecure, please use initWithClient" userInfo:nil];
    return [self initWithClient:nil delegate:nil];
}

- (instancetype)initWithClient:(BTClient *)client delegate:(id<BTPaymentMethodCreationDelegate>)delegate {
    if (client == nil || delegate == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.client = client;
        self.delegate = delegate;
    }
    return self;
}

- (void)verifyCardWithNonce:(NSString *)nonce amount:(NSDecimalNumber *)amount {
    NSAssert(self.delegate, @"BTThreeDSecure must have a delegate before verifying a card (delegate is nil)");

    [self.client lookupNonceForThreeDSecure:nonce
                          transactionAmount:amount
                                    success:^(BTThreeDSecureLookupResult *threeDSecureLookup, BTCardPaymentMethod *card) {
                                        NSAssert(threeDSecureLookup.requiresUserAuthentication == (card == nil) , @"BTThreeDSecure verifyCardWithNonce Expect to receive either a lookup result or a nonce. Received neither or both.");
                                        if (card) {
                                            [self informDelegateDidCreatePaymentMethod:card];
                                        } else {
                                            BTThreeDSecureAuthenticationViewController *authenticationViewController = [[BTThreeDSecureAuthenticationViewController alloc] initWithLookup:threeDSecureLookup];
                                            authenticationViewController.delegate = self;
                                            [self informDelegateRequestsPresentationOfViewController:authenticationViewController];
                                        }
                                    }
                                    failure:^(NSError *error) {
                                        [self informDelegateDidFailWithError:error];
                                    }];
}

- (void)verifyCard:(BTCardPaymentMethod *)card amount:(NSDecimalNumber *)amount {
    [self verifyCardWithNonce:card.nonce amount:amount];
}

- (void)verifyCardWithDetails:(BTClientCardRequest *)details amount:(NSDecimalNumber *)amount {
    [self.client saveCardWithRequest:details
                             success:^(BTCardPaymentMethod *card) {
                                 [self verifyCard:card amount:amount];
                             } failure:^(NSError *error) {
                                 [self informDelegateDidFailWithError:error];
                             }];
}

#pragma mark BTThreeDSecureAuthenticationViewControllerDelegate

- (void)threeDSecureViewController:(__unused BTThreeDSecureAuthenticationViewController *)viewController
              didAuthenticateCard:(BTCardPaymentMethod *)card
                        completion:(void (^)(BTThreeDSecureViewControllerCompletionStatus))completionBlock {
    self.upgradedPaymentMethod = card;
    completionBlock(BTThreeDSecureViewControllerCompletionStatusSuccess);
}

- (void)threeDSecureViewController:(__unused BTThreeDSecureAuthenticationViewController *)viewController
                  didFailWithError:(NSError *)error {
    self.upgradedPaymentMethod = nil;
    [self informDelegateDidFailWithError:error];
}

- (void)threeDSecureViewControllerDidFinish:(BTThreeDSecureAuthenticationViewController *)viewController {
    if (self.upgradedPaymentMethod) {
        [self informDelegateDidCreatePaymentMethod:self.upgradedPaymentMethod];
        [self informDelegateRequestsDismissalOfAuthorizationViewController:viewController];
    }
}

#pragma mark - Delegate Informers

- (void)informDelegateWillPerformAppSwitch {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreatorWillPerformAppSwitch:)]) {
        [self.delegate paymentMethodCreatorWillPerformAppSwitch:self];
    }
}

- (void)informDelegateWillProcess {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreatorWillProcess:)]) {
        [self.delegate paymentMethodCreatorWillProcess:self];
    }
}

- (void)informDelegateRequestsPresentationOfViewController:(UIViewController *)viewController {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreator:requestsPresentationOfViewController:)]) {
        [self.delegate paymentMethodCreator:self requestsPresentationOfViewController:viewController];
    }
}

- (void)informDelegateRequestsDismissalOfAuthorizationViewController:(UIViewController *)viewController {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreator:requestsDismissalOfViewController:)]) {
        [self.delegate paymentMethodCreator:self requestsDismissalOfViewController:viewController];
    }
}

- (void)informDelegateDidCreatePaymentMethod:(BTPaymentMethod *)paymentMethod {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreator:didCreatePaymentMethod:)]) {
        [self.delegate paymentMethodCreator:self didCreatePaymentMethod:paymentMethod];
    }
}

- (void)informDelegateDidFailWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreator:didFailWithError:)]) {
        [self.delegate paymentMethodCreator:self didFailWithError:error];
    }
}

- (void)informDelegateDidCancel {
    if ([self.delegate respondsToSelector:@selector(paymentMethodCreatorDidCancel:)]) {
        [self.delegate paymentMethodCreatorDidCancel:self];
    }
}

@end
