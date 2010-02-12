//
//  IGKLaunchController.m
//  Ingredients
//
//  Created by Alex Gordon on 10/02/2010.
//  Copyright 2010 Fileability. All rights reserved.
//

#import "IGKLaunchController.h"
#import "IGKScraper.h"
#import "IGKApplicationDelegate.h"


@interface IGKLaunchController ()

- (void)addDocsetsInPath:(NSString *)docsets toArray:(NSMutableArray *)docsetPaths;

@end


@implementation IGKLaunchController

@synthesize appController;

- (void)launch
{	
	NSMutableArray *docsetPaths = [[NSMutableArray alloc] init];
	
	//Add the default documentation
	[self addDocsetsInPath:[[appController developerDirectory] stringByAppendingPathComponent:@"/Documentation/DocSets/"]
				   toArray:docsetPaths];
	
	NSString *platformsPath = [[appController developerDirectory] stringByAppendingPathComponent:@"/Platforms/"];
	NSError *error = nil;
	NSArray *platforms = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:platformsPath error:&error];
	if (!error)
	{
		for (NSString *platform in platforms)
		{
			NSString *platformPath = [platformsPath stringByAppendingPathComponent:platform];
			NSString *platformDocsetsPath = [platformPath stringByAppendingPathComponent:@"/Developer/Documentation/DocSets"];
			
			[self addDocsetsInPath:platformDocsetsPath
						   toArray:docsetPaths];
		}
	}
	
	NSLog(@"docsetPaths = %@", docsetPaths);
	
	dbQueue = dispatch_queue_create(NULL, NULL);
	
	totalPathsCount = 0;
	
	scrapers = [[NSMutableArray alloc] init];
	
	for (NSString *docsetPath in docsetPaths)
	{
		IGKScraper *scraper = [[IGKScraper alloc] initWithDocsetURL:[NSURL fileURLWithPath:docsetPath]
											   managedObjectContext:[appController backgroundManagedObjectContext]
												   launchController:self
															dbQueue:dbQueue];
		
		NSInteger scraperPaths = [scraper findPaths];
		
		totalPathsCount += scraperPaths;
		
		if (scraperPaths)
			[scrapers addObject:scraper];
		//if ([scraper findPaths])
		//	pathReportsExpected += 1;
	}
	
	for (NSString *scraper in scrapers)
	{
		[scraper index];
	}
	
	
	//[ctx save:nil];
	//[ctx reset];
}

- (void)reportPathCount:(NSUInteger)pathCount
{
	return;
	pathReportsReceived += 1;
	totalPathsCount += pathCount;
	
	NSLog(@"Getting path report: %d / %d", pathCount, totalPathsCount);
	
	//If we're still expecting paths, return for now
	if (pathReportsReceived < pathReportsExpected)
		return;
	
	//Otherwise send the path count
	NSLog(@"## Total number of paths: %d", totalPathsCount);
}
- (void)reportPath
{
	pathsCounter++;
	
	if (pathsCounter >= totalPathsCount)
	{
		//All paths have been reported
		[[NSNotificationCenter defaultCenter] postNotificationName:@"IGKHasIndexedAllPaths" object:self];
	}
	else
	{
		//A new path
		
		//There's around 200 pixels in the progress bar. We only want to send a notification for each one
		if ((pathsCounter % ((totalPathsCount / 100) ?: 1)) == 0)
		{
			dispatch_async(dispatch_get_global_queue(0, 0), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:@"IGKHasIndexedNewPaths" object:self];
			});
		}
	}
}

- (double)fraction
{
	return (double)pathsCounter / (double)totalPathsCount;
}

- (void)addDocsetsInPath:(NSString *)docsets toArray:(NSMutableArray *)docsetPaths
{
	NSError *error = nil;
	NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docsets error:&error];
	if (error)
		return;
	for (NSString *path in paths)
	{
		if ([path isEqual:@"com.apple.ADC_Reference_Library.DeveloperTools.docset"])
			continue;
		
		path = [docsets stringByAppendingPathComponent:path];
		if (![path length] || ![[path pathExtension] isEqual:@"docset"])
			continue;
		
		[docsetPaths addObject:path];
	}
}

- (void)finalize
{
	dispatch_release(dbQueue);
	[super finalize];
}

@end