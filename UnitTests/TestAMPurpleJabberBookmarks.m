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
#import "TestAMPurpleJabberBookmarks.h"

#import "AMPurpleJabberBookmarks.h"

// Expose private XML-construction methods for testing
@interface AMPurpleJabberBookmarks (TestUtilities)

- (NSString *)_xmlForRetrieve;
- (NSString *)_xmlForStoreWithBookmarksXML:(NSString *)bookmarksXML;

@end

@implementation TestAMPurpleJabberBookmarks

- (void)testRetrieveXML
{
	AMPurpleJabberBookmarks *bookmarks = [[AMPurpleJabberBookmarks alloc] init];
	NSString *xml = [bookmarks _xmlForRetrieve];
	STAssertNotNil(xml, @"Bookmarks retrieve XML should not be nil");
	STAssertTrue([xml rangeOfString:@"jabber:iq:private"].location != NSNotFound,
				 @"Retrieve stanza should contain private XML namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"storage:bookmarks"].location != NSNotFound,
				 @"Retrieve stanza should contain bookmarks namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"type='get'"].location != NSNotFound,
				 @"Retrieve stanza should be an IQ-get, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"<storage xmlns="].location != NSNotFound,
				 @"Retrieve stanza should contain <storage> element, got: %@", xml);
	[bookmarks release];
}

- (void)testStoreXML
{
	AMPurpleJabberBookmarks *bookmarks = [[AMPurpleJabberBookmarks alloc] init];
	NSString *storageXML = @"<storage xmlns='storage:bookmarks'/>";
	NSString *xml = [bookmarks _xmlForStoreWithBookmarksXML:storageXML];
	STAssertNotNil(xml, @"Bookmarks store XML should not be nil");
	STAssertTrue([xml rangeOfString:@"jabber:iq:private"].location != NSNotFound,
				 @"Store stanza should contain private XML namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"storage:bookmarks"].location != NSNotFound,
				 @"Store stanza should contain bookmarks namespace, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"type='set'"].location != NSNotFound,
				 @"Store stanza should be an IQ-set, got: %@", xml);
	[bookmarks release];
}

- (void)testStoreXMLWithConference
{
	AMPurpleJabberBookmarks *bookmarks = [[AMPurpleJabberBookmarks alloc] init];
	NSString *storageXML =
		@"<storage xmlns='storage:bookmarks'>"
		@"<conference name='Development Chat' autojoin='true' jid='dev@conference.example.org'>"
		@"<nick>Phaedrus</nick>"
		@"</conference>"
		@"<conference name='Support' autojoin='false' jid='support@conference.example.com'/>"
		@"</storage>";
	NSString *xml = [bookmarks _xmlForStoreWithBookmarksXML:storageXML];
	STAssertNotNil(xml, @"Bookmarks store XML should not be nil");
	STAssertTrue([xml rangeOfString:@"dev@conference.example.org"].location != NSNotFound,
				 @"Store stanza should contain conference JID, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"Phaedrus"].location != NSNotFound,
				 @"Store stanza should contain conference nick, got: %@", xml);
	STAssertTrue([xml rangeOfString:@"support@conference.example.com"].location != NSNotFound,
				 @"Store stanza should contain second conference JID, got: %@", xml);
	[bookmarks release];
}

@end
