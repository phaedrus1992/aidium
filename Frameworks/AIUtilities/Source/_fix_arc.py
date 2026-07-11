#!/usr/bin/env python3
"""Fix remaining ARC issues in AIUtilities source files."""
import os

src_dir = "/Users/ranger/git/adium/Frameworks/AIUtilities/Source"

# ====== AITextAttributes.m ======
path = os.path.join(src_dir, "AITextAttributes.m")
with open(path) as f:
    content = f.read()

# line 61: remove [dictionary release] before assign
content = content.replace(
    '\t\t\t[dictionary release];\n\t\t\tdictionary = [inAttributes mutableCopy];',
    '\t\t\tdictionary = [inAttributes mutableCopy];'
)
# lines 116-117: release/retain -> direct assign
content = content.replace(
    '\t    if (fontFamilyName != inName) {\n\t        [fontFamilyName release];\n\t        fontFamilyName = [inName retain];',
    '\t    if (fontFamilyName != inName) {\n\t        fontFamilyName = inName;'
)

with open(path, 'w') as f:
    f.write(content)
print("AITextAttributes.m: OK")

# ====== AISendingTextView.m ======
path = os.path.join(src_dir, "AISendingTextView.m")
with open(path) as f:
    content = f.read()

# Remove whole dealloc (ARC does it)
content = content.replace(
    '- (void)dealloc\n{\n\t\t\n\t}\n',
    ''
)
# Also try without the extra blank line
old_dealloc = '- (void)dealloc\n{\n\t\t[returnArray release];\n\t\t\n\t\t[super dealloc];\n\t}'
content = content.replace(old_dealloc, '')

with open(path, 'w') as f:
    f.write(content)
print("AISendingTextView.m: OK")

# ====== AISmoothTooltipTracker.m ======
path = os.path.join(src_dir, "AISmoothTooltipTracker.m")
with open(path) as f:
    content = f.read()

# The file uses tabs for indentation. Let me replace patterns one by one.

# 1. [[[self alloc] initForView:...] autorelease] -> [[self alloc] initForView:...]
content = content.replace(
    "return [[[self alloc] initForView:inView withDelegate:inDelegate] autorelease];",
    "return [[self alloc] initForView:inView withDelegate:inDelegate];"
)
# 2. view = [inView retain] -> view = inView
content = content.replace(
    "view = [inView retain];",
    "view = inView;"
)
# 3. [view release]; view = nil; -> view = nil;
content = content.replace(
    "\t\t[view release]; view = nil;",
    "\t\tview = nil;"
)
# 4. dealloc: remove "[super dealloc];"
# The dealloc has view = nil followed by blank line then [super dealloc];
content = content.replace(
    "\t\tview = nil;\n\t\t\n\t\t[super dealloc];",
    "\t\tview = nil;"
)
# 5. ] retain]; at end of scheduledTimerWithTimeInterval block
content = content.replace(
    "repeats:YES] retain];",
    "repeats:YES];"
)
# 6. [theTimer release]; theTimer = nil; -> theTimer = nil;
content = content.replace(
    "[theTimer release]; theTimer = nil;",
    "theTimer = nil;"
)

with open(path, 'w') as f:
    f.write(content)
print("AISmoothTooltipTracker.m: OK")

# ====== AIStringAdditions.m ======
path = os.path.join(src_dir, "AIStringAdditions.m")
with open(path) as f:
    content = f.read()

# [[[self alloc] initWithData:...] autorelease] -> [[self alloc] initWithData:...]
content = content.replace(
    "return [[[self alloc] initWithData:data encoding:encoding] autorelease];",
    "return [[self alloc] initWithData:data encoding:encoding];"
)
# [[[self alloc] initWithBytes:...] autorelease]
content = content.replace(
    "return [[[self alloc] initWithBytes:inBytes length:inLength encoding:inEncoding] autorelease];",
    "return [[self alloc] initWithBytes:inBytes length:inLength encoding:inEncoding];"
)
# compacted: return [outName autorelease]
content = content.replace(
    "return [outName autorelease];",
    "return outName;"
)
# stringByExpandingBundlePath: [[self copy] autorelease]
content = content.replace(
    "return [[self copy] autorelease];",
    "return [self copy];"
)
# stringByCollapsingBundlePath: [[self copy] autorelease] (same string)
# Already handled by above replace
# stringWithEllipsisByTruncatingToLength: returnString = [[self copy] autorelease]
content = content.replace(
    "returnString = [[self copy] autorelease];",
    "returnString = [self copy];"
)
# safeFilenameString: return [string autorelease]
content = content.replace(
    "return [string autorelease];",
    "return string;"
)
# stringByEncodingURLEscapes: [[[NSString alloc] initWithBytes:...] autorelease]
content = content.replace(
    "return [[[NSString alloc] initWithBytes:destPtr length:destIndex encoding:NSASCIIStringEncoding] autorelease];",
    "return [[NSString alloc] initWithBytes:destPtr length:destIndex encoding:NSASCIIStringEncoding];"
)
# stringByDecodingURLEscapes: same as above but there are two of these
# Already handled by the above replace (exact match)
# allLinesWithSeparator: [lines addObject:[[separatorObj copy] autorelease]]
content = content.replace(
    "[lines addObject:[[separatorObj copy] autorelease]];",
    "[lines addObject:[separatorObj copy]];"
)
# CFXMLCreateStringByEscapingEntities: autorelease -> CFBridgingRelease
old = "return [(NSString *)CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (CFStringRef)self, (CFDictionaryRef)realEntities) autorelease];"
new = "return CFBridgingRelease(CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (__bridge CFStringRef)self, (__bridge CFDictionaryRef)realEntities));"
content = content.replace(old, new)
# CFXMLCreateStringByUnescapingEntities
old = "return [(NSString *)CFXMLCreateStringByUnescapingEntities(kCFAllocatorDefault, (CFStringRef)self, (CFDictionaryRef)entities) autorelease];"
new = "return CFBridgingRelease(CFXMLCreateStringByUnescapingEntities(kCFAllocatorDefault, (__bridge CFStringRef)self, (__bridge CFDictionaryRef)entities));"
content = content.replace(old, new)

# uuid: CFUUIDCreateString -> CFBridgingRelease
old = ("\t\tCFUUIDRef\tuuid;\n"
       "\t\tNSString\t*uuidStr;\n"
       "\t\t\n"
       "\t\tuuid = CFUUIDCreate(NULL);\n"
       "\t\tuuidStr = (NSString *)CFUUIDCreateString(NULL, uuid);\n"
       "\t\tCFRelease(uuid);\n"
       "\t\t\n"
       "\t\treturn [uuidStr autorelease];")
new = ("\t\tCFUUIDRef\tuuid;\n"
       "\t\t\n"
       "\t\tuuid = CFUUIDCreate(NULL);\n"
       "\t\tNSString\t*uuidStr = (NSString *)CFUUIDCreateString(NULL, uuid);\n"
       "\t\tCFRelease(uuid);\n"
       "\t\t\n"
       "\t\treturn (NSString *)CFBridgingRelease((__bridge CFStringRef)uuidStr);")
content = content.replace(old, new)

# lineBreakCharacterSet retain
content = content.replace(
    "lineBreakCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:lineBreakCharacters length:numberOfLineBreakCharacters]] retain];",
    "lineBreakCharacterSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:lineBreakCharacters length:numberOfLineBreakCharacters]];"
)

# stringByAddingPercentEscapesForAllCharacters: CFURLCreate -> CFBridgingRelease
# First replace the return [string autorelease] in the relevant section
old = ("\t\tNSString *string = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t(CFStringRef)self, \n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tNULL,\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t(CFStringRef)@\";/?:@&=+$\",\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tkCFStringEncodingUTF8);\n"
       "\n"
       "\t\treturn [string autorelease];")
new = ("\t\tNSString *string = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t(__bridge CFStringRef)self, \n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tNULL,\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t(__bridge CFStringRef)@\";/?:@&=+$\",\n"
       "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tkCFStringEncodingUTF8);\n"
       "\n"
       "\t\treturn string;")
content = content.replace(old, new)

with open(path, 'w') as f:
    f.write(content)
print("AIStringAdditions.m: OK")

# ====== AISystemNetworkDefaults.m ======
path = os.path.join(src_dir, "AISystemNetworkDefaults.m")
with open(path) as f:
    content = f.read()

# SCDynamicStoreCopyProxies + autorelease -> CFBridgingRelease
old = ("\t\tNSDictionary\t*proxyDict = nil;\n"
       "\t\t\n"
       "\t\tif ((proxyDict = (NSDictionary *)SCDynamicStoreCopyProxies(NULL))) {\n"
       "\t\t\t[proxyDict autorelease];")
new = ("\t\tNSDictionary\t*proxyDict = nil;\n"
       "\t\t\n"
       "\t\tif ((proxyDict = CFBridgingRelease(SCDynamicStoreCopyProxies(NULL)))) {")
content = content.replace(old, new)

# CFURLRef cast needs __bridge
content = content.replace(
    "CFURLRef url = (CFURLRef)[NSURL URLWithString:[NSString stringWithFormat:@\"http://%@\", hostName ?: @\"google.com\"]];",
    "CFURLRef url = (__bridge CFURLRef)[NSURL URLWithString:[NSString stringWithFormat:@\"http://%@\", hostName ?: @\"google.com\"]];"
)

# CFNetworkCopyProxiesForURL CFDictionaryRef cast
content = content.replace(
    "CFRelease(CFNetworkCopyProxiesForURL(url, (CFDictionaryRef)@{}));",
    "CFRelease(CFNetworkCopyProxiesForURL(url, (__bridge CFDictionaryRef)@{}));"
)

# CFNetworkCopyProxiesForAutoConfigurationScript + autorelease -> CFBridgingRelease
old = "proxies = [(NSArray *)CFNetworkCopyProxiesForAutoConfigurationScript((CFStringRef)scriptStr, url, &error) autorelease];"
new = "proxies = CFBridgingRelease(CFNetworkCopyProxiesForAutoConfigurationScript((__bridge CFStringRef)scriptStr, url, &error));"
content = content.replace(old, new)

with open(path, 'w') as f:
    f.write(content)
print("AISystemNetworkDefaults.m: OK")

print("\nAll 5 files fixed. Run build to verify.")
