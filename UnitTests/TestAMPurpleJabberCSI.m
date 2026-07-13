/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
#import "TestAMPurpleJabberCSI.h"

#import "AMPurpleJabberCSI.h"

// Expose private XML-construction method for testing
@interface AMPurpleJabberCSI (TestUtilities)

- (NSString *)_xmlForState:(NSInteger)state;

@end

@implementation TestAMPurpleJabberCSI

- (void)testCSIStanzaXMLActive
{
	AMPurpleJabberCSI *csi = [[AMPurpleJabberCSI alloc] init];
	NSString *xml = [csi _xmlForState:1]; // 1 = active
	STAssertNotNil(xml, @"CSI active XML string should not be nil");
	STAssertTrue([xml rangeOfString:@"<active/>"].location != NSNotFound,
				 @"Active CSI stanza should contain <active/> element, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"urn:xmpp:csi:0"].location != NSNotFound,
				 @"CSI stanza should contain CSI namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"<iq "].location != NSNotFound ||
				 [xml rangeOfString:@"<iq>"].location != NSNotFound,
				 @"CSI stanza should be an IQ stanza, got: %@", xml);
	[csi release];
}

- (void)testCSIStanzaXMLInactive
{
	AMPurpleJabberCSI *csi = [[AMPurpleJabberCSI alloc] init];
	NSString *xml = [csi _xmlForState:2]; // 2 = inactive
	STAssertNotNil(xml, @"CSI inactive XML string should not be nil");
	STAssertTrue([xml rangeOfString:@"<inactive/>"].location != NSNotFound,
				 @"Inactive CSI stanza should contain <inactive/> element, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"urn:xmpp:csi:0"].location != NSNotFound,
				 @"CSI stanza should contain CSI namespace, got: %@", xml);
	[csi release];
}

@end
