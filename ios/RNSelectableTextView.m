#if __has_include(<RCTText/RCTTextSelection.h>)
#import <RCTText/RCTTextSelection.h>
#else
#import "RCTTextSelection.h"
#endif

#if __has_include(<RCTText/RCTUITextView.h>)
#import <RCTText/RCTUITextView.h>
#else
#import "RCTUITextView.h"
#endif

#import "RNSelectableTextView.h"

#if __has_include(<RCTText/RCTTextAttributes.h>)
#import <RCTText/RCTTextAttributes.h>
#else
#import "RCTTextAttributes.h"
#endif

#import <React/RCTUtils.h>

@implementation RNSelectableTextView
{
    RCTUITextView *_backedTextInputView;
    // array of urls and associated positions
    NSMutableArray <NSDictionary*> *urlAndRange;
}

NSString *const RNST_CUSTOM_SELECTOR = @"_CUSTOM_SELECTOR_";

UITextPosition *selectionStart;
UITextPosition* beginning;

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
    if (self = [super initWithBridge:bridge]) {

        _backedTextInputView = [[RCTUITextView alloc] initWithFrame:self.bounds];
        _backedTextInputView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backedTextInputView.backgroundColor = [UIColor clearColor];
        _backedTextInputView.textColor = [UIColor blackColor];
        // This line actually removes 5pt (default value) left and right padding in UITextView.
        _backedTextInputView.textContainer.lineFragmentPadding = 0;
#if !TARGET_OS_TV
        _backedTextInputView.scrollsToTop = NO;
#endif
        _backedTextInputView.scrollEnabled = NO;
        _backedTextInputView.textInputDelegate = self;
        _backedTextInputView.editable = NO;
        _backedTextInputView.selectable = YES;
        _backedTextInputView.contextMenuHidden = YES;
        
        beginning = _backedTextInputView.beginningOfDocument;
        
        for (UIGestureRecognizer *gesture in [_backedTextInputView gestureRecognizers]) {
            if (
                [gesture isKindOfClass:[UIPanGestureRecognizer class]]
                ) {
                [_backedTextInputView setExclusiveTouch:NO];
                gesture.enabled = YES;
            } else {
                gesture.enabled = NO;
            }
        }
        
        [self addSubview:_backedTextInputView];
        
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        
        UITapGestureRecognizer *tapGesture = [ [UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tapGesture.numberOfTapsRequired = 2;
        
        UITapGestureRecognizer *singleTapGesture = [ [UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
        singleTapGesture.numberOfTapsRequired = 1;
        
        [_backedTextInputView addGestureRecognizer:longPressGesture];
        [_backedTextInputView addGestureRecognizer:tapGesture];
        [_backedTextInputView addGestureRecognizer:singleTapGesture];
        
        [self setUserInteractionEnabled:YES];
    }
    
    return self;
}

-(void) _handleGesture
{
    if (!_backedTextInputView.isFirstResponder) {
        [_backedTextInputView becomeFirstResponder];
    }
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    
    if (menuController.isMenuVisible) return;
    
    NSMutableArray *menuControllerItems = [NSMutableArray arrayWithCapacity:self.menuItems.count];
    
    for(NSString *menuItemName in self.menuItems) {
        NSString *sel = [NSString stringWithFormat:@"%@%@", RNST_CUSTOM_SELECTOR, menuItemName];
        UIMenuItem *item = [[UIMenuItem alloc] initWithTitle: menuItemName
                                                      action: NSSelectorFromString(sel)];
        
        [menuControllerItems addObject: item];
    }
    
    menuController.menuItems = menuControllerItems;
    [menuController setTargetRect:self.bounds inView:self];
    [menuController setMenuVisible:YES animated:YES];
}

-(void) handleSingleTap: (UITapGestureRecognizer *) gesture
{
    CGPoint pos = [gesture locationInView:_backedTextInputView];
    pos.y += _backedTextInputView.contentOffset.y;
    
    UITextPosition *tapPos = [_backedTextInputView closestPositionToPoint:pos];
    UITextRange *word = [_backedTextInputView.tokenizer rangeEnclosingPosition:tapPos withGranularity:(UITextGranularityWord) inDirection:UITextLayoutDirectionRight];
    
    UITextPosition* beginning = _backedTextInputView.beginningOfDocument;
    
    UITextPosition *selectionStart = word.start;
    UITextPosition *selectionEnd = word.end;
    
    const NSInteger location = [_backedTextInputView offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger endLocation = [_backedTextInputView offsetFromPosition:beginning toPosition:selectionEnd];
    
    const NSInteger tapLocation = [_backedTextInputView offsetFromPosition:beginning toPosition:tapPos];
    NSString* url;
    NSUInteger urlAssociatedLocation, urlAssociatedLength;
    
    
    for (NSDictionary* item in urlAndRange){
        urlAssociatedLocation = [[item objectForKey:@"location"] unsignedIntValue] ;
        urlAssociatedLength =  [[item objectForKey:@"length"] unsignedIntValue] ;
        url = [item objectForKey:@"url"];
        if(urlAssociatedLocation <= tapLocation && tapLocation <= urlAssociatedLocation + urlAssociatedLength ){
            // open the link with custom function from JS, if the prop is provided
            if(_onLinkPress && ![_onLinkPress isKindOfClass:[NSNull class]] ){
                _onLinkPress(@{@"link": url});
            }
            else{
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
        }
    }
    
    self.onHighlightPress(@{
        @"clickedRangeStart": @(location),
        @"clickedRangeEnd": @(endLocation),
                          });
}

-(void) handleLongPress: (UILongPressGestureRecognizer *) gesture
{
    
    CGPoint pos = [gesture locationInView:_backedTextInputView];
    pos.y += _backedTextInputView.contentOffset.y;
    
    UITextPosition *tapPos = [_backedTextInputView closestPositionToPoint:pos];
    UITextRange *word = [_backedTextInputView.tokenizer rangeEnclosingPosition:tapPos withGranularity:(UITextGranularityWord) inDirection:UITextLayoutDirectionRight];
    
    switch ([gesture state]) {
        case UIGestureRecognizerStateBegan:
            selectionStart = word.start;
            break;
        case UIGestureRecognizerStateChanged:
            break;
        case UIGestureRecognizerStateEnded:
            selectionStart = nil;
            [self _handleGesture];
            return;
        default:
            break;
    }
    
    UITextPosition *selectionEnd = word.end;
    
    const NSInteger location = [_backedTextInputView offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger endLocation = [_backedTextInputView offsetFromPosition:beginning toPosition:selectionEnd];
    
    if ((location == 0 && endLocation == 0) || (location > endLocation - location)) return;
    
    [_backedTextInputView select:self];
    [_backedTextInputView setSelectedRange:NSMakeRange(location, endLocation - location)];
    
}

-(void) handleTap: (UITapGestureRecognizer *) gesture
{
    [_backedTextInputView select:self];
    [_backedTextInputView selectAll:self];
    [self _handleGesture];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    if (self.value) {
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:self.value attributes:self.textAttributes.effectiveTextAttributes];
        
        [super setAttributedText:str];
    } else {
        [super setAttributedText:attributedText];
    }
    
    // don't re-calculate the array if elements exist
    if(urlAndRange.count > 0){
        return;
    }

    NSMutableAttributedString *res = [attributedText mutableCopy];

    [res beginEditing];
    __block CGFloat *colors;

    // init the array
    urlAndRange = [NSMutableArray array];

    // for each font-color found in the attributed string
    [res enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, res.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        // if a font-color was found in the attributed string
        if (value) {
            UIColor *oldColor = (UIColor *)value;
            colors = CGColorGetComponents(oldColor.CGColor);
            
            // the red component of a link text color is 0.4 and 0.72 depending of the theme
            // regular text has values around 0.12 on light and 1 on dark
            if (colors[0] > 0.4 && colors[0] < 0.8) {
                // make sure the linksArray won't be out of range
                if (self.linksArray.count > urlAndRange.count) {
                    NSDictionary* itemToBeAdded = @{
                        @"url": self.linksArray[urlAndRange.count],
                        @"location": [NSString stringWithFormat:@"%lu",range.location],
                        @"length": [NSString stringWithFormat: @"%lu", range.length],
                    };
                    [urlAndRange addObject:itemToBeAdded];
                }
            }
            
        }
    }];
    [res endEditing];
    
}

- (id<RCTBackedTextInputViewProtocol>)backedTextInputView
{
    return _backedTextInputView;
}

- (void)tappedMenuItem:(NSString *)eventType
{
    RCTTextSelection *selection = self.selection;
    
    NSUInteger start = selection.start;
    NSUInteger end = selection.end - selection.start;
    
    self.onSelection(@{
        @"content": [[self.attributedText string] substringWithRange:NSMakeRange(start, end)],
        @"eventType": eventType,
        @"selectionStart": @(start),
        @"selectionEnd": @(selection.end)
                     });
    
    [_backedTextInputView setSelectedTextRange:nil notifyDelegate:false];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    if ([super methodSignatureForSelector:sel]) {
        return [super methodSignatureForSelector:sel];
    }
    return [super methodSignatureForSelector:@selector(tappedMenuItem:)];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    NSString *sel = NSStringFromSelector([invocation selector]);
    NSRange match = [sel rangeOfString:RNST_CUSTOM_SELECTOR];
    if (match.location == 0) {
        [self tappedMenuItem:[sel substringFromIndex:17]];
    } else {
        [super forwardInvocation:invocation];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if(selectionStart != nil) {return NO;}
    NSString *sel = NSStringFromSelector(action);
    NSRange match = [sel rangeOfString:RNST_CUSTOM_SELECTOR];
    
    if (match.location == 0) {
        return YES;
    }
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!_backedTextInputView.isFirstResponder) {
        [_backedTextInputView setSelectedTextRange:nil notifyDelegate:true];
    } else {
        UIView *sub = nil;
        for (UIView *subview in self.subviews.reverseObjectEnumerator) {
            CGPoint subPoint = [subview convertPoint:point toView:self];
            UIView *result = [subview hitTest:subPoint withEvent:event];
            
            if (!result.isFirstResponder) {
                NSString *name = NSStringFromClass([result class]);
                
                if ([name isEqual:@"UITextRangeView"]) {
                    sub = result;
                }
            }
        }
        
        if (sub == nil) {
            [_backedTextInputView setSelectedTextRange:nil notifyDelegate:true];
        }
    }
    
    return [super hitTest:point withEvent:event];
}

@end
