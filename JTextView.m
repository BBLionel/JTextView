//
//  JTextView.m
//  JKit
//
//  Created by Jeremy Tregunna on 10-10-24.
//  Copyright (c) 2010 Jeremy Tregunna. All rights reserved.
//

#import <CoreText/CoreText.h>
#import "JTextView.h"


static CGFloat const kJTextViewPaddingSize = 2.0f;

static NSString* const kJTextViewDataDetectorLinkKey = @"kJTextViewDataDetectorLinkKey";
static NSString* const kJTextViewDataDetectorPhoneNumberKey = @"kJTextViewDataDetectorPhoneNumberKey";
static NSString* const kJTextViewDataDetectorDateKey = @"kJTextViewDataDetectorDateKey";
static NSString* const kJTextViewDataDetectorAddressKey = @"kJTextViewDataDetectorAddressKey";
static NSString* const kJTextViewLinkAttributeName = @"kJTextViewLinkAttributeName";

@interface JTextView (PrivateMethods)

- (void)dataDetectorPassInRange:(NSRange)range;
- (void)dataDetectorPassInRange:(NSRange)range withAttributedString:(NSMutableAttributedString *)attributedString;

- (void)receivedTap:(UITapGestureRecognizer*)recognizer;
- (void)setup;

- (void)setGraphicsContext:(CGContextRef)context;

@end

@interface JTextView () <UIGestureRecognizerDelegate>

@property (nonatomic, copy) dispatch_block_t tapRecognizedBlock;

@end


@implementation JTextView {
    BOOL _maximumTextSizeChanged;
}

@synthesize tapRecognizedBlock = _tapRecognizedBlock;

@synthesize attributedText = _textStore;
@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize editable = _editable;
@synthesize dataDetectorTypes = _dataDetectorTypes;
@synthesize textViewDelegate = _textViewDelegate;
@synthesize text = _text;

@synthesize linkColor = _linkColor;
@synthesize shouldUnderlineLinks = _shouldUnderlineLinks;
@synthesize maximumTextSize = _maximumTextSize;


#pragma mark -
#pragma mark Object creation and destruction

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame]))
    {
        [self setup];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self setup];
    }
    
    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor whiteColor];
    _textStore = [[NSMutableAttributedString alloc] init];
    _textColor = [UIColor blackColor];
    _font = [[UIFont systemFontOfSize:[UIFont systemFontSize]] retain];
    _editable = NO;
    _dataDetectorTypes = UIDataDetectorTypeNone;
    caret = [[JTextCaret alloc] initWithFrame:CGRectZero];
    
    _maximumTextSize = self.bounds.size;
    
    UITapGestureRecognizer* tap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(receivedTap:)] autorelease];
    tap.delegate = self;
    
    [self addGestureRecognizer:tap];
}

- (void)dealloc
{
    if(textFrame != NULL)
    {
        CFRelease(textFrame);
    }
    
    if(_graphicsContext != NULL)
    {
        CGContextRelease(_graphicsContext);
        _graphicsContext = NULL;
    }
    
    if(_tapRecognizedBlock != nil) {
        Block_release(_tapRecognizedBlock);
        _tapRecognizedBlock = nil;
    }
    
    [_linkColor release], _linkColor = nil;
	[_font release], _font = nil;
	[_textStore release], _textStore = nil;
    [caret release], caret = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Responder chain


- (BOOL)canBecomeFirstResponder
{
	return self.editable;
}

#pragma mark -
#pragma mark Setters

- (void)setGraphicsContext:(CGContextRef)context
{
    if(context != NULL && context != _graphicsContext)
    {
        if(_graphicsContext != NULL)
        {
            CGContextRelease(_graphicsContext);
        }
        
        _graphicsContext = CGContextRetain(context);
    }
}

-(void)setFrame:(CGRect)frame {
    if(!CGRectEqualToRect(frame, self.frame)) {
        if(!_maximumTextSizeChanged) {
            _maximumTextSize = frame.size;
        }
        
        [super setFrame:frame];
    }
}

- (void)setMaximumTextSize:(CGSize)maximumTextSize {
    if(!CGSizeEqualToSize(_maximumTextSize, maximumTextSize)) {
        _maximumTextSize = maximumTextSize;        
        _maximumTextSizeChanged = YES;
        
        [self setNeedsDisplay];
    }
}

#pragma mark -
#pragma mark Text drawing

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
    [self setGraphicsContext:context];
    
    NSMutableAttributedString *textStringToDraw = [self.attributedText mutableCopy];
    
	[self.backgroundColor set];
	CGContextFillRect(context, rect);
    
    CGFloat width = CGRectGetWidth(rect);
    
    CGSize textSize = [textStringToDraw.string sizeWithFont:self.font
                                          constrainedToSize:self.maximumTextSize
                                              lineBreakMode:UILineBreakModeWordWrap];
	NSRange textRange = NSMakeRange(0, textStringToDraw.length);
	
	CTFontRef font = CTFontCreateWithName((CFStringRef)self.font.fontName, self.font.pointSize, NULL);
	[textStringToDraw addAttribute:(NSString*)kCTFontAttributeName value:(id)font range:textRange];
    
    if(font != NULL)
    {
        CFRelease(font);
    }
    
    [textStringToDraw addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)_textColor range:textRange];
	
	if(!self.editable)
		[self dataDetectorPassInRange:textRange withAttributedString:textStringToDraw];
	    
    CGContextTranslateCTM(context, 0, textSize.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0, 1.0));
	
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)textStringToDraw);
    
    if(textFrame != NULL) 
    {
        CFRelease(textFrame);
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, width, textSize.height));

	textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    
    if(framesetter != NULL)
    {
        CFRelease(framesetter);
    }
	
    [_textStore setAttributedString:textStringToDraw];
    
	CTFrameDraw(textFrame, context);
}


#pragma mark -
#pragma mark UIKeyInput delegate methods


- (BOOL)hasText
{
    if(self.attributedText.length > 0)
        return YES;
    return NO;
}

- (NSString *)text {
    return [self.attributedText string];
}

- (void)setText:(NSString *)text {
    if(![text isEqualToString:[self.attributedText string]]) {
        self.attributedText = [[[NSMutableAttributedString alloc] initWithString:text] autorelease];
        [self setNeedsDisplay];
    }
}

- (void)insertText:(NSString*)aString
{
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:aString];
    [self.attributedText appendAttributedString:attributedString];
    [attributedString release];
    [self setNeedsDisplay];
}


- (void)deleteBackward
{
	if(self.attributedText.length != 0)
	{
		NSRange range = NSMakeRange(self.attributedText.length - 1, 1);
		[self.attributedText deleteCharactersInRange:range];
		[self setNeedsDisplay];
	}
}


#pragma mark -
#pragma mark Data detectors

- (void)dataDetectorPassInRange:(NSRange)range 
{
    [self dataDetectorPassInRange:range withAttributedString:self.attributedText];
}

- (void)dataDetectorPassInRange:(NSRange)range withAttributedString:(NSMutableAttributedString *)attributedString
{
	if (self.dataDetectorTypes == UIDataDetectorTypeNone)
		return;

	NSError* error = NULL;
	NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                               error:&error];
	NSAssert(error == nil, @"Problem creating the link detector: %@", [error localizedDescription]);
	NSString* string = [attributedString string];
	
	[detector enumerateMatchesInString:string options:0 range:range usingBlock:^(NSTextCheckingResult* match, NSMatchingFlags flags, BOOL* stop){
		NSRange matchRange = [match range];
		// No way to call into Calendar, so don't detect dates
		if([match resultType] != NSTextCheckingTypeDate)
		{
            UIColor *linkColor = (_linkColor != nil) ? _linkColor : [UIColor blueColor];
            //This sentinel attribute will tell us that this is a link.
            [attributedString addAttribute:kJTextViewLinkAttributeName 
                                     value:[NSNull null]
                                     range:matchRange];

			[attributedString addAttribute:(NSString*)kCTForegroundColorAttributeName 
                                     value:(id)linkColor.CGColor
                                     range:matchRange];
            
            if(_shouldUnderlineLinks) {
                [attributedString addAttribute:(NSString*)kCTUnderlineStyleAttributeName 
                                         value:[NSNumber numberWithInt:kCTUnderlineStyleSingle] 
                                         range:matchRange];
            }
		}
		switch([match resultType])
		{
			case NSTextCheckingTypeLink:
			{
				NSURL* url = [match URL];
				if([self.textViewDelegate respondsToSelector:@selector(jTextView:didReceiveURL:range:)])
					[self.textViewDelegate jTextView:self didReceiveURL:url range:matchRange];
				else
					[attributedString addAttribute:kJTextViewDataDetectorLinkKey value:url range:matchRange];
				break;
			}
			case NSTextCheckingTypePhoneNumber:
			{
				NSString* phoneNumber = [match phoneNumber];
				if([self.textViewDelegate respondsToSelector:@selector(jTextView:didReceivePhoneNumber:range:)])
					[self.textViewDelegate jTextView:self didReceivePhoneNumber:phoneNumber range:matchRange];
				else
					[attributedString addAttribute:kJTextViewDataDetectorPhoneNumberKey value:phoneNumber range:matchRange];
				break;
			}
			case NSTextCheckingTypeAddress:
			{
				NSDictionary* addressComponents = [match addressComponents];
				if([self.textViewDelegate respondsToSelector:@selector(jTextView:didReceiveAddress:range:)])
					[self.textViewDelegate jTextView:self didReceiveAddress:addressComponents range:matchRange];
				else
					[attributedString addAttribute:kJTextViewDataDetectorAddressKey value:addressComponents range:matchRange];
				break;
			}
			case NSTextCheckingTypeDate:
			{
				//NSDate* date = [match date];
				//[self.attributedText addAttribute:kJTextViewDataDetectorDateKey value:date range:matchRange];
				break;
			}
		}
	}];
}

#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    self.tapRecognizedBlock = nil;
    
	CGPoint point = [touch locationInView:self];
	CGContextRef context = _graphicsContext;
	
	NSArray* tempLines = (NSArray*)CTFrameGetLines(textFrame);
	CFIndex lineCount = [tempLines count];//CFArrayGetCount(lines);
	NSMutableArray* lines = [NSMutableArray arrayWithCapacity:lineCount];
	for(id elem in [tempLines reverseObjectEnumerator])
		[lines addObject:elem];
	CGPoint origins[lineCount];
    
	CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 0), origins);
    
	for(CFIndex idx = 0; idx < lineCount; idx++)
	{
		CTLineRef line = CFArrayGetValueAtIndex((CFArrayRef)lines, idx);
        CGRect bounds = CTLineGetImageBounds(line, context);
        if(CGRectIsNull(bounds))
        {
            NSLog(@"Invalid arguments supplied to CTLineGetImageBounds.");
            continue;
        }
        
        CGPoint origin = bounds.origin;
        origin.y += origins[idx].y;
        bounds.origin = origin;
        
		if(!CGRectContainsPoint(CGRectInset(bounds, -10, -10), point))
        {
            continue;
        }
        
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for(CFIndex j = 0; j < CFArrayGetCount(runs); j++)
        {
            CTRunRef run = CFArrayGetValueAtIndex(runs, j);
            NSDictionary* attributes = (NSDictionary*)CTRunGetAttributes(run);
            BOOL result = NO;
            NSURL* url = [attributes objectForKey:kJTextViewDataDetectorLinkKey];
            NSString* phoneNumber = [attributes objectForKey:kJTextViewDataDetectorPhoneNumberKey];
            NSDictionary* addressComponents = [attributes objectForKey:kJTextViewDataDetectorAddressKey];
            //NSDate* date = [attributes objectForKey:kJTextViewDataDetectorDateKey];
            if(url)
            {
                self.tapRecognizedBlock = ^{
                    if([_textViewDelegate respondsToSelector:@selector(jTextView:didSelectLink:)])
                        [_textViewDelegate jTextView:self didSelectLink:url];
                    else
                        [[UIApplication sharedApplication] openURL:url];
                };
                
                return YES;
            }
            else if(phoneNumber)
            {
                phoneNumber = [phoneNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                // The following code may be switched to if we absolutely need to remove everything but the numbers.
                //NSMutableString* strippedPhoneNumber = [NSMutableString stringWithCapacity:[phoneNumber length]]; // Can't be longer than that
                //for(NSUInteger i = 0; i < [phoneNumber length]; i++)
                //{
                //	if(isdigit([phoneNumber characterAtIndex:i]))
                //		[strippedPhoneNumber appendFormat:@"%c", [phoneNumber characterAtIndex:i]];
                //}
                //NSLog(@"*** phoneNumber = %@; strippedPhoneNumber = %@", phoneNumber, strippedPhoneNumber);
                
                self.tapRecognizedBlock = ^{
                    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phoneNumber]];
                    [[UIApplication sharedApplication] openURL:url];
                };
                return YES;
            }
            else if(addressComponents)
            {
                self.tapRecognizedBlock = ^{
                    NSMutableString* address = [NSMutableString string];
                    NSString* temp = nil;
                    if((temp = [addressComponents objectForKey:NSTextCheckingStreetKey]))
                        [address appendString:temp];
                    if((temp = [addressComponents objectForKey:NSTextCheckingCityKey]))
                        [address appendString:[NSString stringWithFormat:@"%@%@", ([address length] > 0) ? @", " : @"", temp]];
                    if((temp = [addressComponents objectForKey:NSTextCheckingStateKey]))
                        [address appendString:[NSString stringWithFormat:@"%@%@", ([address length] > 0) ? @", " : @"", temp]];
                    if((temp = [addressComponents objectForKey:NSTextCheckingZIPKey]))
                        [address appendString:[NSString stringWithFormat:@" %@", temp]];
                    if((temp = [addressComponents objectForKey:NSTextCheckingCountryKey]))
                        [address appendString:[NSString stringWithFormat:@"%@%@", ([address length] > 0) ? @", " : @"", temp]];
                    NSString* urlString = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%@", [address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                };
                
                return YES;
            }
            //else if((NSDate* date = [attributes objectForKey:kJTextViewDataDetectorDateKey]))
            //{
            //	NSLog(@"Unable to handle date: %@", date);
            //	result = NO;
            //	return;
            //}
        }
    }
    
    return NO;
}

#pragma mark Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if(!self.tapRecognizedBlock) {
        [self.nextResponder touchesBegan:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if(!self.tapRecognizedBlock) {
        [self.nextResponder touchesCancelled:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if(!self.tapRecognizedBlock) {
        [self.nextResponder touchesEnded:touches withEvent:event];
    }
}

- (void)receivedTap:(UITapGestureRecognizer*)recognizer
{
	if(self.editable)
	{
		[self becomeFirstResponder];
		return;
	}
    
    if(_tapRecognizedBlock) {
        _tapRecognizedBlock();
        
        self.tapRecognizedBlock = nil;
    }
}


@end
