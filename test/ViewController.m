#import "ViewController.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIFont *font = [UIFont fontWithName:@"Andika" size:20];
    
    NSArray *chars = @[
                       @"-",
                       @"|",
                       @"|-",
                       @"ɪ",
                       @"ʃ",
                       @"ʃɪ"
                       ];
    
    for (NSString *string in chars) {
        //CGRect rect = [self getBoundingRectForGlyphFromString:string withFont:font];
        CGRect bounds = [self getBoundingRectFromString:string withFont:font];
        NSLog(@"'%@' (%f, %f, %f, %f))", string, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CGRect *) getBoundingRectForGlyphFromString:(NSString *)string withFont:(UIFont *)fnt
{
    // get characters from NSString
    NSUInteger len = [string length];
    UniChar *characters = (UniChar *)malloc(sizeof(UniChar)*len);
    CFStringGetCharacters((__bridge CFStringRef)string, CFRangeMake(0, [string length]), characters);
    CTFontRef coreTextFont = CTFontCreateWithName((CFStringRef)fnt.fontName, fnt.pointSize, NULL);
    
    // allocate glyphs and bounding box arrays for holding the result
    // assuming that each character is only one glyph, which is wrong
    CGGlyph *glyphs = (CGGlyph *)malloc(sizeof(CGGlyph)*len);
    CTFontGetGlyphsForCharacters(coreTextFont, characters, glyphs, len);
    
    // get bounding boxes for glyphs
    CGRect *boundingBoxes = (CGRect *)malloc(sizeof(CGRect)*len);
    CTFontGetBoundingRectsForGlyphs(coreTextFont, kCTFontOrientationDefault, glyphs, boundingBoxes, len);
    
    CFRelease(coreTextFont);
    free(characters);
    free(glyphs);

    return boundingBoxes;
}

- (CGRect) getBoundingRectFromString:(NSString *)string withFont:(UIFont *)fnt
{
    // get characters from NSString
    NSUInteger len = [string length];
    UniChar *characters = (UniChar *)malloc(sizeof(UniChar)*len);
    CFStringGetCharacters((__bridge CFStringRef)string, CFRangeMake(0, [string length]), characters);
    CTFontRef coreTextFont = CTFontCreateWithName((CFStringRef)fnt.fontName, fnt.pointSize, NULL);
    
    // allocate glyphs and bounding box arrays for holding the result
    // assuming that each character is only one glyph, which is wrong
    CGGlyph *glyphs = (CGGlyph *)malloc(sizeof(CGGlyph)*len);
    CTFontGetGlyphsForCharacters(coreTextFont, characters, glyphs, len);
    
    // get bounding boxes for glyphs
    CGRect *characterFrames = (CGRect *)malloc(sizeof(CGRect)*len);
    CTFontGetBoundingRectsForGlyphs(coreTextFont, kCTFontOrientationDefault, glyphs, characterFrames, len);
    CFRelease(coreTextFont);
    free(characters);
    free(glyphs);
    
    // Measure how mush specec will be needed for this attributed string
    // So we can find minimun frame needed
    CFRange fitRange;
    CFAttributedStringRef attributtedString = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attributtedString);
    CFRelease(attributtedString);
    CGSize s = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, len), NULL, CGSizeMake(MAXFLOAT, MAXFLOAT), &fitRange);
    
    CGRect frameRect = CGRectMake(0, 0, s.width, s.height);
    CGPathRef framePath = CGPathCreateWithRect(frameRect, NULL);
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, len), framePath, NULL);
    CGPathRelease(framePath);
    CFRelease(framesetter);
    
    // Get the lines in our frame
    NSArray* lines = (NSArray*)CTFrameGetLines(ctFrame);
    unsigned long lineCount = [lines count];
    
    // Allocate memory to hold line frames information:
    CGPoint *lineOrigins = malloc(sizeof(CGPoint) * lineCount);
    CGRect *lineFrames = malloc(sizeof(CGRect) * lineCount);
    
    // Get the origin point of each of the lines
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    CFRelease(ctFrame);
    
    // Solution borrowew from (but simplified):
    // https://github.com/twitter/twui/blob/master/lib/Support/CoreText%2BAdditions.m
    
    // Loop throught the lines
    for(CFIndex i = 0; i < lineCount; ++i) {
        
        CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
        
        CFRange lineRange = CTLineGetStringRange(line);
        CFIndex lineStartIndex = lineRange.location;
        CFIndex lineEndIndex = lineStartIndex + lineRange.length;
        
        CGPoint lineOrigin = lineOrigins[i];
        CGFloat ascent, descent, leading;
        CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        
        
        // If we have more than 1 line, we want to find the real height of the line by measuring the distance between the current line and previous line. If it's only 1 line, then we'll guess the line's height.
        BOOL useRealHeight = i < lineCount - 1;
        CGFloat neighborLineY = i > 0 ? lineOrigins[i - 1].y : (lineCount - 1 > i ? lineOrigins[i + 1].y : 0.0f);
        CGFloat lineHeight = ceil(useRealHeight ? fabs(neighborLineY - lineOrigin.y) : ascent + descent + leading);
        
        lineFrames[i].origin = lineOrigin;
        lineFrames[i].size = CGSizeMake(lineWidth, lineHeight);
        
        for (long ic = lineStartIndex; ic < lineEndIndex; ic++) {
            CGFloat startOffset = CTLineGetOffsetForStringIndex(line, ic, NULL);
            //characterFrames[ic].origin = CGPointMake(startOffset, lineOrigin.y);
            characterFrames[ic] = CGRectOffset(characterFrames[ic], startOffset, lineOrigin.y);
        }
    }
    free(lineOrigins);
    free(lineFrames);
    
    // Compute bounding box
    CGRect bounds = CGRectZero;
    for (int i = 0; i < len; i++) {
        if (i == 0) {
            bounds = characterFrames[i];
        } else {
            bounds = CGRectUnion(bounds, characterFrames[i]);
        }
    }
    free(characterFrames);
    
    return bounds;
}

@end
